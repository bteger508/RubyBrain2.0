# Shared shape for Brain's MCP tools.
#
# Tools answer with a single text block: a JSON document when the call succeeds,
# a plain sentence when it does not. Agents get something parseable either way,
# and failures come back as tool errors rather than exceptions so the agent can
# read what went wrong and try again.
class ApplicationTool < MCP::Tool
  class << self
    private
      def success(payload)
        MCP::Tool::Response.new([ { type: "text", text: JSON.pretty_generate(payload) } ])
      end

      def failure(message)
        MCP::Tool::Response.new([ { type: "text", text: message } ], error: true)
      end

      def serialize(memory)
        {
          id: memory.id,
          title: memory.title,
          description: memory.description,
          recorded_at: memory.created_at.iso8601,
          last_recalled_at: memory.last_recalled_at&.iso8601,
          recall_count: memory.recall_count
        }
      end
  end
end
