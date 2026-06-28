# frozen_string_literal: true

module Kotoshu
  module Metrics
    # Thread-safe metrics collector.
    #
    # Tracks performance metrics for spellchecking operations:
    # - Lookup counts and timing
    # - Cache hit/miss rates
    # - Suggestion generation stats
    #
    # @example
    #   collector = Kotoshu::Metrics::Collector.new
    #   collector.record_lookup("hello", result: true, time: 0.5)
    #   collector.stats
    #   # => { lookups: 1, correct_lookups: 1, avg_lookup_time: 0.5, ... }
    class Collector
      # Initialize a new collector.
      def initialize
        @mutex = Mutex.new
        reset
      end

      # Record a lookup operation.
      #
      # @param word [String] The word being looked up
      # @param result [Boolean] The lookup result
      # @param time [Float] Time taken in milliseconds
      def record_lookup(_word, result:, time:)
        @mutex.synchronize do
          @metrics[:lookups] += 1
          @metrics[:correct_lookups] += 1 if result
          @metrics[:misspelled_lookups] += 1 unless result

          @metrics[:lookup_times] << time
        end
      end

      # Record a cache operation.
      #
      # @param cache_type [String] Type of cache (lookup, suggestion)
      # @param hit [Boolean] True if cache hit
      def record_cache(cache_type, hit:)
        @mutex.synchronize do
          key = :"#{cache_type}_cache_hits"
          miss_key = :"#{cache_type}_cache_misses"

          if hit
            @metrics[key] += 1
          else
            @metrics[miss_key] += 1
          end
        end
      end

      # Record suggestion generation.
      #
      # @param word [String] The input word
      # @param count [Integer] Number of suggestions generated
      # @param time [Float] Time taken in milliseconds
      def record_suggestions(_word, count:, time:)
        @mutex.synchronize do
          @metrics[:suggestion_requests] += 1
          @metrics[:suggestions_generated] += count

          @metrics[:suggestion_times] << time
        end
      end

      # Get current metrics statistics.
      #
      # @return [Hash] Current statistics with computed averages
      def stats
        @mutex.synchronize do
          calculate_stats
        end
      end

      # Reset all metrics.
      def reset
        @mutex.synchronize do
          @metrics = {
            lookups: 0,
            correct_lookups: 0,
            misspelled_lookups: 0,
            lookup_times: [],

            lookup_cache_hits: 0,
            lookup_cache_misses: 0,
            suggestion_cache_hits: 0,
            suggestion_cache_misses: 0,

            suggestion_requests: 0,
            suggestions_generated: 0,
            suggestion_times: [],

            started_at: Time.now
          }
        end
      end

      # Export metrics in StatsD format.
      #
      # @return [String] StatsD protocol lines
      def to_statsd
        s = stats
        prefix = "kotoshu"

        lines = []
        lines << "#{prefix}.lookups:#{s[:lookups]}|c"
        lines << "#{prefix}.correct_lookups:#{s[:correct_lookups]}|c"
        lines << "#{prefix}.misspelled_lookups:#{s[:misspelled_lookups]}|c"
        lines << "#{prefix}.avg_lookup_time:#{s[:avg_lookup_time]}|ms"
        lines << "#{prefix}.lookup_cache_hits:#{s[:lookup_cache_hits]}|c"
        lines << "#{prefix}.lookup_cache_misses:#{s[:lookup_cache_misses]}|c"
        lines << "#{prefix}.suggestion_requests:#{s[:suggestion_requests]}|c"
        lines << "#{prefix}.suggestions_generated:#{s[:suggestions_generated]}|c"
        lines << "#{prefix}.avg_suggestion_time:#{s[:avg_suggestion_time]}|ms"

        lines.join("\n")
      end

      # Export metrics in Prometheus exposition format.
      #
      # @return [String] Prometheus format
      def to_prometheus
        s = stats

        lines = []
        lines << "# HELP kotoshu_lookups Total number of word lookups"
        lines << "# TYPE kotoshu_lookups counter"
        lines << "kotoshu_lookups #{s[:lookups]}"

        lines << "# HELP kotoshu_correct_lookups Number of correct word lookups"
        lines << "# TYPE kotoshu_correct_lookups counter"
        lines << "kotoshu_correct_lookups #{s[:correct_lookups]}"

        lines << "# HELP kotoshu_misspelled_lookups Number of misspelled word lookups"
        lines << "# TYPE kotoshu_misspelled_lookups counter"
        lines << "kotoshu_misspelled_lookups #{s[:misspelled_lookups]}"

        lines << "# HELP kotoshu_avg_lookup_time Average lookup time in milliseconds"
        lines << "# TYPE kotoshu_avg_lookup_time gauge"
        lines << "kotoshu_avg_lookup_time #{s[:avg_lookup_time]}"

        lines << "# HELP kotoshu_lookup_cache_hits Number of lookup cache hits"
        lines << "# TYPE kotoshu_lookup_cache_hits counter"
        lines << "kotoshu_lookup_cache_hits #{s[:lookup_cache_hits]}"

        lines << "# HELP kotoshu_lookup_cache_misses Number of lookup cache misses"
        lines << "# TYPE kotoshu_lookup_cache_misses counter"
        lines << "kotoshu_lookup_cache_misses #{s[:lookup_cache_misses]}"

        lines << "# HELP kotoshu_suggestion_requests Number of suggestion requests"
        lines << "# TYPE kotoshu_suggestion_requests counter"
        lines << "kotoshu_suggestion_requests #{s[:suggestion_requests]}"

        lines << "# HELP kotoshu_suggestions_generated Total number of suggestions generated"
        lines << "# TYPE kotoshu_suggestions_generated counter"
        lines << "kotoshu_suggestions_generated #{s[:suggestions_generated]}"

        lines << "# HELP kotoshu_avg_suggestion_time Average suggestion generation time in milliseconds"
        lines << "# TYPE kotoshu_avg_suggestion_time gauge"
        lines << "kotoshu_avg_suggestion_time #{s[:avg_suggestion_time]}"

        lines.join("\n")
      end

      private

      # Calculate computed statistics.
      #
      # @return [Hash] Statistics with computed values
      def calculate_stats
        lookup_times = @metrics[:lookup_times]
        suggestion_times = @metrics[:suggestion_times]

        avg_lookup = lookup_times.empty? ? 0 : lookup_times.sum / lookup_times.size
        avg_suggestion = suggestion_times.empty? ? 0 : suggestion_times.sum / suggestion_times.size

        lookup_hit_rate = calculate_hit_rate(@metrics[:lookup_cache_hits], @metrics[:lookup_cache_misses])
        suggestion_hit_rate = calculate_hit_rate(@metrics[:suggestion_cache_hits], @metrics[:suggestion_cache_misses])

        {
          lookups: @metrics[:lookups],
          correct_lookups: @metrics[:correct_lookups],
          misspelled_lookups: @metrics[:misspelled_lookups],
          avg_lookup_time: avg_lookup.round(3),

          lookup_cache_hits: @metrics[:lookup_cache_hits],
          lookup_cache_misses: @metrics[:lookup_cache_misses],
          lookup_cache_hit_rate: lookup_hit_rate,

          suggestion_cache_hits: @metrics[:suggestion_cache_hits],
          suggestion_cache_misses: @metrics[:suggestion_cache_misses],
          suggestion_cache_hit_rate: suggestion_hit_rate,

          suggestion_requests: @metrics[:suggestion_requests],
          suggestions_generated: @metrics[:suggestions_generated],
          avg_suggestions_per_request: if @metrics[:suggestion_requests].positive?
                                         (@metrics[:suggestions_generated].to_f / @metrics[:suggestion_requests]).round(2)
                                       else
                                         0
                                       end,
          avg_suggestion_time: avg_suggestion.round(3),

          uptime_seconds: (Time.now - @metrics[:started_at]).round(2)
        }
      end

      # Calculate cache hit rate.
      #
      # @param hits [Integer] Number of hits
      # @param misses [Integer] Number of misses
      # @return [Float] Hit rate (0-1)
      def calculate_hit_rate(hits, misses)
        total = hits + misses
        total.positive? ? (hits.to_f / total).round(4) : 0.0
      end
    end
  end
end
