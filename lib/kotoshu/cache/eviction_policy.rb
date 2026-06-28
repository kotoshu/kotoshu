# frozen_string_literal: true

module Kotoshu
  module Cache
    # Pure value object: given a max total size and a list of cache
    # entries, decide which entries to evict to fit under the cap.
    #
    # The policy is LRU by +cached_at+ timestamp (oldest evicted first).
    # It performs no IO and has no concept of what an "entry" actually
    # is on disk — it just sees a flat list of records each carrying
    # +:path+, +:size+, +:cached_at+, and returns a plan. BaseCache#evict
    # is responsible for collecting those records and executing the plan.
    #
    # ISO8601 timestamps sort lexicographically because they are
    # zero-padded, so the policy can compare them as plain strings
    # without parsing. Entries with a nil +cached_at+ sort oldest
    # (treated as the epoch) so they are evicted first — a corrupt
    # metadata.json should not strand an entry forever.
    class EvictionPolicy
      # @return [Integer] maximum total size in bytes
      attr_reader :max_size

      # @param max_size [Integer, #to_i] maximum total size in bytes
      # @raise [ArgumentError] if max_size is negative
      def initialize(max_size:)
        @max_size = max_size.to_i
        return unless @max_size.negative?

        raise ArgumentError, "max_size must be >= 0"
      end

      # Decide which entries to evict.
      #
      # @param entries [Array<Hash>] each hash has :path (String),
      #   :size (Integer), :cached_at (String, ISO8601, or nil)
      # @return [Hash] { evict: Array<Hash>, keep: Array<Hash>,
      #   bytes_reclaimed: Integer }
      def plan(entries)
        sorted = entries.sort_by { |e| sort_key(e[:cached_at]) }
        total = sorted.sum { |e| e[:size].to_i }

        return { evict: [], keep: sorted, bytes_reclaimed: 0 } if total <= max_size

        evict = []
        reclaimed = 0
        sorted.each do |e|
          break if total - reclaimed <= max_size

          evict << e
          reclaimed += e[:size].to_i
        end

        { evict: evict, keep: sorted - evict, bytes_reclaimed: reclaimed }
      end

      private

      # ISO8601 strings sort correctly as strings; nil sorts first so
      # entries with missing timestamps are evicted ahead of any valid
      # entry.
      def sort_key(cached_at)
        cached_at || ""
      end
    end
  end
end
