require "test_helper"

class ForgetToolTest < ActiveSupport::TestCase
  test "marks the memory forgotten" do
    memory = Memory.create!(title: "Ben deploys with Capistrano", description: "No longer true.")

    response = ForgetTool.call(id: memory.id)

    assert_not response.error?
    assert memory.reload.forgotten
    assert_equal memory.id, tool_json(response)[:memory][:id]
  end

  test "keeps the memory but drops it out of recall" do
    memory = Memory.create!(title: "Ben deploys with Capistrano", description: "No longer true.")

    ForgetTool.call(id: memory.id)

    assert Memory.exists?(memory.id)
    assert_empty Memory.recall(query: "Capistrano")
  end

  test "reports an unknown id" do
    response = ForgetTool.call(id: 999_999)

    assert response.error?
    assert_match(/999999/, tool_text(response))
  end

  test "forgetting twice is harmless" do
    memory = Memory.create!(title: "Ben deploys with Capistrano", description: "No longer true.")

    ForgetTool.call(id: memory.id)
    response = ForgetTool.call(id: memory.id)

    assert_not response.error?
    assert memory.reload.forgotten
  end

  test "is declared with the arguments it needs" do
    assert_equal "forget", ForgetTool.tool_name
    assert_equal %w[ id ], ForgetTool.input_schema.to_h[:required]
  end
end
