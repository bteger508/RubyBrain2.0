ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    # Add more helper methods to be used by all tests here...

    # Tools answer with a single text block, holding a JSON document on success
    # and a plain sentence on failure.
    def tool_json(response)
      # Rooted, since bare JSON resolves to ActiveSupport::JSON in here.
      ::JSON.parse(tool_text(response), symbolize_names: true)
    end

    def tool_text(response)
      response.content.first[:text]
    end

    # Swaps the embedder for one test, so a case can exercise a provider outage
    # without leaving the swap behind for whatever runs next in this process.
    def with_embedder(embedder)
      original = ApplicationEmbedder.current
      ApplicationEmbedder.current = embedder
      yield
    ensure
      ApplicationEmbedder.current = original
    end
  end
end
