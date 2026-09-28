# Turns text into a vector so Model.Recall() can search by meaning rather than by keyword.
#
# Provider differences — model names, request shape, batch limits, whether a
# search query and a stored document should be embedded differently — are
# ruby_llm's problem, not Brain's. This class exists for one reason beyond
# that: it is a seam, so the test suite can embed without a network or a key.
#
# Subclasses implement #generate. Everything else is shared.
class ApplicationEmbedder
  # The width of the `memories.embedding` column. Every provider is asked for
  # this many dimensions; one that cannot oblige is the wrong provider, and
  # changing the number means a migration and a full re-embed.
  DIMENSIONS = 1536

  # Some providers embed a search query and a stored document differently, and
  # score better for it. ruby_llm translates these into each provider's own
  # vocabulary, and providers without the concept ignore them.
  PURPOSES = %i[ document query ].freeze

  class Error < StandardError; end

  # Nearly always the wrong model name rather than a broken provider.
  class DimensionMismatch < Error
    def initialize(actual)
      super("Embedder returned #{actual} dimensions, expected #{DIMENSIONS}. " \
            "Check config.x.embedding.model — the column is fixed at #{DIMENSIONS} and changing it needs a migration.")
    end
  end

  class << self
    attr_writer :current

    # The embedder Brain is configured to use. Assignable so a test can swap in
    # a fake without touching global config.
    def current
      @current ||= build
    end

    def reset!
      @current = nil
    end

    private
      def build
        case (provider = Rails.application.config.x.embedding.provider.to_s)
        when "fake"    then FakeEmbedder.new
        when "ruby_llm" then RubyLLMEmbedder.new
        else raise Error, "Unknown embedding provider #{provider.inspect}"
        end
      end
  end

  def embed(text, purpose: :document)
    embed_all([ text ], purpose: purpose).first
  end

  # Batched because backfills and near-duplicate checks would otherwise pay a
  # round trip per memory.
  def embed_all(texts, purpose: :document)
    texts = Array(texts)
    return [] if texts.empty?

    raise ArgumentError, "Unknown purpose #{purpose.inspect}" unless PURPOSES.include?(purpose)

    generate(texts, purpose).each { |vector| validate!(vector) }
  end

  private
    def generate(texts, purpose)
      raise NotImplementedError, "#{self.class} must implement #generate"
    end

    def validate!(vector)
      raise DimensionMismatch, vector.size unless vector.size == DIMENSIONS
      vector
    end

    # Cosine distance is undefined for a zero vector, and pgvector answers NaN
    # rather than raising, which would quietly poison every ranking it touches.
    def normalize(vector)
      magnitude = Math.sqrt(vector.sum { |value| value * value })
      return Array.new(DIMENSIONS, 1.0 / Math.sqrt(DIMENSIONS)) if magnitude.zero?

      vector.map { |value| value / magnitude }
    end
end
