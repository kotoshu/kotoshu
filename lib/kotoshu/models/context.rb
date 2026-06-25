# frozen_string_literal: true

module Kotoshu
  module Models
    # Value object for text context around an error.
    #
    # Provides the surrounding text before, current, and after
    # an error location for context display and analysis.
    #
    # @example Creating context
    #   context = Context.new(
    #     before: "The quick brown",
    #     current: "fox",
    #     after: "jumps over",
    #     location: Location.new(line: 5, column: 16)
    #   )
    #   context.full_context  # => "The quick brown fox jumps over"
    class Context
      attr_reader :before, :current, :after, :location, :window, :full_context

      # Create a new context object.
      #
      # @param before [String] Text before the error
      # @param current [String] The current line/text containing the error
      # @param after [String] Text after the error
      # @param location [Documents::Location] The error location
      # @param window [Integer] Window size used for context (default: 5)
      def initialize(before:, current:, after:, location:, window: 5)
        @before = before
        @current = current
        @after = after
        @location = location
        @window = window
        @full_context = [before, current, after].compact.join("\n")
        freeze
      end

      # Get surrounding words around the error location.
      #
      # @param n [Integer] Number of words on each side (default: 3)
      # @return [Array<String>] Surrounding words
      def surrounding_words(n = 3)
        return [] if @current.nil? || @current.empty?

        words = @current.split
        return [] if words.empty?

        # Try to find the word at the error location
        target_word = word_at_location
        return words unless target_word

        idx = words.index(target_word)
        return words unless idx

        # Get n words before and after
        start_idx = [0, idx - n].max
        end_idx = [words.size - 1, idx + n].min

        words[start_idx..end_idx].to_a
      end

      # Get the word at the error location.
      #
      # @return [String, nil] The word at the error location
      def word_at_location
        return nil unless @location

        if @location.column
          # Get character at column
          return @current[@location.column] if @current && @location.column < @current.length
        end

        # For node-based locations, return the current text
        @current
      end

      # Check if this context equals another.
      #
      # @param other [Object] Another object
      # @return [Boolean] True if contexts match
      def ==(other)
        return false unless other.is_a?(Context)

        @location == other.location && @full_context == other.full_context
      end
      alias_method :eql?, :==

      # Hash code for hash table usage.
      #
      # @return [Integer] Hash code
      def hash
        [@location, @full_context].hash
      end

      # String representation.
      #
      # @return [String] Human-readable representation
      def to_s
        if @location.line
          "Line #{@location.line}: #{@full_context}"
        else
          @full_context
        end
      end
      alias_method :inspect, :to_s

      # Get context as a formatted string with error highlighting.
      #
      # @param error_word [String] The error word to highlight
      # @return [String] Formatted context with ANSI codes
      def with_highlight(error_word)
        return @full_context unless error_word

        # Find and highlight the error word
        @full_context.gsub(error_word) { |m| "\033[4m#{m}\033[0m" }
      end
    end
  end
end
