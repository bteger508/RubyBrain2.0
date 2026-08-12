# Record a memory for later recall.
#
# Recalls and checks for near duplicates first. If there are any duplicates, the
# new memory supersedes the old one, so future recalls return the new memory.
class RecordTool < MCP::Tool
  tool_name "record"
  title "Record memory"
  description <<~TEXT
    Record a memory for later recall. Checks for near-duplicate memories first;
    when one is found, the new memory supersedes it.
  TEXT

  input_schema(
    properties: {
      title: {
        type: "string",
        description: "Short, self-contained summary of the memory."
      },
      description: {
        type: "string",
        description: "Full detail of what happened or what was learned."
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
    # TODO: search for near duplicates, then create the memory and supersede any
    # duplicate it replaces.
    MCP::Tool::Response.new([ { type: "text", text: "record is not implemented yet" } ])
  end
end
