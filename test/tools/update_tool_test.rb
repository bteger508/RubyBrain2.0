require "test_helper"

class UpdateToolTest < ActiveSupport::TestCase
  test "records the new memory and links the old one to it" do
    old = Memory.create!(title: "The retry budget is three attempts", description: "Set in 2025.")

    response = UpdateTool.call(id: old.id, title: "The retry budget is five attempts", description: "Raised today.")

    assert_not response.error?
    result = tool_json(response)
    assert_equal "The retry budget is five attempts", result[:memory][:title]
    assert_equal old.id, result[:superseded][:id]
    assert_equal result[:memory][:id], old.reload.superseded_by_id
  end

  test "leaves the old memory readable as history" do
    old = Memory.create!(title: "The retry budget is three attempts", description: "Set in 2025.")

    UpdateTool.call(id: old.id, title: "The retry budget is five attempts", description: "Raised today.")

    assert Memory.exists?(old.id)
    assert_not old.reload.forgotten
    assert_not_includes Memory.recallable, old
  end

  test "reports an unknown id" do
    response = UpdateTool.call(id: 999_999, title: "Anything", description: "Detail.")

    assert response.error?
    assert_match(/999999/, tool_text(response))
  end

  test "refuses to update an already superseded memory" do
    old = Memory.create!(title: "The retry budget is three attempts", description: "Set in 2025.")
    current = Memory.create!(title: "The retry budget is five attempts", description: "Raised today.")
    old.supersede_with!(current)

    response = UpdateTool.call(id: old.id, title: "The retry budget is nine attempts", description: "Raised again.")

    assert response.error?
    assert_match(/#{current.id}/, tool_text(response))
  end

  test "rejects a blank title without recording anything" do
    old = Memory.create!(title: "The retry budget is three attempts", description: "Set in 2025.")

    assert_no_difference -> { Memory.count } do
      response = UpdateTool.call(id: old.id, title: "  ", description: "Detail.")

      assert response.error?
    end
    assert_nil old.reload.superseded_by_id
  end

  test "is declared with the arguments it needs" do
    assert_equal "update", UpdateTool.tool_name
    assert_equal %w[ id title description ], UpdateTool.input_schema.to_h[:required]
  end
end
