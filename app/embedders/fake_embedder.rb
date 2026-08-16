# An embedder that needs no API key, no network, and no model download.
#
# It is a signed hashing vectorizer: every token lands in a handful of fixed
# dimensions, so texts that share words end up pointing in similar directions
# and texts that share none end up roughly orthogonal. That is enough structure
# to rank, threshold, and fuse against in tests, and it is perfectly stable —
# the same text always yields the same vector, on any machine.
#
# What it does not model is meaning. "ships nightly" and "deploys every evening"
# are neighbours to a real embedder and strangers to this one. Tests written
# against it exercise the retrieval mechanism, not embedding quality.
class FakeEmbedder < ApplicationEmbedder
  # Four dimensions per token: enough to keep unrelated texts apart at this
  # width, few enough that a short title stays sparse.
  SLOTS_PER_TOKEN = 4

  private
    def generate(texts, _purpose)
      texts.map { |text| vector_for(text) }
    end

    def vector_for(text)
      vector = Array.new(DIMENSIONS, 0.0)

      tokenize(text).each do |token|
        # Two words per slot: one places it, one signs it. Drawing both from the
        # same word would tie the sign to the slot's parity.
        Digest::SHA256.digest(token).unpack("N8").each_slice(2) do |slot, sign|
          vector[slot % DIMENSIONS] += sign.even? ? 1.0 : -1.0
        end
      end

      normalize(vector)
    end

    def tokenize(text)
      text.to_s.downcase.scan(/[[:alnum:]]+/)
    end
end
