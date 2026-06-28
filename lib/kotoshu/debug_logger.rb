# frozen_string_literal: true

module Kotoshu
  module Debug
    # Debug logger for detailed spellchecking information.
    #
    # Provides structured logging for lookup operations, suggestion generation,
    # cache behavior, and decision trees.
    class Logger
      # Log levels
      LEVELS = %i[info verbose trace].freeze

      attr_reader :output, :level

      # Create a new debug logger.
      #
      # @param output [IO] Output stream (default: $stderr)
      # @param level [Symbol] Log level (:info, :verbose, :trace)
      def initialize(output: $stderr, level: :info)
        @output = output
        @level = level
        @indent = 0
      end

      # Log lookup operation.
      #
      # @param word [String] The word being looked up
      # @param result [Boolean] The lookup result
      # @param time [Float] Time taken in milliseconds
      def debug_lookup(word, result:, time:)
        return unless should_log?(:info)

        status = result ? "✓" : "✗"
        output.puts "DEBUG: lookup #{status} \"#{word}\" - #{time.round(3)}ms"
      end

      # Log suggestion generation.
      #
      # @param word [String] The input word
      # @param suggestions [Array] Generated suggestions
      # @param time [Float] Time taken in milliseconds
      def debug_suggestions(word, suggestions:, time:)
        return unless should_log?(:verbose)

        output.puts "DEBUG: suggestions for \"#{word}\" (#{time.round(3)}ms)"

        return unless should_log?(:trace)

        @indent += 2
        suggestions.each do |suggestion|
          dist = suggestion.distance
          conf = suggestion.confidence
          source = suggestion.source
          output.puts "#{' ' * @indent}#{suggestion.word} (dist: #{dist}, conf: #{conf.round(2)}, src: #{source})"
        end
        @indent -= 2
      end

      # Log cache operation.
      #
      # @param cache_type [String] Type of cache
      # @param key [String] The cache key
      # @param hit [Boolean] True if cache hit
      def debug_cache(cache_type, key, hit:)
        return unless should_log?(:trace)

        status = hit ? "HIT" : "MISS"
        output.puts "DEBUG: cache #{cache_type.upcase} #{status} \"#{key}\""
      end

      # Log decision tree.
      #
      # @param word [String] The input word
      # @param decisions [Array] Array of decision nodes
      def debug_decision_tree(word, decisions:)
        return unless should_log?(:trace)

        output.puts "DEBUG: decision tree for \"#{word}\""
        @indent += 2
        print_decisions(decisions)
        @indent -= 2
      end

      # Log info message.
      #
      # @param message [String] The message
      def info(message)
        return unless should_log?(:info)

        output.puts "DEBUG: #{message}"
      end

      # Log verbose message.
      #
      # @param message [String] The message
      def verbose(message)
        return unless should_log?(:verbose)

        output.puts "DEBUG: #{message}"
      end

      # Log trace message.
      #
      # @param message [String] The message
      def trace(message)
        return unless should_log?(:trace)

        output.puts "DEBUG: #{message}"
      end

      private

      # Check if should log at current level.
      #
      # @param required_level [Symbol] Required level
      # @return [Boolean] True if should log
      def should_log?(required_level)
        LEVELS.index(required_level) <= LEVELS.index(@level)
      end

      # Print decisions tree.
      #
      # @param decisions [Array] Decision nodes
      def print_decisions(decisions, index = 0)
        decisions.each do |decision|
          prefix = "#{' ' * @indent}#{index}. "
          output.puts "#{prefix}#{decision[:description]}"

          if should_log?(:trace) && decision[:details]
            @indent += 2
            decision[:details].each do |key, value|
              output.puts "#{' ' * @indent}#{key}: #{value}"
            end
            @indent -= 2
          end

          next unless decision[:children] && !decision[:children].empty?

          @indent += 2
          print_decisions(decision[:children], index + 1)
          @indent -= 2
        end
      end
    end
  end
end
