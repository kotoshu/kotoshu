# frozen_string_literal: true

module Kotoshu
  # Metrics and instrumentation for Kotoshu.
  #
  # Provides thread-safe collection of performance metrics:
  # - Lookup counts and timing
  # - Cache hit/miss rates
  # - Suggestion generation stats
  # - Optional export to StatsD or Prometheus
  #
  # @example Enable metrics
  #   Kotoshu::Metrics.enable
  #   Kotoshu.correct?("hello")
  #   Kotoshu::Metrics.stats
  #   # => { lookups: 1, cache_hits: 0, cache_misses: 1, ... }
  module Metrics
    class << self
      # Enable metrics collection.
      def enable
        @enabled = true
        @collector = Collector.new
      end

      # Disable metrics collection.
      def disable
        @enabled = false
        @collector = nil
      end

      # Check if metrics are enabled.
      #
      # @return [Boolean] True if enabled
      def enabled?
        @enabled ||= false
      end

      # Get the metrics collector.
      #
      # @return [Collector, nil] The collector instance
      attr_reader :collector

      # Record a lookup operation.
      #
      # @param word [String] The word being looked up
      # @param result [Boolean] The lookup result
      # @param time [Float] Time taken in milliseconds
      def record_lookup(word, result:, time:)
        return unless enabled?

        collector&.record_lookup(word, result: result, time: time)
      end

      # Record a cache operation.
      #
      # @param cache_type [String] Type of cache (lookup, suggestion)
      # @param hit [Boolean] True if cache hit
      def record_cache(cache_type, hit:)
        return unless enabled?

        collector&.record_cache(cache_type, hit: hit)
      end

      # Record suggestion generation.
      #
      # @param word [String] The input word
      # @param count [Integer] Number of suggestions generated
      # @param time [Float] Time taken in milliseconds
      def record_suggestions(word, count:, time:)
        return unless enabled?

        collector&.record_suggestions(word, count: count, time: time)
      end

      # Get current metrics statistics.
      #
      # @return [Hash] Current statistics
      def stats
        return {} unless enabled?

        collector&.stats || {}
      end

      # Reset all metrics.
      def reset
        return unless enabled?

        collector&.reset
      end

      # Get metrics as StatsD format.
      #
      # @return [String] StatsD protocol lines
      def to_statsd
        return "" unless enabled?

        collector&.to_statsd || ""
      end

      # Get metrics as Prometheus format.
      #
      # @return [String] Prometheus exposition format
      def to_prometheus
        return "" unless enabled?

        collector&.to_prometheus || ""
      end
    end
  end
end
