# Recall memories by keywords or time range.
#
# Parameters are TBD; the schema below is a first cut and is expected to change
# once semantic (pgvector) and full-text (tsvector) search land.
class RecallTool < MCP::Tool
  tool_name "recall"
  title "Recall memories"
  description <<~TEXT
    Recall memories by keywords or time range. Superseded and forgotten memories
    are excluded.
  TEXT

  input_schema(
    properties: {
      query: {
        type: "string",
        description: "Keywords to search titles and descriptions for."
      },
      from: {
        type: "string",
        format: "date-time",
        description: "Only recall memories created at or after this time."
      },
      to: {
        type: "string",
        format: "date-time",
        description: "Only recall memories created at or before this time."
      },
      limit: {
        type: "integer",
        description: "Maximum number of memories to return.",
        default: 10
      }
    },
    required: []
  )

  annotations(
    read_only_hint: true,
    idempotent_hint: true
  )

  def self.call(query: nil, from: nil, to: nil, limit: 10, server_context: nil)
    # TODO: search by keyword and time range, then bump last_recalled_at and
    # recall_count on whatever comes back.
    MCP::Tool::Response.new([ { type: "text", text: "recall is not implemented yet" } ])
  end
end
