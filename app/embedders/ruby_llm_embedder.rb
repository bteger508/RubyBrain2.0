# Brain's real embedder: whichever provider ruby_llm is pointed at.
#
# Switching between OpenAI, Gemini, Cohere, Bedrock, Mistral, or a local Ollama
# model is a change of configuration, not of code — so nothing here names a
# provider. See config/initializers/embedding.rb.
class RubyLLMEmbedder < ApplicationEmbedder
  # Providers spell the query/document distinction differently. ruby_llm puts
  # the value on the right request field, so these are the vocabularies its
  # supported providers actually accept; providers without the concept, such as
  # OpenAI, ignore it entirely.
  TASK_TYPES = {
    document: "RETRIEVAL_DOCUMENT",
    query:    "RETRIEVAL_QUERY"
  }.freeze

  private
    def generate(texts, purpose)
      embedding = RubyLLM.embed(texts, **options(purpose))

      # One text still yields a flat vector rather than an array of one.
      vectors = embedding.vectors
      vectors.first.is_a?(Array) ? vectors : [ vectors ]
    rescue RubyLLM::Error => error
      raise Error, "Embedding failed: #{error.message}"
    end

    def options(purpose)
      config = Rails.application.config.x.embedding

      {
        # Asked for explicitly so the answer fits the column whatever the model's
        # own default happens to be.
        dimensions: DIMENSIONS,
        task_type: TASK_TYPES.fetch(purpose)
      }.tap do |options|
        options[:model] = config.model if config.model.present?
        options[:provider] = config.provider_name if config.provider_name.present?
      end
    end
end
