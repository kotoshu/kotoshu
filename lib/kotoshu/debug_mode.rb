# frozen_string_literal: true

module Kotoshu
  # Debug mode for detailed spellchecking insights.
  #
  # When enabled, debug mode provides:
  # - Lookup timing information
  # - Suggestion scoring details
  # - Decision tree visualization
  # - Cache hit/miss tracking
  # - Performance metrics
  #
  # @example Enable debug mode
  #   Kotoshu::Debug.enable
  #   Kotoshu.correct?("hello")
  #   # Output: DEBUG: lookup "hello" - 0.001ms
  #
  # @example Disable debug mode
  #   Kotoshu::Debug.disable
  module Debug
    class << self
      # Enable debug mode.
      #
      # @param output [IO] Output stream (default: $stderr)
      # @param level [Symbol] Debug level (:info, :verbose, :trace)
      def enable(output: $stderr, level: :info)
        @enabled = true
        @output = output
        @level = level
        @logger = Debug::Logger.new(output: output, level: level)
      end

      # Disable debug mode.
      def disable
        @enabled = false
        @logger = nil
      end

      # Check if debug mode is enabled.
      #
      # @return [Boolean] True if enabled
      def enabled?
        @enabled ||= false
      end

      # Get the debug logger.
      #
      # @return [Debug::Logger, nil] The logger instance
      attr_reader :logger

      # Log a lookup operation.
      #
      # @param word [String] The word being looked up
      # @param result [Boolean] The lookup result
      # @param time [Float] Time taken in milliseconds
      def log_lookup(word, result:, time:)
        return unless enabled?

        logger&.debug_lookup(word, result: result, time: time)
      end

      # Log a suggestion generation.
      #
      # @param word [String] The input word
      # @param suggestions [Array] Generated suggestions
      # @param time [Float] Time taken in milliseconds
      def log_suggestions(word, suggestions:, time:)
        return unless enabled?

        logger&.debug_suggestions(word, suggestions: suggestions, time: time)
      end

      # Log a cache hit/miss.
      #
      # @param cache_type [String] Type of cache (lookup, suggestion)
      # @param key [String] The cache key
      # @param hit [Boolean] True if cache hit
      def log_cache(cache_type, key, hit:)
        return unless enabled?

        logger&.debug_cache(cache_type, key, hit: hit)
      end

      # Log a decision tree.
      #
      # @param word [String] The input word
      # @param decisions [Array] Array of decision nodes
      def log_decision_tree(word, decisions:)
        return unless enabled?

        logger&.debug_decision_tree(word, decisions: decisions)
      end

      # Start a timing context.
      #
      # @yield Block to time
      # @return [Object] Block result
      def time(label)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000

        logger&.info("#{label}: #{elapsed.round(3)}ms")
        result
      end

      # Measure and log a lookup.
      #
      # @yield Block that performs the lookup
      # @return [Object] Block result
      def measure_lookup(word)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000

        log_lookup(word, result: result, time: elapsed)
        result
      end

      # Measure and log suggestions.
      #
      # @yield Block that generates suggestions
      # @return [Object] Block result
      def measure_suggestions(word)
        start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        result = yield
        elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - start) * 1000

        log_suggestions(word, suggestions: result, time: elapsed)
        result
      end
    end
  end
end
