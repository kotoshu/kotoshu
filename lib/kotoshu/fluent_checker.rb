# frozen_string_literal: true

module Kotoshu
  class Spellchecker
    # Fluent checker for chainable configuration.
    #
    # Provides a convenient API for spell checking with method chaining.
    #
    # @example Basic usage
    #   result = Kotoshu.fluent.check("Hello wrold")
    #
    # @example With options
    #   Kotoshu.fluent
    #     .ignore_words(/https?:\/\/\S+/)
    #     .max_suggestions(5)
    #     .check("Hello wrold")
    class FluentChecker
      # @return [Spellchecker] The underlying spellchecker
      attr_reader :spellchecker

      # @return [Hash] Configuration options
      attr_reader :options

      # Create a new fluent checker.
      #
      # @param spellchecker [Spellchecker] The underlying spellchecker
      # @param options [Hash] Configuration options
      def initialize(spellchecker:, options: {})
        @spellchecker = spellchecker
        @options = options
        @progress_callback = nil
        @error_callback = nil
      end

      # Check text for spelling errors.
      #
      # @param text [String] Text to check
      # @return [Models::Result::DocumentResult] Check result
      def check(text)
        @spellchecker.check(text)
      end

      # Ignore words matching pattern.
      #
      # @param pattern [Regexp] Pattern to ignore
      # @return [FluentChecker] Self for chaining
      #
      # @example
      #   fluent.ignore_words(/https?:\/\/\S+/)
      def ignore_words(pattern)
        @options[:ignore_patterns] ||= []
        @options[:ignore_patterns] << pattern
        self
      end

      # Set maximum suggestions.
      #
      # @param max [Integer] Maximum suggestions
      # @return [FluentChecker] Self for chaining
      def max_suggestions(max)
        @options[:max_suggestions] = max
        self
      end

      # Set progress callback.
      #
      # @param block [Proc] Callback proc
      # @return [FluentChecker] Self for chaining
      def on_progress(&block)
        @progress_callback = block
        self
      end

      # Set error callback.
      #
      # @param block [Proc] Callback proc
      # @return [FluentChecker] Self for chaining
      def on_error(&block)
        @error_callback = block
        self
      end

      # Get the result.
      #
      # @return [Models::Result::ResultDocumentResult] Check result
      def result
        check(@text)
      end
    end
  end
end
