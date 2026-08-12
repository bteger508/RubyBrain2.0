# Archive a memory that is no longer relevant or accurate.
#
# The memory is kept on disk and marked forgotten so it drops out of recalls.
class ForgetTool < MCP::Tool
  tool_name "forget"
  title "Forget memory"
  description <<~TEXT
    Archive a memory that is no longer relevant or accurate. The memory is marked
    forgotten and excluded from future recalls rather than deleted.
  TEXT

  input_schema(
    properties: {
      id: {
        type: "integer",
        description: "ID of the memory to forget."
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
    # TODO: mark the memory forgotten.
    MCP::Tool::Response.new([ { type: "text", text: "forget is not implemented yet" } ])
  end
end
