# Archive a memory that is no longer relevant or accurate.
#
# The memory is kept and marked forgotten so it drops out of recalls, rather than
# deleted, so a mistaken forget can be traced.
class ForgetTool < ApplicationTool
  tool_name "forget"
  title "Forget memory"
  description <<~TEXT
    Forget a memory that is no longer relevant or accurate. It stops being
    recalled but is not deleted. Use this when a memory was wrong; use update
    when the fact it records has merely changed.
  TEXT

  input_schema(
    properties: {
      id: {
        type: "integer",
        description: "ID of the memory to forget, as returned by recall."
      }
    },
    required: [ "id" ]
  )

  annotations(
    read_only_hint: false,
    destructive_hint: true,
    idempotent_hint: true
  )

  def self.call(id:, server_context: nil)
    memory = Memory.find(id)
    memory.forget!

    success(memory: serialize(memory))
  rescue ActiveRecord::RecordNotFound
    failure("No memory with id #{id}.")
  end
end
