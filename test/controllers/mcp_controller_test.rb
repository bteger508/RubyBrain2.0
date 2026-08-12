require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  # The transport only trusts loopback hosts unless MCP_ALLOWED_HOSTS widens it.
  setup { host! "localhost" }

  test "lists the four tools" do
    result = rpc("tools/list")

    assert_equal %w[ record recall update forget ].sort,
      result["tools"].map { |tool| tool["name"] }.sort
  end

  test "record declares its required arguments" do
    result = rpc("tools/list")
    record = result["tools"].find { |tool| tool["name"] == "record" }

    assert_equal %w[ title description ], record["inputSchema"]["required"]
  end

  test "calling a tool returns its stub" do
    result = rpc("tools/call", name: "recall", arguments: {})

    assert_not result["isError"]
    assert_equal "recall is not implemented yet", result["content"].first["text"]
  end

  test "rejects an unknown tool" do
    response = post_rpc("tools/call", name: "remember", arguments: {})

    assert response["error"], "expected a JSON-RPC error for an unknown tool"
  end

  private
    def rpc(method, params = {})
      body = post_rpc(method, params)
      assert_nil body["error"], "expected no JSON-RPC error, got #{body["error"].inspect}"
      body["result"]
    end

    def post_rpc(method, params = {})
      post mcp_path,
        params: { jsonrpc: "2.0", id: 1, method: method, params: params }.to_json,
        headers: { "Content-Type" => "application/json", "Accept" => "application/json, text/event-stream" }

      JSON.parse(response.body)
    end
end
