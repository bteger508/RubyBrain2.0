# Brain's real embedder: whichever provider ruby_llm is pointed at.
#
# Switching between OpenAI, Gemini, Cohere, Bedrock, Mistral, or a local Ollama
# model is a change of configuration, not of code — so nothing here names a
# provider. See config/initializers/embedding.rb.
class RubyLLMEmbedder < ApplicationEmbedder
  # ruby_llm's embedding API takes model, provider, and dimensions, and nothing
  # else — it has no notion of a query embedding versus a document one, so there
  # is no field to put a purpose on and it is dropped here. The distinction stays
  # in ApplicationEmbedder's interface because it is a property of the providers
  # that have it, not of the client library, and a provider ruby_llm later
  # exposes it for can be honoured without changing every caller.
  #
  # Config and model-lookup failures do not descend from RubyLLM::Error, so they
  # are named alongside it; uncaught, a missing key or a mistyped model name
  # takes down the record that was only trying to embed itself.
  FAILURES = [ RubyLLM::Error, RubyLLM::ConfigurationError, RubyLLM::ModelNotFoundError ].freeze

  private
    def generate(texts, _purpose)
      embedding = RubyLLM.embed(texts, **options)

      # One text still yields a flat vector rather than an array of one.
      vectors = embedding.vectors
      vectors.first.is_a?(Array) ? vectors : [ vectors ]
    rescue *FAILURES => error
      raise Error, "Embedding failed: #{error.message}"
    end

    def options
      config = Rails.application.config.x.embedding

      {
        # Asked for explicitly so the answer fits the column whatever the model's
        # own default happens to be.
        dimensions: DIMENSIONS
      }.tap do |options|
        options[:model] = config.model if config.model.present?
        options[:provider] = config.provider_name if config.provider_name.present?
      end
    end
end
