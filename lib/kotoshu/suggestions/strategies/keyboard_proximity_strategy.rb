# frozen_string_literal: true

require_relative "base_strategy"

module Kotoshu
  module Suggestions
    module Strategies
      # Keyboard proximity suggestion strategy.
      #
      # Generates suggestions by finding words that can be formed by
      # substituting adjacent keys on a QWERTY keyboard.
      #
      # @example Creating a keyboard proximity strategy
      #   strategy = KeyboardProximityStrategy.new
      #   result = strategy.generate(context)
      class KeyboardProximityStrategy < BaseStrategy
        # QWERTY keyboard layout (US).
        #
        # Each key maps to its adjacent keys.
        KEYBOARD_LAYOUT = {
          "`" => ["1", "tab"],
          "1" => ["`", "2", "q"],
          "2" => ["1", "3", "w", "q"],
          "3" => ["2", "4", "e", "w"],
          "4" => ["3", "5", "r", "e"],
          "5" => ["4", "6", "t", "r"],
          "6" => ["5", "7", "y", "t"],
          "7" => ["6", "8", "u", "y"],
          "8" => ["7", "9", "i", "u"],
          "9" => ["8", "0", "o", "i"],
          "0" => ["9", "p", "o"],
          "-" => ["0", "="],
          "=" => ["-"],
          "q" => ["tab", "w", "a", "1"],
          "w" => ["q", "e", "a", "s", "2"],
          "e" => ["w", "r", "s", "d", "3"],
          "r" => ["e", "t", "d", "f", "4"],
          "t" => ["r", "y", "f", "g", "5"],
          "y" => ["t", "u", "g", "h", "6"],
          "u" => ["y", "i", "h", "j", "7"],
          "i" => ["u", "o", "j", "k", "8"],
          "o" => ["i", "p", "k", "l", "9"],
          "p" => ["o", "l", ";", "0"],
          "[" => ["p", "'"],
          "]" => ["enter", "\\"],
          "\\" => ["enter"],  # Backslash neighbors
          "a" => ["caps", "s", "z", "q"],
          "s" => ["a", "d", "z", "x", "w"],
          "d" => ["s", "f", "x", "c", "e"],
          "f" => ["d", "g", "c", "v", "r"],
          "g" => ["f", "h", "v", "b", "t"],
          "h" => ["g", "j", "b", "n", "y"],
          "j" => ["h", "k", "n", "m", "u"],
          "k" => ["j", "l", "m", ",", "i"],
          "l" => ["k", ";", ",", ".", "o"],
          ";" => ["l", "'", ".", "p"],
          "'" => [";"],
          "z" => ["shift", "s", "x", "a"],
          "x" => ["z", "c", "s", "d"],
          "c" => ["x", "v", "d", "f"],
          "v" => ["c", "b", "f", "g"],
          "b" => ["v", "n", "g", "h"],
          "n" => ["b", "m", "h", "j"],
          "m" => ["n", ",", "j", "k"],
          "," => ["m", ".", "k", "l"],
          "." => [",", "/", "l", ";"],
          "/" => [".", "shift"],
          " " => []  # Space has no neighbors
        }.freeze

        # Create a new keyboard proximity strategy.
        #
        # @param name [String, Symbol] Name of the strategy
        # @param config [Hash] Configuration options
        # @option config [Integer] max_distance Maximum keyboard distance
        # @option config [Integer] max_results Maximum results to return
        def initialize(name: :keyboard_proximity, **config)
          super(name: name, **config)
        end

        # Generate suggestions based on keyboard proximity.
        #
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Suggestions within keyboard distance
        def generate(context)
          word = context.word
          max_dist = get_config(:max_distance, 2)

          all_words = dictionary_words(context)

          # Generate keyboard variants
          variants = keyboard_variants(word, max_dist)

          # Find matching dictionary words
          results = variants.select do |variant|
            dict_word = find_word(all_words, variant)
            dict_word && dict_word != word
          end.uniq

          create_suggestion_set(results)
        end

        # Check if this strategy should handle the context.
        #
        # @param context [Context] The suggestion context
        # @return [Boolean] True if the word needs correction
        def handles?(context)
          return false unless enabled?
          !dictionary_lookup(context, context.word)
        end

        private

        # Get neighbors for a key.
        #
        # @param char [String] The character
        # @return [Array<String>] Neighbor keys
        def neighbors(char)
          KEYBOARD_LAYOUT[char.downcase] || []
        end

        # Generate keyboard variants of a word.
        #
        # @param word [String] The word
        # @param max_distance [Integer] Maximum edit distance
        # @return [Array<String>] Keyboard variants
        def keyboard_variants(word, max_distance)
          return [] if word.nil? || word.empty?

          word = word.downcase
          variants = Set.new([word])

          max_distance.times do
            new_variants = Set.new

            variants.each do |variant|
              # Generate all single-key substitutions
              variant.each_char.with_index do |char, i|
                neighbors(char).each do |neighbor|
                  new_word = variant[0...i] + neighbor + variant[(i + 1)..]
                  new_variants.add(new_word)

                  # Also try insertions and deletions
                  new_variants.add(variant[0...i] + variant[(i + 1)..])  # Delete
                  new_variants.add(variant[0...i] + neighbor + variant[i..])  # Insert
                end
              end
            end

            variants = new_variants
          end

          variants.to_a
        end

        # Find a word in the dictionary (case-insensitive).
        #
        # @param all_words [Array<String>] All dictionary words
        # @param word [String] The word to find
        # @return [String, nil] The dictionary word or nil
        def find_word(all_words, word)
          return nil if word.nil? || word.empty?

          word_lower = word.downcase

          # First try exact match
          return word if all_words.include?(word_lower)

          # Then try case-insensitive search
          all_words.find { |w| w.downcase == word_lower }
        end
      end
    end
  end
end

require "set" if RUBY_VERSION < "3.0"
