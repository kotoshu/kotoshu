# frozen_string_literal: true

module Kotoshu
  module Components
    # Base class for spell checkers.
    #
    # Spell checkers validate words and provide suggestions for misspelled words.
    # Different languages use different spell checking strategies:
    # - Latin scripts: Dictionary lookup (Hunspell, Morfologik)
    # - CJK: Confusion rule checking (no dictionary)
    # - RTL: Dictionary lookup with bidirectional text handling
    #
    # @abstract Subclasses must implement #check and #suggest
    #
    # @example Checking a word
    #   checker = EnglishSpellChecker.new(aff_path: "en_US.aff", dic_path: "en_US.dic")
    #   result = checker.check("hello")
    #   # => { found: true, stem: "hello", flags: [] }
    #
    # @example Getting suggestions
    #   result = checker.check("helo")
    #   # => { found: false, stem: nil, flags: [] }
    #   suggestions = checker.suggest("helo")
    #   # => [
    #   #      { word: "hello", distance: 1, score: 0.9 },
    #   #      { word: "help", distance: 2, score: 0.7 }
    #   #    ]
    class SpellChecker
      # Check if a word is spelled correctly.
      #
      # Returns a hash with:
      # - :found (Boolean) - true if word is in dictionary
      # - :stem (String, nil) - The stem/lemma if found
      # - :flags (Array<String>) - Morphological flags
      #
      # @abstract Subclasses must implement
      # @param word [String] The word to check
      # @return [Hash] Result with :found, :stem, :flags
      # @raise [NotImplementedError] if not implemented by subclass
      def check(word)
        raise NotImplementedError, "#{self.class} must implement #check"
      end

      # Get spelling suggestions for a misspelled word.
      #
      # Returns an array of suggestion hashes with:
      # - :word (String) - The suggested word
      # - :distance (Integer) - Edit distance from original word
      # - :score (Float) - Confidence score (0-1, higher is better)
      #
      # Suggestions are sorted by relevance (highest score first).
      #
      # @abstract Subclasses must implement
      # @param word [String] The misspelled word
      # @param max_suggestions [Integer] Maximum number of suggestions to return
      # @return [Array<Hash>] Array of suggestion hashes
      # @raise [NotImplementedError] if not implemented by subclass
      def suggest(word, max_suggestions: 10)
        raise NotImplementedError, "#{self.class} must implement #suggest"
      end

      # Check if a word is spelled correctly.
      #
      # Convenience method that returns a boolean.
      #
      # @param word [String] The word to check
      # @return [Boolean] true if word is correct
      def correct?(word)
        check(word)[:found]
      end
    end
  end
end
