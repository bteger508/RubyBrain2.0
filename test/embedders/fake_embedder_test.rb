require "test_helper"

# The fake is what the whole suite ranks against, so its similarity structure is
# load-bearing rather than incidental.
class FakeEmbedderTest < ActiveSupport::TestCase
  setup { @embedder = FakeEmbedder.new }

  test "returns a unit vector of the column's width" do
    vector = @embedder.embed("Brain deploys with Kamal")

    assert_equal ApplicationEmbedder::DIMENSIONS, vector.size
    assert_in_delta 1.0, magnitude(vector), 0.000001
  end

  test "is deterministic across calls" do
    assert_equal @embedder.embed("Brain deploys with Kamal"), @embedder.embed("Brain deploys with Kamal")
  end

  test "is deterministic across instances" do
    assert_equal FakeEmbedder.new.embed("Brain deploys with Kamal"),
      FakeEmbedder.new.embed("Brain deploys with Kamal")
  end

  test "places a rephrasing nearer than an unrelated memory" do
    original = @embedder.embed("Brain deploys with Kamal")
    rephrased = @embedder.embed("Brain deploys using Kamal")
    unrelated = @embedder.embed("Ben works in the Pacific timezone")

    assert_operator similarity(original, rephrased), :>, similarity(original, unrelated)
    assert_operator similarity(original, rephrased), :>, 0.5
    assert_in_delta 0.0, similarity(original, unrelated), 0.1
  end

  test "ignores case and punctuation" do
    assert_equal @embedder.embed("Brain deploys with Kamal"), @embedder.embed("  brain, DEPLOYS: with (kamal)!  ")
  end

  test "gives blank text a usable vector rather than an undefined one" do
    # Cosine distance against a zero vector is NaN, which Postgres would happily
    # sort by.
    vector = @embedder.embed("")

    assert_in_delta 1.0, magnitude(vector), 0.000001
  end

  private
    def magnitude(vector) = Math.sqrt(vector.sum { |value| value * value })

    # Both vectors are unit length, so the dot product is the cosine.
    def similarity(one, other) = one.zip(other).sum { |a, b| a * b }
end
