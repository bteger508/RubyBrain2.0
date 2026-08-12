class Memory < ApplicationRecord
  # Trigram similarity above which two titles are treated as the same memory
  # rephrased. Calibrated against real pairs: rephrasings land around 0.65-0.87,
  # unrelated memories below 0.05.
  #
  # Note that trigrams are word-order blind, so "tabs over spaces" and "spaces
  # over tabs" score 1.0 despite meaning the opposite. Semantic embeddings are
  # the fix; until then, near_duplicates_of is the only place that assumption
  # lives.
  SIMILARITY_THRESHOLD = 0.55

  DEFAULT_RECALL_LIMIT = 10

  belongs_to :superseded_by, class_name: "Memory", optional: true
  has_many :supersedes, class_name: "Memory", foreign_key: :superseded_by_id,
    inverse_of: :superseded_by, dependent: :nullify

  validates :title, presence: true
  validates :description, presence: true

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

    # Recalls memories by keyword and/or time range, and counts the recall against
    # each one returned.
    def recall(query: nil, from: nil, to: nil, limit: DEFAULT_RECALL_LIMIT)
      scope = recallable
      scope = scope.matching(query) if query.present?
      scope = scope.recorded_after(from) if from
      scope = scope.recorded_before(to) if to
      scope = scope.order(created_at: :desc) if query.blank?

      mark_recalled scope.limit(limit).to_a
    end

    private
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
end
