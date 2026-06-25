# frozen_string_literal: true

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
          "`" => %w[1 tab],
          "1" => ["`", "2", "q"],
          "2" => %w[1 3 w q],
          "3" => %w[2 4 e w],
          "4" => %w[3 5 r e],
          "5" => %w[4 6 t r],
          "6" => %w[5 7 y t],
          "7" => %w[6 8 u y],
          "8" => %w[7 9 i u],
          "9" => %w[8 0 o i],
          "0" => %w[9 p o],
          "-" => ["0", "="],
          "=" => ["-"],
          "q" => %w[tab w a 1],
          "w" => %w[q e a s 2],
          "e" => %w[w r s d 3],
          "r" => %w[e t d f 4],
          "t" => %w[r y f g 5],
          "y" => %w[t u g h 6],
          "u" => %w[y i h j 7],
          "i" => %w[u o j k 8],
          "o" => %w[i p k l 9],
          "p" => ["o", "l", ";", "0"],
          "[" => ["p", "'"],
          "]" => ["enter", "\\"],
          "\\" => ["enter"], # Backslash neighbors
          "a" => %w[caps s z q],
          "s" => %w[a d z x w],
          "d" => %w[s f x c e],
          "f" => %w[d g c v r],
          "g" => %w[f h v b t],
          "h" => %w[g j b n y],
          "j" => %w[h k n m u],
          "k" => ["j", "l", "m", ",", "i"],
          "l" => ["k", ";", ",", ".", "o"],
          ";" => ["l", "'", ".", "p"],
          "'" => [";"],
          "z" => %w[shift s x a],
          "x" => %w[z c s d],
          "c" => %w[x v d f],
          "v" => %w[c b f g],
          "b" => %w[v n g h],
          "n" => %w[b m h j],
          "m" => ["n", ",", "j", "k"],
          "," => ["m", ".", "k", "l"],
          "." => [",", "/", "l", ";"],
          "/" => [".", "shift"],
          " " => [] # Space has no neighbors
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
          min_similarity = get_config(:min_similarity, 0.70)  # Filter low-similarity suggestions

          all_words = dictionary_words(context)

          # Generate keyboard variants
          variants = keyboard_variants(word, max_dist)

          # Find matching dictionary words with their edit distances and similarity
          results_with_distances = {}
          variants.each do |variant|
            dict_word = find_word(all_words, variant)
            next unless dict_word && dict_word != word

            # Calculate edit distance from original word
            dist = edit_distance(word, dict_word)
            next if dist > max_dist

            # Calculate typo correction similarity
            similarity = calculate_ngram_similarity(word, dict_word)
            next if similarity < min_similarity  # Filter by similarity threshold

            # Keep the minimum distance for each word
            results_with_distances[dict_word] ||= dist
            results_with_distances[dict_word] = dist if dist < results_with_distances[dict_word]
          end

          # Sort by distance and create suggestions
          sorted_words = results_with_distances.sort_by { |_, dist| dist }.map(&:first)
          create_suggestion_set(sorted_words, distances: results_with_distances, original_word: word)
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

        # Calculate edit distance between two strings.
        # Uses Levenshtein distance (substitution, insertion, deletion).
        #
        # @param str1 [String] First string
        # @param str2 [String] Second string
        # @return [Integer] Edit distance
        def edit_distance(str1, str2)
          return str2.length if str1.empty?
          return str1.length if str2.empty?

          len1 = str1.length
          len2 = str2.length

          # Create a 2D array for dynamic programming
          d = Array.new(len1 + 1) { Array.new(len2 + 1, 0) }

          # Initialize the first row and column
          (0..len1).each { |i| d[i][0] = i }
          (0..len2).each { |j| d[0][j] = j }

          # Fill the matrix
          (1..len1).each do |i|
            (1..len2).each do |j|
              cost = (str1[i - 1] == str2[j - 1]) ? 0 : 1

              d[i][j] = [
                d[i - 1][j] + 1,      # deletion
                d[i][j - 1] + 1,      # insertion
                d[i - 1][j - 1] + cost  # substitution
              ].min
            end
          end

          d[len1][len2]
        end

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
                  new_variants.add(variant[0...i] + variant[(i + 1)..]) # Delete
                  new_variants.add(variant[0...i] + neighbor + variant[i..]) # Insert
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
