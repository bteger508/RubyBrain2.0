require "test_helper"

class ApplicationEmbedderTest < ActiveSupport::TestCase
  # Stands in for a provider whose model returns a width the column cannot hold.
  class WrongWidthEmbedder < ApplicationEmbedder
    private
      def generate(texts, _purpose)
        texts.map { Array.new(8, 0.5) }
      end
  end

  class PurposeSpyEmbedder < ApplicationEmbedder
    attr_reader :purposes

    def initialize = @purposes = []

    private
      def generate(texts, purpose)
        @purposes << purpose
        texts.map { Array.new(DIMENSIONS, 0.0) }
      end
  end

  test "the test suite runs on the offline embedder" do
    assert_instance_of FakeEmbedder, ApplicationEmbedder.current
  end

  test "rejects a vector that does not fit the column" do
    error = assert_raises ApplicationEmbedder::DimensionMismatch do
      WrongWidthEmbedder.new.embed("anything")
    end

    assert_match(/expected #{ApplicationEmbedder::DIMENSIONS}/, error.message)
  end

  test "embeds a batch in one call" do
    embedder = PurposeSpyEmbedder.new

    vectors = embedder.embed_all([ "one", "two", "three" ])

    assert_equal 3, vectors.size
    assert_equal 1, embedder.purposes.size, "batch should not fan out into a call per text"
  end

  test "embeds documents and queries differently" do
    embedder = PurposeSpyEmbedder.new

    embedder.embed("a stored memory")
    embedder.embed("a search", purpose: :query)

    assert_equal [ :document, :query ], embedder.purposes
  end

  test "rejects an unknown purpose rather than silently embedding as a document" do
    assert_raises ArgumentError do
      FakeEmbedder.new.embed("anything", purpose: :nonsense)
    end
  end

  test "embedding nothing costs nothing" do
    embedder = PurposeSpyEmbedder.new

    assert_empty embedder.embed_all([])
    assert_empty embedder.purposes
  end

  test "requires subclasses to implement generate" do
    assert_raises NotImplementedError do
      ApplicationEmbedder.new.embed("anything")
    end
  end
end
