require "test_helper"

class RecallToolTest < ActiveSupport::TestCase
  test "recalls memories matching a keyword" do
    Memory.create!(title: "Brain deploys with Kamal", description: "One command.")
    Memory.create!(title: "Ben works in the Pacific timezone", description: "UTC-8.")

    response = RecallTool.call(query: "Kamal")

    assert_not response.error?
    result = tool_json(response)
    assert_equal 1, result[:count]
    assert_equal "Brain deploys with Kamal", result[:memories].first[:title]
  end

  test "returns the newest memories when given no query" do
    Memory.create!(title: "An older memory", description: "Detail.", created_at: 2.days.ago)
    Memory.create!(title: "A newer memory", description: "Detail.", created_at: 1.hour.ago)

    titles = tool_json(RecallTool.call)[:memories].map { |memory| memory[:title] }

    assert_equal [ "A newer memory", "An older memory" ], titles
  end

  test "filters by time range" do
    Memory.create!(title: "Recorded last year", description: "Detail.", created_at: 1.year.ago)
    Memory.create!(title: "Recorded today", description: "Detail.", created_at: 1.hour.ago)

    result = tool_json(RecallTool.call(from: 1.day.ago.iso8601))

    assert_equal [ "Recorded today" ], result[:memories].map { |memory| memory[:title] }
  end

  test "accepts a bare date as well as a full timestamp" do
    Memory.create!(title: "Recorded last year", description: "Detail.", created_at: 1.year.ago)
    recent = Memory.create!(title: "Recorded today", description: "Detail.", created_at: 1.hour.ago)

    [ 1.day.ago.to_date.iso8601, 1.day.ago.utc.iso8601 ].each do |from|
      result = tool_json(RecallTool.call(from: from))

      assert_equal [ recent.title ], result[:memories].map { |memory| memory[:title] }, "failed for #{from}"
    end
  end

  # Time.zone.parse would read these as today and as the 12th of this month
  # respectively, silently applying a filter the agent never asked for.
  test "rejects a vague timestamp rather than guessing at it" do
    [ "last Tuesday-ish", "12", "yesterday", "garbage" ].each do |vague|
      response = RecallTool.call(from: vague)

      assert response.error?, "expected #{vague.inspect} to be rejected"
      assert_match(/from/i, tool_text(response))
    end
  end

  test "excludes forgotten and superseded memories" do
    Memory.create!(title: "Brain deploys with Kamal", description: "Detail.", forgotten: true)

    assert_equal 0, tool_json(RecallTool.call(query: "Kamal"))[:count]
  end

  test "counts the recall against what it returns" do
    memory = Memory.create!(title: "Brain deploys with Kamal", description: "Detail.")

    result = tool_json(RecallTool.call(query: "Kamal"))

    assert_equal 1, memory.reload.recall_count
    assert_equal 1, result[:memories].first[:recall_count]
  end

  test "honors a limit and caps it" do
    3.times { |i| Memory.create!(title: "Kamal note #{i}", description: "Detail.") }

    assert_equal 2, tool_json(RecallTool.call(query: "Kamal", limit: 2))[:count]
    assert_equal 3, tool_json(RecallTool.call(query: "Kamal", limit: 10_000))[:count]
  end

  test "reports an empty recall plainly" do
    result = tool_json(RecallTool.call(query: "elephants"))

    assert_equal 0, result[:count]
    assert_empty result[:memories]
  end

  test "takes no required arguments" do
    assert_equal "recall", RecallTool.tool_name
    assert_empty RecallTool.input_schema.to_h[:required]
  end
end
