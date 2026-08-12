require "test_helper"

class RecordToolTest < ActiveSupport::TestCase
  test "records a memory and returns it" do
    response = RecordTool.call(title: "Ben prefers Minitest", description: "Not RSpec.")

    assert_not response.error?
    memory = tool_json(response)[:memory]
    assert_equal "Ben prefers Minitest", memory[:title]
    assert_equal "Not RSpec.", memory[:description]
    assert Memory.exists?(memory[:id])
  end

  test "reports nothing superseded when the memory is new" do
    response = RecordTool.call(title: "Ben works in the Pacific timezone", description: "UTC-8.")

    assert_empty tool_json(response)[:superseded]
  end

  test "supersedes a near duplicate and says so" do
    original = Memory.create!(title: "Brain deploys with Kamal", description: "Older phrasing.")

    response = RecordTool.call(title: "Brain deploys using Kamal", description: "Via bin/kamal deploy.")

    superseded = tool_json(response)[:superseded]
    assert_equal [ original.id ], superseded.map { |memory| memory[:id] }
    assert_equal tool_json(response)[:memory][:id], original.reload.superseded_by_id
  end

  test "rejects a blank title without recording anything" do
    assert_no_difference -> { Memory.count } do
      response = RecordTool.call(title: "   ", description: "No title here.")

      assert response.error?
      assert_match(/title/i, tool_text(response))
    end
  end

  test "is declared with the arguments it needs" do
    schema = RecordTool.input_schema.to_h

    assert_equal "record", RecordTool.tool_name
    assert_equal %w[ title description ], schema[:required]
  end
end
