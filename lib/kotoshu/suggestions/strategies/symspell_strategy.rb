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
        def initialize(dictionary: nil, name: :symspell, language_code: "en",
                       frequency_provider: nil, **config)
          super(name: name, **config)
          @dictionary = dictionary
          @language_code = language_code
          @frequency_provider = frequency_provider || FrequencyProvider.new
          @max_deletion_distance = config.fetch(:max_deletion_distance, DEFAULT_MAX_DELETION_DISTANCE)
          @max_dictionary_size = config.fetch(:max_dictionary_size, DEFAULT_MAX_DICTIONARY_SIZE)
          @handle_transpositions = config.fetch(:handle_transpositions, DEFAULT_HANDLE_TRANSPOSITIONS)
          @deletes = Hash.new { |h, k| h[k] = [] } # deletion_variant -> [original_words]
          @words = Set.new
          @ranks = {}
          @precomputed = false
          # Eager precompute only when a concrete dictionary was passed
          # (tests / one-off scripts). Production path is lazy: first
          # generate call indexes the frequency full_list for the
          # language, falling back to the context dictionary.
          precompute! if dictionary
        end

        # Generate suggestions using deletion distance.
        #
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Generated suggestions
        def generate(context)
          ensure_precomputed!(context)
          word = context.word
          max_dist = get_config(:max_deletion_distance, @max_deletion_distance)

          # Normalize to lowercase for case-insensitive matching
          word_lower = word.downcase

          # Check if word is in dictionary
          return SuggestionSet.empty if @words.include?(word_lower)

          # Union the delete-index buckets for the input and its
          # deletion neighborhood — the SymSpell candidate sweep.
          candidates = Set.new
          candidates.merge(@deletes[word_lower])

          # Generate deletion variants and union their buckets
          checked = Set.new([word_lower])
          max_dist.times do
            generate_deletions_from_set(checked).each do |variant|
              next if checked.include?(variant)

              checked.add(variant)
              candidates.add(variant) if @words.include?(variant)
              candidates.merge(@deletes[variant])
            end
          end

          candidates.delete(word_lower)

          # TRUE edit distance per candidate (with early exit) — the
          # deletion-level approximation misranked same-distance words
          # and cost 18pp of English top-1 (plan C6/C9). Sort by
          # (distance, frequency rank); rank 1 = most frequent.
          scored = candidates.filter_map do |cand|
            dist = bounded_edit_distance(word_lower, cand, max_dist + 1)
            next if dist.nil? || dist > max_dist + 1

            [cand, dist]
          end
          distances = scored.to_h
          sorted = scored.sort_by do |cand, dist|
            rank = @ranks[cand] || 1_000_000_000
            # Missing/extra double-letter is the corpus's dominant
            # single-edit class ("helo"→"hello", "commiting"→
            # "committing"); order it ahead of same-distance edits
            # regardless of frequency (plan C6; mirrors
            # EditDistanceStrategy#typo_pattern_bonus).
            [dist, double_letter_pattern?(context.word, cand) ? 0 : 1, rank]
          end
          # ranked: true — the (distance, frequency-rank) order IS the
          # product decision; base create_suggestion_set would re-sort
          # by combined_score and let its alphabetical tiebreak permute
          # distance-1 ties ("verizon" beat "version" — plan C6).
          limit = [context.max_results, max_results].min
          suggestions = sorted.first(limit).map do |cand, dist|
            ngram = calculate_ngram_similarity(context.word, cand)
            create_suggestion(
              cand, distance: dist,
                    confidence: calculate_confidence(dist),
                    original_length: context.word.length,
                    ngram_score: ngram
            )
          end
          SuggestionSet.new(suggestions, max_size: limit, ranked: true)
        end

        # Lazily build the deletion index from the best available word
        # source: frequency full_list (compact, no Hunspell junk) when
        # present for the language; otherwise the context/Hunspell
        # dictionary. Called once per strategy lifetime.
        def ensure_precomputed!(context)
          return if @precomputed

          freq_words = @frequency_provider.full_list_for(@language_code)
          if freq_words && !freq_words.empty?
            @dictionary = freq_words
            @ranks = @frequency_provider.ranks_for(@language_code)
          elsif @dictionary.nil?
            @dictionary = context.dictionary
          end
          precompute!
          @precomputed = true
        end

        # Pre-compute deletion variants for all dictionary words.
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

        # True when +candidate+ differs from +word+ by exactly one
        # doubled letter: either the candidate inserts a letter that
        # doubles its neighbour ("helo"→"hello") or the word carries a
        # doubled pair the candidate lacks ("preceeding"→"preceding").
        def double_letter_pattern?(word, candidate)
          if candidate.length == word.length + 1
            word.chars.each_cons(2).any? { |a, b| a == b } ||
              doubled_removal?(candidate, word)
          elsif word.length == candidate.length + 1
            doubled_removal?(word, candidate)
          else
            false
          end
        end

        # True when removing one letter of a doubled pair in +long+
        # yields +short+.
        def doubled_removal?(long, short)
          long.chars.each_cons(2).with_index.any? do |(a, b), i|
            next false unless a == b

            long[0...i] + long[(i + 1)..] == short
          end
        end

        # True Damerau-Levenshtein (restricted / optimal string
        # alignment) with an early-exit bound. Transpositions count as
        # one edit — the corpus's dominant error class ("teh"→"the");
        # plain Levenshtein buried them at distance 2 behind junk
        # (plan C6/C9). Returns nil once the distance provably exceeds
        # +max+ (the caller passes one past its cutoff so boundary
        # candidates survive).
        def bounded_edit_distance(a, b, max)
          return 0 if a == b

          la = a.length
          lb = b.length
          return nil if (la - lb).abs > max

          prev2 = nil
          prev = (0..lb).to_a
          (1..la).each do |i|
            cur = [i]
            row_min = i
            (1..lb).each do |j|
              sub = prev[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1)
              v = [prev[j] + 1, cur[j - 1] + 1, sub].min
              if prev2 && i > 1 && j > 1 &&
                  a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]
                v = [v, prev2[j - 2] + 1].min
              end
              cur[j] = v
              row_min = v if v < row_min
            end
            return nil if row_min > max

            prev2 = prev
            prev = cur
          end
          d = prev[lb]
          d <= max ? d : nil
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
          case dictionary
          when Kotoshu::Dictionary::Base then dictionary.words # all_words is an alias
          when Array then dictionary.dup
          when Hash then dictionary.keys
          else []
          end
        end
      end
    end
  end
end
