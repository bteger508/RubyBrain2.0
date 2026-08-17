require "test_helper"

# The real embedder is the one piece of Brain that cannot be exercised offline:
# every path through it ends in a provider call. What can be checked without a
# network is the call itself — that the options Brain builds are options
# ruby_llm accepts, and that a provider failure arrives as ApplicationEmbedder's
# own error rather than escaping as whatever the gem raised.
#
# Both have gone wrong once already: an option ruby_llm never supported raised
# ArgumentError inside a save, which no rescue caught, which rolled back the
# memory being recorded.
class RubyLLMEmbedderTest < ActiveSupport::TestCase
  test "passes only options ruby_llm accepts" do
    accepted = RubyLLM::Embedding.method(:embed).parameters
      .filter_map { |type, name| name if type.in?(%i[ key keyreq ]) }

    unknown = embedder.send(:options).keys - accepted

    assert_empty unknown, "ruby_llm's embed takes #{accepted.inspect}"
  end

  test "asks for the width the column is fixed at" do
    assert_equal ApplicationEmbedder::DIMENSIONS, embedder.send(:options)[:dimensions]
  end

  test "a missing key surfaces as an embedder error rather than the gem's" do
    answering -> { raise RubyLLM::ConfigurationError, "Missing configuration" } do
      error = assert_raises ApplicationEmbedder::Error do
        embedder.embed("anything")
      end

      assert_match(/Missing configuration/, error.message)
    end
  end

  test "an unknown model surfaces as an embedder error rather than the gem's" do
    answering -> { raise RubyLLM::ModelNotFoundError, "No such model" } do
      assert_raises(ApplicationEmbedder::Error) { embedder.embed("anything") }
    end
  end

  test "a provider outage surfaces as an embedder error rather than the gem's" do
    answering -> { raise RubyLLM::ServiceUnavailableError, "Down" } do
      assert_raises(ApplicationEmbedder::Error) { embedder.embed("anything") }
    end
  end

  test "reads a single text back as one vector rather than a flat one" do
    vector = Array.new(ApplicationEmbedder::DIMENSIONS, 0.1)

    answering -> { RubyLLM::Embedding.new(vectors: vector, model: "test") } do
      assert_equal [ vector ], embedder.embed_all([ "one text" ])
    end
  end

  private
    def embedder = @embedder ||= RubyLLMEmbedder.new

    # Minitest 6 ships no stubbing, and Brain's own seam — an ApplicationEmbedder
    # subclass — sits above the call this file is about. So the call itself is
    # swapped for the duration of the block and put back however the block ends.
    def answering(answer)
      RubyLLM.singleton_class.alias_method :embed_without_double, :embed
      RubyLLM.define_singleton_method(:embed) { |*, **| answer.call }

      yield
    ensure
      RubyLLM.singleton_class.alias_method :embed, :embed_without_double
      RubyLLM.singleton_class.remove_method :embed_without_double
    end
end
