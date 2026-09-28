class Memory < ApplicationRecord
  SIMILARITY_THRESHOLD = 0.55

  DEFAULT_RECALL_LIMIT = 10

  # Cosine distance beyond which a memory is not about the query at all. kNN
  # always returns its k nearest rows however unrelated they are, so without a
  # floor an unrecognised query comes back full of confident nonsense.
  # Similarity is 1 - distance, making this a floor of 0.25.
  MAX_SEMANTIC_DISTANCE = 0.75

  # Reciprocal rank fusion, from the paper that introduced it. Large enough that
  # one arm ranking something first does not by itself decide the outcome.
  RRF_K = 60

  # How deep to read each arm before fusing. Fusion can only reorder what it is
  # given, so both arms need more than the caller asked for.
  CANDIDATE_MULTIPLIER = 4

  has_neighbors :embedding

  belongs_to :superseded_by, class_name: "Memory", optional: true
  has_many :supersedes, class_name: "Memory", foreign_key: :superseded_by_id,
    inverse_of: :superseded_by, dependent: :nullify

  validates :title, presence: true
  validates :description, presence: true

  # Kept current on every write rather than only in record!, so a memory created
  # any other way is still recallable.
  before_save :assign_embedding, if: :embeddable_text_changed?

  # Memories still in circulation: not forgotten, and not replaced by a newer one.
  scope :recallable, -> { where(forgotten: false, superseded_by_id: nil) }

  scope :matching, ->(query) {
    where("searchable @@ websearch_to_tsquery('english', ?)", query)
      .order(Arel.sql(sanitize_sql([ "ts_rank(searchable, websearch_to_tsquery('english', ?)) DESC", query ])))
  }

  scope :recorded_after, ->(time) { where(created_at: time..) }
  scope :recorded_before, ->(time) { where(created_at: ..time) }

  class << self
    # Memories close enough to `title` to be the same fact stated differently,
    # closest first.
    def near_duplicates_of(title, threshold: SIMILARITY_THRESHOLD)
      recallable
        .where("similarity(title, ?) >= ?", title, threshold)
        .order(Arel.sql(sanitize_sql([ "similarity(title, ?) DESC", title ])))
    end

    # Records a memory, superseding any near-duplicates it restates so that future
    # recalls return this one instead. Returns the new memory and what it replaced.
    def record!(title:, description:)
      transaction do
        # Found before the insert, so the new memory cannot match itself.
        superseded = near_duplicates_of(title).to_a
        memory = create!(title: title, description: description)

        where(id: superseded.map(&:id)).update_all(superseded_by_id: memory.id, updated_at: Time.current)

        [ memory, superseded ]
      end
    end

    # Recalls memories by meaning and/or time range, and counts the recall
    # against each one returned.
    #
    # A query is answered by two searches at once: embeddings, which find a
    # memory that means the same thing in different words, and full text, which
    # finds the identifiers and error strings that embeddings are worst at. Each
    # ranks the same pool, and the two rankings are fused.
    def recall(query: nil, from: nil, to: nil, limit: DEFAULT_RECALL_LIMIT)
      scope = recallable
      scope = scope.recorded_after(from) if from
      scope = scope.recorded_before(to) if to

      memories =
        if query.present?
          hybrid_search(scope, query, limit: limit)
        else
          scope.order(created_at: :desc).limit(limit).to_a
        end

      mark_recalled memories
    end

    private
      def hybrid_search(scope, query, limit:)
        depth = limit * CANDIDATE_MULTIPLIER
        ranked = fuse(semantic_ids(scope, query, limit: depth), lexical_ids(scope, query, limit: depth))
        ids = ranked.first(limit)
        return [] if ids.empty?

        # One trip for the rows, then back into fused order, which SQL has no
        # reason to preserve.
        by_id = scope.where(id: ids).index_by(&:id)
        ids.filter_map { |id| by_id[id] }
      end

      # Ranks by angle between embeddings, discarding anything too far away to
      # be about the query at all.
      def semantic_ids(scope, query, limit:)
        embedding = ApplicationEmbedder.current.embed(query, purpose: :query)

        scope.nearest_neighbors(:embedding, embedding, distance: :cosine)
          .limit(limit)
          .select { |memory| memory.neighbor_distance <= MAX_SEMANTIC_DISTANCE }
          .map(&:id)
      rescue ApplicationEmbedder::Error => error
        # Losing an arm degrades the ranking; losing recall entirely would lose
        # the agent its memory.
        Rails.error.report(error, source: "brain.recall", handled: true)
        []
      end

      def lexical_ids(scope, query, limit:)
        scope.matching(query).limit(limit).pluck(:id)
      end

      # Reciprocal rank fusion: each arm contributes 1/(k + rank), so a memory
      # both arms like outranks one that either alone ranks first. Scores stay
      # comparable without having to normalise a cosine distance against a
      # ts_rank, which are on unrelated scales.
      def fuse(*rankings)
        scores = Hash.new(0.0)

        rankings.each do |ids|
          ids.each_with_index { |id, index| scores[id] += 1.0 / (RRF_K + index + 1) }
        end

        scores.sort_by { |id, score| [ -score, id ] }.map(&:first)
      end

      def mark_recalled(memories)
        return memories if memories.empty?

        recalled_at = Time.current
        where(id: memories.map(&:id)).update_all(
          sanitize_sql([ "recall_count = recall_count + 1, last_recalled_at = :at, updated_at = :at", at: recalled_at ])
        )

        # The rows just moved underneath these objects; mirror the change rather
        # than re-reading them, so callers see current stats.
        memories.each do |memory|
          memory.recall_count += 1
          memory.last_recalled_at = recalled_at
          memory.changes_applied
        end
      end
  end

  # Replaces this memory with a newer one. The old memory is kept and linked
  # forward, so the history of a changing fact stays readable.
  def supersede_with!(memory)
    raise ArgumentError, "a memory cannot supersede itself" if memory == self

    update!(superseded_by: memory)
  end

  def forget!
    update!(forgotten: true)
  end

  private
    # Title and description are embedded together: recall is against the whole
    # memory, not its headline.
    def embeddable_text
      [ title, description ].compact_blank.join("\n\n")
    end

    def embeddable_text_changed?
      title_changed? || description_changed?
    end

    def assign_embedding
      self.embedding = ApplicationEmbedder.current.embed(embeddable_text)
    rescue ApplicationEmbedder::Error => error
      # A provider outage should not swallow what the agent asked Brain to
      # remember. The memory is stored unembedded and full text still finds it;
      # a later save, or a backfill, fills the vector in.
      Rails.error.report(error, source: "brain.record", handled: true)
      self.embedding = nil
    end
end
