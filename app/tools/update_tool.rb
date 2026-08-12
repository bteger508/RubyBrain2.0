# Update a memory by supersession.
#
# Nothing is edited in place: the new memory is recorded, and the old one is
# linked forward to it, so the history of a changing fact stays readable.
class UpdateTool < ApplicationTool
  tool_name "update"
  title "Update memory"
  description <<~TEXT
    Update a memory by recording a new version of it and linking the old one
    forward. The old memory is preserved but stops being recalled. Use this when
    a remembered fact has changed; use forget when it was simply wrong.
  TEXT

  input_schema(
    properties: {
      id: {
        type: "integer",
        description: "ID of the memory being superseded, as returned by recall."
      },
      title: {
        type: "string",
        description: "Short, self-contained summary of the new memory."
      },
      description: {
        type: "string",
        description: "Full detail of the new memory."
      }
    },
    required: [ "id", "title", "description" ]
  )

  annotations(
    read_only_hint: false,
    destructive_hint: false,
    idempotent_hint: false
  )

  def self.call(id:, title:, description:, server_context: nil)
    superseded = Memory.find(id)

    if superseded.superseded_by_id
      return failure(
        "Memory #{id} was already superseded by memory #{superseded.superseded_by_id}. Update that one instead."
      )
    end

    memory = Memory.transaction do
      Memory.create!(title: title, description: description).tap do |replacement|
        superseded.supersede_with!(replacement)
      end
    end

    success(memory: serialize(memory), superseded: serialize(superseded))
  rescue ActiveRecord::RecordNotFound
    failure("No memory with id #{id}.")
  rescue ActiveRecord::RecordInvalid => error
    failure("Could not update that memory: #{error.record.errors.full_messages.to_sentence}.")
  end
end
