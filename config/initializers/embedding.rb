# Recall searches by meaning, which needs an embedder.
#
# `provider` picks the seam: "fake" is deterministic, offline, and needs no key,
# which is what the test suite and a fresh checkout run on. "ruby_llm" is the
# real one, and which provider *it* talks to is settled by configuration and by
# whichever credentials are present — Brain names none of them.
Rails.application.config.x.embedding.tap do |config|
  config.provider = ENV.fetch("EMBEDDING_PROVIDER") { Rails.env.test? ? "fake" : "ruby_llm" }

  # Passed through to ruby_llm when set. Left blank, ruby_llm picks its own
  # default model and resolves the provider from the credentials it finds.
  config.provider_name = ENV["EMBEDDING_PROVIDER_NAME"]
  config.model = ENV["EMBEDDING_MODEL"]
end

RubyLLM.configure do |config|
  config.request_timeout = 20
  config.max_retries = 2

  # Brain never used the legacy acts_as API; opting in now keeps 2.0 quiet.
  config.use_new_acts_as = true

  # Credentials, wired without naming a provider: every option ruby_llm's
  # providers declare is filled from the matching upper-case environment
  # variable, so OPENAI_API_KEY, GEMINI_API_KEY, BEDROCK_REGION, OLLAMA_API_BASE
  # and any provider added in a later release all work with no change here.
  RubyLLM::Provider.providers.values
    .select { |provider| provider.respond_to?(:configuration_options) }
    .flat_map(&:configuration_options)
    .uniq
    .each do |option|
      value = ENV[option.to_s.upcase]
      config.public_send(:"#{option}=", value) if value.present?
    end
end
