require "test_helper"

class MemoryTest < ActiveSupport::TestCase
  test "requires a title and a description" do
    memory = Memory.new

    assert_not memory.valid?
    assert_includes memory.errors.attribute_names, :title
    assert_includes memory.errors.attribute_names, :description
  end

  test "starts out never recalled" do
    memory = Memory.create!(title: "Ben runs Postgres 16", description: "Locally, in the devcontainer.")

    assert_equal 0, memory.recall_count
    assert_nil memory.last_recalled_at
    assert_not memory.forgotten
  end

  # Recallable

  test "recallable excludes forgotten memories" do
    kept = create_memory(title: "Ben deploys with Kamal")
    forgotten = create_memory(title: "Ben deploys with Capistrano", forgotten: true)

    assert_includes Memory.recallable, kept
    assert_not_includes Memory.recallable, forgotten
  end

  test "recallable excludes superseded memories" do
    old = create_memory(title: "The retry budget is three attempts")
    new = create_memory(title: "The retry budget is five attempts")
    old.supersede_with!(new)

    assert_includes Memory.recallable, new
    assert_not_includes Memory.recallable, old
  end

  # Near-duplicate detection

  test "near_duplicates_of matches a rephrasing" do
    original = create_memory(title: "Brain deploys with Kamal")

    assert_includes Memory.near_duplicates_of("Brain deploys using Kamal"), original
  end

  test "near_duplicates_of ignores unrelated memories" do
    create_memory(title: "Ben works in the Pacific timezone")

    assert_empty Memory.near_duplicates_of("Brain uses Postgres for storage")
  end

  test "near_duplicates_of ignores forgotten and superseded memories" do
    create_memory(title: "Brain deploys with Kamal", forgotten: true)

    assert_empty Memory.near_duplicates_of("Brain deploys using Kamal")
  end

  test "near_duplicates_of returns the closest match first" do
    exact = create_memory(title: "Brain deploys with Kamal")
    looser = create_memory(title: "Brain deploys with Kamal, usually")

    assert_equal [ exact, looser ], Memory.near_duplicates_of("Brain deploys with Kamal").to_a
  end

  # Recording

  test "record! stores the memory" do
    memory, superseded = Memory.record!(title: "Ben prefers Minitest", description: "Not RSpec.")

    assert memory.persisted?
    assert_equal "Ben prefers Minitest", memory.title
    assert_empty superseded
  end

  test "record! supersedes near duplicates" do
    original = create_memory(title: "Brain deploys with Kamal")

    memory, superseded = Memory.record!(title: "Brain deploys using Kamal", description: "Via bin/kamal deploy.")

    assert_equal [ original ], superseded
    assert_equal memory, original.reload.superseded_by
    assert_not_includes Memory.recallable, original
  end

  test "record! leaves unrelated memories alone" do
    unrelated = create_memory(title: "Ben works in the Pacific timezone")

    _memory, superseded = Memory.record!(title: "Brain uses Postgres for storage", description: "With pg_trgm.")

    assert_empty superseded
    assert_nil unrelated.reload.superseded_by
  end

  test "record! does not supersede itself" do
    memory, superseded = Memory.record!(title: "A memory about itself", description: "Should not self-supersede.")

    assert_empty superseded
    assert_nil memory.reload.superseded_by
  end

  test "record! rejects a blank title" do
    assert_raises ActiveRecord::RecordInvalid do
      Memory.record!(title: "  ", description: "No title here.")
    end
  end

  # Recall

  test "recall matches on keywords" do
    kamal = create_memory(title: "Brain deploys with Kamal")
    create_memory(title: "Ben works in the Pacific timezone")

    assert_equal [ kamal ], Memory.recall(query: "Kamal")
  end

  test "recall ranks a title match above a description match" do
    in_description = create_memory(title: "Ben's release process", description: "He ships with Kamal on Fridays.")
    in_title = create_memory(title: "Kamal is the deploy tool", description: "Chosen for simplicity.")

    assert_equal [ in_title, in_description ], Memory.recall(query: "Kamal")
  end

  test "recall without a query returns the newest memories" do
    older = create_memory(title: "An older memory", created_at: 2.days.ago)
    newer = create_memory(title: "A newer memory", created_at: 1.hour.ago)

    assert_equal [ newer, older ], Memory.recall
  end

  test "recall filters by time range" do
    old = create_memory(title: "Recorded last year", created_at: 1.year.ago)
    recent = create_memory(title: "Recorded today", created_at: 1.hour.ago)

    assert_equal [ recent ], Memory.recall(from: 1.day.ago)
    assert_equal [ old ], Memory.recall(to: 1.month.ago)
  end

  test "recall excludes forgotten and superseded memories" do
    create_memory(title: "Brain deploys with Kamal", forgotten: true)

    assert_empty Memory.recall(query: "Kamal")
  end

  test "recall honors a limit" do
    3.times { |i| create_memory(title: "Kamal note number #{i}") }

    assert_equal 2, Memory.recall(query: "Kamal", limit: 2).size
  end

  test "recall bumps recall_count and last_recalled_at" do
    memory = create_memory(title: "Brain deploys with Kamal")

    recalled = Memory.recall(query: "Kamal")

    assert_equal 1, memory.reload.recall_count
    assert_not_nil memory.last_recalled_at
    assert_equal 1, recalled.first.recall_count, "returned record should reflect the bump"
  end

  test "recall leaves stats alone when nothing matches" do
    memory = create_memory(title: "Brain deploys with Kamal")

    assert_empty Memory.recall(query: "elephants")
    assert_equal 0, memory.reload.recall_count
  end

  # Supersession and forgetting

  test "supersede_with! links the old memory to the new one" do
    old = create_memory(title: "The retry budget is three attempts")
    new = create_memory(title: "The retry budget is five attempts")

    old.supersede_with!(new)

    assert_equal new, old.reload.superseded_by
    assert_includes new.supersedes, old
  end

  test "supersede_with! refuses to supersede a memory with itself" do
    memory = create_memory(title: "A lonely memory")

    assert_raises ArgumentError do
      memory.supersede_with!(memory)
    end
  end

  test "forget! marks the memory forgotten" do
    memory = create_memory(title: "Ben deploys with Capistrano")

    memory.forget!

    assert memory.reload.forgotten
  end

  private
    def create_memory(title:, description: "Some detail.", **attributes)
      Memory.create!(title: title, description: description, **attributes)
    end
end
