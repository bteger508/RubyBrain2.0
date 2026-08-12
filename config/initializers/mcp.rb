# The MCP transport validates Host and Origin headers to prevent DNS rebinding
# attacks. Loopback hosts are always allowed; any hostname Brain is served from
# has to be listed here, as does the origin of any browser-based MCP client.
Rails.application.config.x.mcp.allowed_hosts = ENV.fetch("MCP_ALLOWED_HOSTS", "").split(",").map(&:strip)
Rails.application.config.x.mcp.allowed_origins = ENV.fetch("MCP_ALLOWED_ORIGINS", "").split(",").map(&:strip)

MCP.configure do |config|
  # MCP swallows tool exceptions to return a JSON-RPC error, so report them
  # ourselves or they go unnoticed.
  config.exception_reporter = ->(exception, server_context) {
    Rails.error.report(exception, context: server_context || {}, source: "mcp")
  }
end
