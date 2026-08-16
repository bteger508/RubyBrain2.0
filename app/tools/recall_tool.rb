# Recall memories by meaning or time range.
#
# Two searches answer every query and their rankings are fused: embeddings, which
# match a memory that means the same thing in other words, and full text, which
# catches the identifiers and error strings embeddings handle worst.
class RecallTool < ApplicationTool
  # Guards against an agent asking for the entire corpus in one call.
  MAX_LIMIT = 50

  class InvalidTimestamp < StandardError; end

  tool_name "recall"
  title "Recall memories"
  description <<~TEXT
    Recall memories by meaning, time range, or both. Search by what you want to
    know rather than by the words you expect to be stored: a question or a
    description of the fact works better than a bare keyword, though exact terms
    like identifiers and error strings still match. Omit the query to get the
    most recent memories. Memories that have been forgotten, or superseded by a
    newer version, are never returned. Recalling a memory counts as a use of it.
  TEXT

  input_schema(
    properties: {
      query: {
        type: "string",
        description: "What to search for, matched against titles and descriptions by meaning as well as by wording. A phrase or question works better than a single keyword."
      },
      from: {
        type: "string",
        format: "date-time",
        description: "Only recall memories recorded at or after this ISO 8601 time."
      },
      to: {
        type: "string",
        format: "date-time",
        description: "Only recall memories recorded at or before this ISO 8601 time."
      },
      limit: {
        type: "integer",
        description: "Maximum number of memories to return.",
        default: Memory::DEFAULT_RECALL_LIMIT,
        minimum: 1,
        maximum: MAX_LIMIT
      }
    },
    required: []
  )

  annotations(
    read_only_hint: true,
    idempotent_hint: true
  )

  def self.call(query: nil, from: nil, to: nil, limit: Memory::DEFAULT_RECALL_LIMIT, server_context: nil)
    memories = Memory.recall(
      query: query,
      from: timestamp(from, "from"),
      to: timestamp(to, "to"),
      limit: limit.to_i.clamp(1, MAX_LIMIT)
    )

    success(count: memories.size, memories: memories.map { |memory| serialize(memory) })
  rescue InvalidTimestamp => error
    failure(error.message)
  end

  class << self
    private
      # Strict on purpose. Time.zone.parse would read "last Tuesday-ish" as today
      # and "12" as the 12th of this month, quietly handing back a filter the
      # agent did not ask for. Better to reject it and let the agent restate.
      def timestamp(value, field)
        return nil if value.blank?

        Time.iso8601(value)
      rescue ArgumentError
        date_timestamp(value, field)
      end

      # A bare date is still unambiguous, and agents reach for one often.
      def date_timestamp(value, field)
        Date.iso8601(value).in_time_zone
      rescue ArgumentError
        raise InvalidTimestamp, unreadable(value, field)
      end

      def unreadable(value, field)
        "Could not read `#{field}` as a time: #{value.inspect}. Use ISO 8601, like 2026-08-12T09:00:00Z."
      end
  end
end
