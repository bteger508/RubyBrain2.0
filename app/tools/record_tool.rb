# Record a memory for later recall.
#
# Checks for near duplicates first. If there are any, the new memory supersedes
# them, so future recalls return this memory rather than the phrasing it replaced.
class RecordTool < ApplicationTool
  tool_name "record"
  title "Record memory"
  description <<~TEXT
    Record a memory for later recall. Checks for near-duplicate memories first;
    any it finds are superseded by this one, so recalls return the newest version
    of a fact. Returns the recorded memory and whatever it replaced.
  TEXT

  input_schema(
    properties: {
      title: {
        type: "string",
        description: "The fact itself, in one sentence.",
        maxLength: 120
      },
      description: {
        type: "string",
        description: "Why it's true, its source, and when it was confirmed. 1–3 sentences. Don't add other facts.",
        maxLength: 600
      }
    },
    required: [ "title", "description" ]
  )

  annotations(
    read_only_hint: false,
    destructive_hint: false,
    idempotent_hint: false
  )

  def self.call(title:, description:, server_context: nil)
    memory, superseded = Memory.record!(title: title, description: description)

    success(
      memory: serialize(memory),
      superseded: superseded.map { |replaced| serialize(replaced) }
    )
  rescue ActiveRecord::RecordInvalid => error
    failure("Could not record that memory: #{error.record.errors.full_messages.to_sentence}.")
  end
end
