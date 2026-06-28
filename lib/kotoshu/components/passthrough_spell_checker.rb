# frozen_string_literal: true

module Kotoshu
  module Components
    # Passthrough spell checker for languages that don't use spell checking.
    #
    # This checker always returns that words are "found" (correct). It's used
    # for languages that don't have traditional spell checking, such as:
    # - CJK languages (Japanese, Chinese) - use confusion rules instead
    # - Languages with purely rule-based checking
    #
    # @example
    #   checker = PassthroughSpellChecker.new
    #   result = checker.check('任意のテキスト')
    #   # => { found: true, stem: nil, flags: [] }
    #
    # @example Getting suggestions (always empty)
    #   suggestions = checker.suggest('テキスト')
    #   # => []
    class PassthroughSpellChecker < SpellChecker
      # Create a new passthrough spell checker.
      #
      # @param reason [String] Optional reason why spell checking is not used
      def initialize(reason: nil)
        @reason = reason || "Language does not use spell checking"
      end

      # Always returns that the word is "found" (correct).
      #
      # @param _word [String] The word to check (ignored)
      # @return [Hash] Always returns { found: true, stem: nil, flags: [] }
      def check(_word)
        { found: true, stem: nil, flags: [] }
      end

      # Returns no suggestions.
      #
      # Passthrough spell checkers don't provide suggestions.
      #
      # @param _word [String] The word (ignored)
      # @param _max_suggestions [Integer] Max suggestions (ignored)
      # @return [Array<Hash>] Always returns empty array
      def suggest(_word, _max_suggestions: 10)
        []
      end

      # Always returns true (all words are "correct").
      #
      # @param _word [String] The word to check (ignored)
      # @return [Boolean] Always true
      def correct?(_word)
        true
      end

      # Get the reason why spell checking is not used.
      #
      # @return [String] Reason text
      def reason
        @reason
      end

      # Check if this is a passthrough checker.
      #
      # @return [Boolean] Always true for this class
      def passthrough?
        true
      end
    end
  end
end
