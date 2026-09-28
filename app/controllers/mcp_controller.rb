# The MCP endpoint AI agents connect to.
#
# A server is built per request so tools can later be scoped to the authenticated
# user through server_context. Sessions are not shared across requests, so the
# transport runs stateless and works under multi-process Puma.
class McpController < ActionController::API
  TOOLS = [ RecordTool, RecallTool, UpdateTool, ForgetTool ].freeze

  def create
    status, headers, body = transport.handle_request(request)

    render json: body.first, status: status, headers: headers
  end

  private
    def transport
      MCP::Server::Transports::StreamableHTTPTransport.new(server,
        stateless: true,
        allowed_hosts: Rails.application.config.x.mcp.allowed_hosts,
        allowed_origins: Rails.application.config.x.mcp.allowed_origins)
    end

    def server
      MCP::Server.new(
        name: "brain",
        title: "Brain",
        version: Brain::VERSION,
        instructions: <<~TEXT,
          Brain is your long-term memory. Recall before you assume.
          Each memory holds one fact that could change on its own: a decision, a date, a person's role, a rule. The title states the fact ("PayGo PC go-live is January 2027"), not a topic ("PayGo decisions").
          Before recording, recall the fact's subject. If a memory already holds it, update that memory; don't restate the fact inside another one. Refer to other memories by id instead of copying what they say.
          Split a report into several memories rather than recording it whole.
        TEXT
        tools: TOOLS
      )
    end
end
