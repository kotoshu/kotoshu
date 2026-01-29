# frozen_string_literal: true

module Kotoshu
  module Suggestions
    # Context object passed to suggestion strategies.
    # Encapsulates the state and parameters for suggestion generation.
    class Context
      attr_reader :word, :dictionary, :max_results, :options

      def initialize(word:, dictionary:, max_results: 10, **options)
        @word = word
        @dictionary = dictionary
        @max_results = max_results
        @options = options
      end

      # Get an option value.
      #
      # @param key [Symbol] The option key
      # @param default [Object] Default value if not found
      # @return [Object] The option value
      def option(key, default = nil)
        @options.fetch(key, default)
      end

      # Check if an option is present.
      #
      # @param key [Symbol] The option key
      # @return [Boolean] True if option exists
      def has_option?(key)
        @options.key?(key)
      end

      # Convert context to hash.
      #
      # @return [Hash] Context as hash
      def to_h
        {
          word: @word,
          dictionary: @dictionary,
          max_results: @max_results,
          options: @options
        }
      end

      # Inspect the context.
      #
      # @return [String] Inspection string
      def inspect
        "Context(word: '#{@word}', max_results: #{@max_results})"
      end
      alias to_s inspect
    end
  end
end
