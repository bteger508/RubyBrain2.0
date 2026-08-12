# Update a memory by supersession.
#
# Nothing is edited in place: the new memory is recorded, and the old memory is
# linked to it through the old memory's superseded_by foreign key.
class UpdateTool < MCP::Tool
  tool_name "update"
  title "Update memory"
  description <<~TEXT
    Update a memory by supersession. Records the new memory and links the old one
    to it, so the old memory stays readable as history.
  TEXT

  input_schema(
    properties: {
      id: {
        type: "integer",
        description: "ID of the memory being superseded."
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
    # TODO: record the new memory, then point the old memory's superseded_by at it.
    MCP::Tool::Response.new([ { type: "text", text: "update is not implemented yet" } ])
  end
end
