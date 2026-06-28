# frozen_string_literal: true

module Kotoshu
  module Suggestions
    module Strategies
      # SymSpell suggestion strategy.
      #
      # Uses deletion distance algorithm for fast approximate string matching.
      # Pre-computes deletion variants for all dictionary words, enabling O(1)
      # lookup for common misspellings.
      #
      # This is 10-100x faster than EditDistanceStrategy for large dictionaries.
      #
      # The algorithm works by:
      # 1. Pre-computing single deletion variants for each dictionary word
      # 2. Looking up input word's deletion variants in the pre-computed map
      # 3. Distance is inferred from the deletion level
      #
      # @see https://github.com/wolfgarbe/SymSpell Original SymSpell paper
      class SymSpellStrategy < BaseStrategy
        # Maximum deletion distance to consider
        DEFAULT_MAX_DELETION_DISTANCE = 2
        # Maximum dictionary words to process (increased for better coverage)
        DEFAULT_MAX_DICTIONARY_SIZE = 500_000
        # Enable transposition handling (slower pre-computation, better accuracy)
        DEFAULT_HANDLE_TRANSPOSITIONS = true

        # Create a new SymSpell strategy.
        #
        # @param dictionary [Object] Dictionary to use for suggestions
        # @param name [String, Symbol] Strategy name
        # @param config [Hash] Configuration options
        # @option config [Integer] max_deletion_distance Maximum deletion distance (default: 2)
        # @option config [Integer] max_results Maximum results to return (default: 10)
        # @option config [Integer] max_dictionary_size Maximum words to process (default: 500_000)
        # @option config [Boolean] handle_transpositions Generate transposition variants (default: true)
        def initialize(dictionary:, name: :symspell, **config)
          super(name: name, **config)
          @dictionary = dictionary
          @max_deletion_distance = config.fetch(:max_deletion_distance, DEFAULT_MAX_DELETION_DISTANCE)
          @max_dictionary_size = config.fetch(:max_dictionary_size, DEFAULT_MAX_DICTIONARY_SIZE)
          @handle_transpositions = config.fetch(:handle_transpositions, DEFAULT_HANDLE_TRANSPOSITIONS)
          @deletes = Hash.new { |h, k| h[k] = [] } # deletion_variant -> [original_words]
          @words = Set.new
          precompute!
        end

        # Generate suggestions using deletion distance.
        #
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Generated suggestions
        def generate(context)
          word = context.word
          max_dist = get_config(:max_deletion_distance, @max_deletion_distance)

          # Normalize to lowercase for case-insensitive matching
          word_lower = word.downcase

          # Check if word is in dictionary
          return SuggestionSet.empty if @words.include?(word_lower)

          # Collect candidates with their distances
          candidates = {}
          checked = Set.new([word_lower])

          # First, check if the input word is a deletion variant of any dictionary word
          @deletes[word_lower].each do |dict_word|
            candidates[dict_word] ||= 1
          end

          # If transpositions are enabled, check them too
          if @handle_transpositions
            generate_transpositions(word_lower).each do |transposed|
              @deletes[transposed].each do |dict_word|
                candidates[dict_word] ||= 1
              end
            end
          end

          # Generate deletion variants and check for matches
          max_dist.times do |dist|
            generate_deletions_from_set(checked).each do |variant|
              next if checked.include?(variant)

              checked.add(variant)

              # Check if variant is directly in dictionary
              candidates[variant] = dist + 1 if @words.include?(variant)

              # Check if variant maps to dictionary words
              @deletes[variant].each do |dict_word|
                # Distance = deletions from input + deletions from dict_word
                # Both reach the same variant
                candidates[dict_word] ||= dist + 2
              end
            end
          end

          # Sort by distance and create suggestions
          sorted_words = candidates.sort_by { |_, dist| dist }.map(&:first)
          create_suggestion_set(sorted_words, distances: candidates, original_word: context.word)
        end

        # Pre-compute deletion variants for all dictionary words.
        #
        # This is called during initialization and builds the index.
        def precompute!
          words = dictionary_words(@dictionary)

          words.first(@max_dictionary_size).each do |word|
            next if word.nil? || word.empty?

            word_lower = word.downcase
            @words.add(word_lower)

            # Generate only single deletion variants for efficiency
            # Multiple deletions are handled during lookup
            generate_single_deletions(word_lower).each do |variant|
              @deletes[variant] << word_lower
            end

            # Generate transposition variants if enabled
            if @handle_transpositions
              generate_transpositions(word_lower).each do |variant|
                @deletes[variant] << word_lower
              end
            end
          end
        end

        # Generate all adjacent transposition variants of a word.
        #
        # For example, "world" → ["owrld", "wrold", "wolrd", "wordl"]
        #
        # @param word [String] The word
        # @return [Array<String>] Array of variants with adjacent characters swapped
        def generate_transpositions(word)
          variants = []
          word.chars.each_with_index do |_, i|
            next if i == word.length - 1 # Can't swap last character

            variant = word.dup
            variant[i], variant[i + 1] = variant[i + 1], variant[i]
            variants << variant unless variant == word
          end
          variants
        end

        # Calculate deletion distance between two words.
        #
        # For SymSpell, this is the length of their longest common subsequence
        # based distance (minimum deletions to make them equal).
        #
        # @param str1 [String] First word
        # @param str2 [String] Second word
        # @return [Integer] Deletion distance
        def deletion_distance(str1, str2)
          return str2.length if str1.empty?
          return str1.length if str2.empty?
          return 0 if str1 == str2

          # Simple approach: find if one can be transformed to the other
          # by only deletions (check if str1 is subsequence of str2 or vice versa)
          if is_subsequence?(str1, str2)
            str2.length - str1.length
          elsif is_subsequence?(str2, str1)
            str1.length - str2.length
          else
            # Fallback to edit distance approximation
            # This shouldn't happen often with proper SymSpell usage
            lcs_len = longest_common_subsequence_length(str1, str2)
            str1.length + str2.length - (2 * lcs_len)
          end
        end

        private

        # Generate all single-deletion variants of a word.
        #
        # @param word [String] The word
        # @return [Array<String>] Array of variants with one character deleted
        def generate_single_deletions(word)
          variants = []
          word.chars.each_with_index do |_, i|
            variant = word[0...i] + word[(i + 1)..].to_s
            variants << variant unless variant.empty? || variant == word
          end
          variants
        end

        # Generate deletion variants from a set of words.
        #
        # @param words_set [Set<String>] Set of words to process
        # @return [Set<String>] New set with all single deletions
        def generate_deletions_from_set(words_set)
          result = Set.new
          words_set.each do |word|
            generate_single_deletions(word).each do |variant|
              result.add(variant)
            end
          end
          result
        end

        # Check if str1 is a subsequence of str2.
        #
        # @param str1 [String] Potential subsequence
        # @param str2 [String] String to check against
        # @return [Boolean] True if str1 is subsequence of str2
        def is_subsequence?(str1, str2)
          return true if str1.empty?
          return false if str1.length > str2.length

          i = 0
          str2.each_char do |c|
            i += 1 if c == str1[i]
            return true if i == str1.length
          end
          i == str1.length
        end

        # Calculate the length of the longest common subsequence.
        #
        # Uses dynamic programming for efficiency.
        #
        # @param str1 [String] First string
        # @param str2 [String] Second string
        # @return [Integer] LCS length
        def longest_common_subsequence_length(str1, str2)
          return 0 if str1.empty? || str2.empty?

          # Use shorter string for inner loop
          str1, str2 = str2, str1 if str1.length > str2.length

          # Previous row of DP table
          previous = Array.new(str1.length + 1, 0)

          str2.each_char do |char2|
            current = [0] # First column is always 0

            str1.each_char.with_index do |char1, i|
              current << if char1 == char2
                           previous[i] + 1
                         else
                           [current[i], previous[i + 1]].max
                         end
            end

            previous = current
          end

          previous.last
        end

        # Get all words from the dictionary.
        #
        # @param dictionary [Object] Dictionary object
        # @return [Array<String>] All words
        def dictionary_words(dictionary)
          if dictionary.respond_to?(:words)
            dictionary.words
          elsif dictionary.is_a?(Array)
            dictionary
          elsif dictionary.is_a?(Hash)
            dictionary.keys
          elsif dictionary.respond_to?(:all_words)
            dictionary.all_words
          else
            []
          end
        end
      end
    end
  end
end
