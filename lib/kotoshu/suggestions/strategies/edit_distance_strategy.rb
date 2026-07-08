# frozen_string_literal: true

require 'json'

module Kotoshu
  module Suggestions
    module Strategies
      # Edit distance suggestion strategy with enhanced ranking.
      # Generates suggestions by finding words with small edit distance,
      # ranked by word frequency, keyboard proximity, and common typo patterns.
      #
      # Multi-language support:
      # - Automatically selects keyboard layout based on language_code
      # - Loads frequency data from YAML files (Phase 1) or GitHub (Phase 2)
      # - Supports language-specific typo patterns
      #
      # This is MORE OOP than Spylls which uses standalone functions
      # for edit distance operations.
      #
      # Follows Open-Closed Principle: Extend by adding YAML files,
      # NOT by modifying this class.
      class EditDistanceStrategy < BaseStrategy
        attr_reader :language_code, :keyboard_layout

        # @param name [String, Symbol] Name of the strategy
        # @param config [Hash] Configuration options
        # @option config [String] :language_code Language code for keyboard layout (default: 'en')
        # @option config [Keyboard::Layout] :keyboard_layout Custom keyboard layout (optional)
        # @option config [Hash] :frequency_tiers Custom frequency tiers (optional)
        # @option config [Integer] :max_distance Maximum edit distance (default: 2)
        # @option config [Integer] :max_results Maximum results to return (default: 10)
        def initialize(name: :edit_distance, language_code: 'en', keyboard_layout: nil,
                       frequency_tiers: nil, frequency_provider: nil, **config)
          super(name: name, **config)
          @language_code = language_code

          # Use OOP registry for keyboard layout lookup
          @keyboard_layout = resolve_keyboard_layout(keyboard_layout)

          # Frequency data comes from a provider (extracted in TODO 56
          # T5.1 step 3 Phase A) so the strategy constructor no longer
          # performs disk IO or network access. Callers can inject a
          # custom provider for testing.
          @frequency_provider = frequency_provider || FrequencyProvider.new

          # Use custom frequency tiers if provided, otherwise resolve
          # lazily through the provider on first use.
          if frequency_tiers
            @frequency_tiers = frequency_tiers
            @common_words = Set.new
          else
            @frequency_tiers = nil
          end
        end

        # Public method to get current keyboard being used
        #
        # @return [Keyboard::Layout] The keyboard layout instance
        def keyboard
          @keyboard_layout
        end

        # Public method to get keyboard name
        #
        # @return [String] Keyboard layout name
        def keyboard_name
          @keyboard_layout.name
        end

        # Check if a substitution is a keyboard-adjacent typo
        #
        # @param char1 [String] First character
        # @param char2 [String] Second character
        # @return [Boolean] True if keys are adjacent
        def adjacent_key_typo?(char1, char2)
          @keyboard_layout.adjacent_keys(char1).include?(char2)
        end

        # Get adjacent keys for a given key
        #
        # @param key [String] The key to find adjacent keys for
        # @return [Array<String>] List of adjacent key characters
        def adjacent_keys(key)
          @keyboard_layout.adjacent_keys(key)
        end

        # Get frequency bonus for a word
        #
        # @param word [String] The word to check
        # @return [Integer] Frequency bonus (0-200)
        def frequency_bonus(word)
          tiers = frequency_tiers
          return 0 unless tiers

          word_downcase = word.downcase

          # Top 50: 200 bonus
          return 200 if tiers[:top_50]&.include?(word_downcase)

          # Top 200: 100 bonus
          return 100 if tiers[:top_200]&.include?(word_downcase)

          # Top 1000: 50 bonus
          return 50 if tiers[:top_1000]&.include?(word_downcase)

          # Not in common words: no bonus
          0
        end

        # Frequency tiers used for ranking. Lazy-loads from the
        # provider on first access when not set at construction.
        def frequency_tiers
          @frequency_tiers ||= @frequency_provider.tiers_for(@language_code)
        end

        # Generate suggestions based on enhanced edit distance scoring.
        #
        # Scoring factors:
        # - Edit distance (primary factor)
        # - Word frequency (common words rank higher)
        # - Keyboard proximity (adjacent key typos rank higher)
        # - Common typo patterns (missing double letters, etc.)
        #
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Suggestions within max_distance
        def generate(context)
          word = context.word
          max_dist = get_config(:max_distance, 2)
          min_confidence = get_config(:min_confidence, 0.75) # Higher threshold for quality
          min_similarity = get_config(:min_jaro_similarity, 0.70) # Minimum Jaro-Winkler similarity (0.0-1.0)
          min_results = get_config(:min_results, 3) # Always return at least 3 suggestions if available

          # When the dictionary is case-insensitive, normalize case before
          # edit-distance comparison — otherwise "HELO" can never match
          # "Hello" within distance 2 (case differences alone cost 4).
          # The original dictionary casing is preserved on the returned
          # suggestion (we only normalize for the comparison).
          case_insensitive = dictionary_case_insensitive?(context)
          compare_word = case_insensitive ? word.downcase : word

          # Get all dictionary words
          all_words = dictionary_words(context)

          # Calculate enhanced scores for all candidates
          candidates = []
          # Length filter: edit distance cannot be less than the length
          # difference. Skip dictionary words whose length differs from
          # the input by more than max_dist — they can't possibly match.
          # This is the single biggest performance win for this strategy:
          # without it, we pay the full O(m*n) DP cost on every word in
          # the dictionary.
          target_length = compare_word.length
          length_min = target_length - max_dist
          length_max = target_length + max_dist

          all_words.each do |dict_word|
            next if dict_word == word

            dict_len = dict_word.length
            next if dict_len < length_min || dict_len > length_max

            compare_dict = case_insensitive ? dict_word.downcase : dict_word
            # distance_with_threshold bails out early when the row
            # minimum exceeds max_dist — avoids computing the full
            # DP for clearly-different pairs of similar-length words.
            dist = edit_distance_with_threshold(compare_word, compare_dict, max_dist)
            next unless dist && dist > 0

            # Calculate enhanced score (lower is better)
            score = calculate_enhanced_score(compare_word, compare_dict, dist)
            candidates << [dict_word, dist, score]
          end

          # Sort by enhanced score (lower is better)
          sorted_candidates = candidates.sort_by { |_, _, score| score }

          # Calculate confidence scores with threshold filtering
          if sorted_candidates.empty?
            return SuggestionSet.empty
          end

          max_score = sorted_candidates.map { |_, _, s| s.to_f }.max
          min_score = sorted_candidates.map { |_, _, s| s.to_f }.min
          score_range = (max_score - min_score).abs

          # Create suggestions with confidence-based filtering
          suggestions = []
          sorted_candidates.each do |dict_word, dist, score|
            # Normalize score to confidence (0.0 to 1.0)
            # Lower score = higher confidence
            if score_range > 0
              normalized = (score.to_f - min_score) / score_range # 0 to 1
              confidence = 1.0 - normalized # Invert: lower score = higher confidence
            else
              confidence = 1.0
            end

            # Calculate Jaro-Winkler similarity for additional filtering.
            # Use the same case normalization as the edit distance so the
            # similarity score is consistent with the distance threshold.
            compare_dict = case_insensitive ? dict_word.downcase : dict_word
            jaro_similarity = calculate_ngram_similarity(compare_word, compare_dict)

            # Skip low-confidence or low-similarity suggestions (unless we need more for min_results)
            if (confidence < min_confidence || jaro_similarity < min_similarity) && (suggestions.size >= min_results)
              next
            end

            suggestions << Suggestion.new(
              word: dict_word,
              distance: dist,
              confidence: confidence,
              source: @name,
              original_length: word.length,
              ngram_score: jaro_similarity, # Now stores Jaro-Winkler similarity (0.0-1.0)
              enhanced_score: score
            )

            # Stop when we have enough high-quality suggestions
            break if suggestions.size >= max_results
          end

          SuggestionSet.new(suggestions, max_size: max_results)
        end

        # Check if this strategy should handle the context.
        #
        # @param context [Context] The suggestion context
        # @return [Boolean] True if the word needs correction
        def handles?(context)
          return false unless enabled?

          # Only handle if the word is not in the dictionary
          !dictionary_lookup(context, context.word)
        end

        private

        # Get all words from the dictionary.
        #
        # @param context [Context] The suggestion context
        # @return [Array<String>] All dictionary words
        def dictionary_words(context)
          dictionary = context.dictionary

          if defined?(::Kotoshu::Core::IndexedDictionary) && dictionary.is_a?(::Kotoshu::Core::IndexedDictionary)
            dictionary.all_words
          else
            case dictionary
            when Kotoshu::Dictionary::Base then dictionary.words
            when Hash then dictionary.keys
            when Set then dictionary.to_a
            when Array then dictionary.dup
            else Array(dictionary).flat_map(&:to_a)
            end
          end
        end

        # Check if a word exists in the dictionary.
        #
        # @param context [Context] The suggestion context
        # @param word [String] The word to check
        # @return [Boolean] True if word exists
        def dictionary_lookup(context, word)
          dictionary = context.dictionary

          if defined?(::Kotoshu::Core::IndexedDictionary) && dictionary.is_a?(::Kotoshu::Core::IndexedDictionary)
            dictionary.has_word?(word)
          else
            case dictionary
            when Kotoshu::Dictionary::Base then dictionary.lookup(word)
            when Hash then dictionary.key?(word)
            when Set, Array then dictionary.include?(word)
            else false
            end
          end
        end

        # Determine whether the context's dictionary treats lookups
        # case-insensitively. When true, the edit-distance and similarity
        # calculations lowercase both sides so case differences don't
        # masquerade as edit-distance penalties.
        #
        # @param context [Context] The suggestion context
        # @return [Boolean]
        def dictionary_case_insensitive?(context)
          dictionary = context.dictionary
          # PlainText and similar backends expose `case_sensitive` directly.
          # Hunspell/IndexedDictionary route case through the casing layer,
          # so we leave them case-sensitive here (their casing machinery
          # already produces the right variants upstream).
          return false unless dictionary.is_a?(::Kotoshu::Dictionary::PlainText)

          !dictionary.case_sensitive
        end

        # Calculate Damerau-Levenshtein edit distance between two strings.
        # Delegates to Algorithms::EditDistance.
        #
        # @param str1 [String] First string
        # @param str2 [String] Second string
        # @return [Integer] Edit distance
        def edit_distance(str1, str2)
          Algorithms::EditDistance.distance(str1, str2)
        end

        # Optimized edit distance with early termination.
        # Returns early if distance exceeds threshold.
        #
        # @param str1 [String] First string
        # @param str2 [String] Second string
        # @param threshold [Integer] Maximum distance to calculate
        # @return [Integer, nil] Distance or nil if exceeds threshold
        def edit_distance_with_threshold(str1, str2, threshold)
          Algorithms::EditDistance.distance_with_threshold(str1, str2, threshold)
        end

        public

        # Calculate enhanced score combining multiple factors.
        #
        # Lower score = better suggestion
        #
        # @param original [String] The original misspelled word
        # @param suggestion [String] The suggested word
        # @param distance [Integer] Edit distance
        # @return [Float] Enhanced score (lower is better)
        def calculate_enhanced_score(original, suggestion, distance)
          score = distance * 1000.0 # Base score from edit distance

          # Factor 1: Word frequency bonus (common words get lower score)
          score -= frequency_bonus(suggestion)

          # Factor 2: Keyboard proximity penalty (typo-like patterns get lower score)
          score += keyboard_penalty(original, suggestion)

          # Factor 3: Common typo pattern bonus
          # Transposition (swap adjacent chars) is the MOST common typo
          trans_bonus = transposition_bonus(original, suggestion)
          score -= trans_bonus

          # Factor 4: Missing double letter bonus (helo -> hello)
          score -= typo_pattern_bonus(original, suggestion)

          # Factor 5: Length similarity bonus (similar length is better)
          length_diff = (original.length - suggestion.length).abs
          score += length_diff * 50

          score
        end

        # Calculate bonus for transposition (swap adjacent characters).
        # This is the MOST common typing error, so it gets the highest bonus.
        #
        # @param original [String] The original word
        # @param suggestion [String] The suggested word
        # @return [Float] Transposition bonus (0 or 200)
        def transposition_bonus(original, suggestion)
          # Transposition only makes sense for same-length words
          return 0 unless original.length == suggestion.length

          o = original.downcase
          s = suggestion.downcase

          # Count transpositions needed
          transpositions = 0
          (0...o.length).each do |i|
            next if o[i] == s[i]

            # Find matching char in suggestion
            match_idx = s.index(o[i], i + 1)
            if match_idx && (match_idx == i + 1 || (match_idx > i + 1 && s[i] == o[match_idx]))
              # This is a simple adjacent swap
              transpositions += 1
            end
          end

          # Only give bonus for single transposition
          transpositions == 1 ? 200 : (transpositions * 100)
        end

        # Calculate keyboard proximity penalty.
        #
        # Substitutions between adjacent keys get lower penalty.
        # Uses OOP keyboard layout for language-aware distance calculations.
        #
        # @param original [String] The original word
        # @param suggestion [String] The suggested word
        # @return [Float] Keyboard penalty (0-200)
        def keyboard_penalty(original, suggestion)
          penalty = 0

          # Find the edit script to see what changed
          o_chars = original.chars
          s_chars = suggestion.chars

          # Simple comparison for equal-length words (substitutions)
          if o_chars.length == s_chars.length
            o_chars.each_with_index do |c1, i|
              c2 = s_chars[i]
              next if c1 == c2

              # Use OOP keyboard layout for distance calculation
              key_dist = @keyboard_layout.distance(c1, c2)

              penalty += if key_dist == Float::INFINITY
                           # Symbol or unknown key - medium penalty
                           50
                         elsif key_dist == 1
                           10  # Very likely typo (adjacent keys)
                         elsif key_dist == 2
                           30  # Somewhat likely
                         else
                           100 # Unlikely to be typo (far keys)
                         end
            end
          end

          penalty
        end

        # Calculate bonus for common typo patterns.
        #
        # @param original [String] The original word
        # @param suggestion [String] The suggested word
        # @return [Float] Pattern bonus (0-300)
        def typo_pattern_bonus(original, suggestion)
          bonus = 0

          # Pattern 1: Missing double letter (helo -> hello)
          # This is the MOST COMMON typo after transposition, give it highest bonus
          if suggestion.length == original.length + 1
            # Check if suggestion has a double letter that original is missing
            suggestion.chars.each_cons(2).with_index do |pair, i|
              if pair[0] == pair[1] # Found double letter at positions i and i+1
                # Check if removing the second occurrence (at i+1) gives us the original word
                # For "hello" with "ll" at position 2, remove position 3: "hel" + "o" = "helo"
                expected = suggestion[0...i + 1] + suggestion[i + 2..-1]
                if expected == original
                  bonus += 300 # Strong bonus for missing double letter (MORE than transposition!)
                  break
                end
              end
            end
          end

          # Pattern 2: Extra double letter (helllo -> hello)
          if original.length == suggestion.length + 1
            # Check if original has a double letter that suggestion doesn't
            original.chars.each_cons(2).with_index do |pair, i|
              if pair[0] == pair[1] # Found double letter in original
                # Check if removing it gives the suggestion
                reconstructed = original[0...i + 1] + original[i + 1..-1]
                if reconstructed == suggestion
                  bonus += 100 # Bonus for extra double letter
                  break
                end
              end
            end
          end

          # Pattern 3: Common prefixes/suffixes
          if original.start_with?(suggestion[0...3]) && suggestion.length > original.length
            bonus += 30 # Suggestion extends common prefix
          end

          bonus
        end

        private

        # Resolve keyboard layout using OOP registry pattern
        #
        # @param keyboard_layout [Keyboard::Layout, String, nil] Layout override
        # @return [Keyboard::Layout] Resolved layout
        def resolve_keyboard_layout(keyboard_layout)
          if keyboard_layout.is_a?(Keyboard::Layout)
            keyboard_layout
          elsif keyboard_layout.is_a?(String)
            Keyboard::Registry.layout_by_name(keyboard_layout)
          elsif @language_code
            Keyboard::Registry.layout_for(@language_code)
          else
            Keyboard::Registry.layout_by_name('QWERTY')
          end
        end
      end
    end
  end
end
