# frozen_string_literal: true

require 'json'
require_relative "../suggestion"
require_relative "../suggestion_set"
require_relative "base_strategy"
require_relative "../../data/common_words_loader"

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
                       frequency_tiers: nil, **config)
          super(name: name, **config)
          @language_code = language_code

          # Use OOP registry for keyboard layout lookup
          @keyboard_layout = resolve_keyboard_layout(keyboard_layout)

          # Use custom frequency tiers if provided, otherwise load from Kelly data
          if frequency_tiers
            @frequency_tiers = frequency_tiers
            @common_words = Set.new
          else
            # Load frequency data for the language from Kelly JSON
            # This sets @frequency_tiers internally
            load_frequency_data(language_code)
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
          return 0 unless @frequency_tiers

          word_downcase = word.downcase

          # Top 50: 200 bonus
          return 200 if @frequency_tiers[:top_50]&.include?(word_downcase)

          # Top 200: 100 bonus
          return 100 if @frequency_tiers[:top_200]&.include?(word_downcase)

          # Top 1000: 50 bonus
          return 50 if @frequency_tiers[:top_1000]&.include?(word_downcase)

          # Not in common words: no bonus
          0
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
          min_confidence = get_config(:min_confidence, 0.75)  # Higher threshold for quality
          min_similarity = get_config(:min_jaro_similarity, 0.70)  # Minimum Jaro-Winkler similarity (0.0-1.0)
          min_results = get_config(:min_results, 3)  # Always return at least 3 suggestions if available

          # Get all dictionary words
          all_words = dictionary_words(context)

          # Calculate enhanced scores for all candidates
          candidates = []
          all_words.each do |dict_word|
            next if dict_word == word

            dist = edit_distance(word, dict_word)
            next if dist > max_dist || dist <= 0

            # Calculate enhanced score (lower is better)
            score = calculate_enhanced_score(word, dict_word, dist)
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
              normalized = (score.to_f - min_score) / score_range  # 0 to 1
              confidence = 1.0 - normalized  # Invert: lower score = higher confidence
            else
              confidence = 1.0
            end

            # Calculate Jaro-Winkler similarity for additional filtering
            jaro_similarity = calculate_ngram_similarity(word, dict_word)

            # Skip low-confidence or low-similarity suggestions (unless we need more for min_results)
            if confidence < min_confidence || jaro_similarity < min_similarity
              next if suggestions.size >= min_results
            end

            suggestions << Suggestion.new(
              word: dict_word,
              distance: dist,
              confidence: confidence,
              source: @name,
              original_length: word.length,
              ngram_score: jaro_similarity,  # Now stores Jaro-Winkler similarity (0.0-1.0)
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

          # Check for IndexedDictionary if Core module is loaded
          if defined?(::Kotoshu::Core::IndexedDictionary) && dictionary.is_a?(::Kotoshu::Core::IndexedDictionary)
            dictionary.all_words
          elsif dictionary.respond_to?(:words)
            dictionary.words
          elsif dictionary.is_a?(Hash)
            dictionary.keys
          elsif dictionary.is_a?(Set)
            dictionary.to_a
          elsif dictionary.is_a?(Array)
            dictionary
          else
            # Fallback: try to iterate
            Array(dictionary).flat_map(&:to_a)
          end
        end

        # Check if a word exists in the dictionary.
        #
        # @param context [Context] The suggestion context
        # @param word [String] The word to check
        # @return [Boolean] True if word exists
        def dictionary_lookup(context, word)
          dictionary = context.dictionary

          # First check if it's a dictionary backend with lookup method
          if dictionary.respond_to?(:lookup)
            dictionary.lookup(word)
          elsif defined?(::Kotoshu::Core::IndexedDictionary) && dictionary.is_a?(::Kotoshu::Core::IndexedDictionary)
            dictionary.has_word?(word)
          elsif dictionary.is_a?(Set)
            dictionary.include?(word)
          elsif dictionary.respond_to?(:include?)
            dictionary.include?(word)
          elsif dictionary.is_a?(Hash)
            dictionary.key?(word)
          else
            false
          end
        end

        # Calculate Damerau-Levenshtein edit distance between two strings.
        # This extends Levenshtein by treating transposition of adjacent characters as 1 operation.
        #
        # Examples:
        #   "wrold" → "world" = 1 (transposition of 'r' and 'o')
        #   "hello" → "hell" = 1 (deletion)
        #   "cat" → "cut" = 1 (substitution)
        #
        # @param str1 [String] First string
        # @param str2 [String] Second string
        # @return [Integer] Edit distance
        def edit_distance(str1, str2)
          # Handle empty strings
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

              # Check for transposition (Damerau extension)
              if i > 1 && j > 1 &&
                 str1[i - 1] == str2[j - 2] &&
                 str1[i - 2] == str2[j - 1]
                d[i][j] = [d[i][j], d[i - 2][j - 2] + 1].min
              end
            end
          end

          d[len1][len2]
        end

        # Optimized edit distance with early termination.
        # Returns early if distance exceeds threshold.
        #
        # @param str1 [String] First string
        # @param str2 [String] Second string
        # @param threshold [Integer] Maximum distance to calculate
        # @return [Integer, nil] Distance or nil if exceeds threshold
        def edit_distance_with_threshold(str1, str2, threshold)
          # For now, use the regular implementation
          # This can be optimized later with early termination
          dist = edit_distance(str1, str2)
          dist <= threshold ? dist : nil
        end

        # Calculate enhanced score combining multiple factors.
        #
        # Lower score = better suggestion
        #
        # @param original [String] The original misspelled word
        # @param suggestion [String] The suggested word
        # @param distance [Integer] Edit distance
        # @return [Float] Enhanced score (lower is better)
        def calculate_enhanced_score(original, suggestion, distance)
          score = distance * 1000.0  # Base score from edit distance

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

              if key_dist == Float::INFINITY
                # Symbol or unknown key - medium penalty
                penalty += 50
              elsif key_dist == 1
                penalty += 10  # Very likely typo (adjacent keys)
              elsif key_dist == 2
                penalty += 30  # Somewhat likely
              else
                penalty += 100  # Unlikely to be typo (far keys)
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
              if pair[0] == pair[1]  # Found double letter at positions i and i+1
                # Check if removing the second occurrence (at i+1) gives us the original word
                # For "hello" with "ll" at position 2, remove position 3: "hel" + "o" = "helo"
                expected = suggestion[0...i + 1] + suggestion[i + 2..-1]
                if expected == original
                  bonus += 300  # Strong bonus for missing double letter (MORE than transposition!)
                  break
                end
              end
            end
          end

          # Pattern 2: Extra double letter (helllo -> hello)
          if original.length == suggestion.length + 1
            # Check if original has a double letter that suggestion doesn't
            original.chars.each_cons(2).with_index do |pair, i|
              if pair[0] == pair[1]  # Found double letter in original
                # Check if removing it gives the suggestion
                reconstructed = original[0...i + 1] + original[i + 1..-1]
                if reconstructed == suggestion
                  bonus += 100  # Bonus for extra double letter
                  break
                end
              end
            end
          end

          # Pattern 3: Common prefixes/suffixes
          if original.start_with?(suggestion[0...3]) && suggestion.length > original.length
            bonus += 30  # Suggestion extends common prefix
          end

          bonus
        end

        private

        # Resolve keyboard layout using OOP registry pattern
        #
        # @param keyboard_layout [Keyboard::Layout, String, nil] Layout override
        # @return [Keyboard::Layout] Resolved layout
        def resolve_keyboard_layout(keyboard_layout)
          require_relative '../../../kotoshu/keyboard/registry'

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

        # Load frequency data for the language.
        #
        # Uses a tiered approach:
        # 1. First tries to load from local Kelly JSON files (frequency-list-kelly/data/)
        # 2. Then tries to load from GitHub frequency.json (Phase 2)
        # 3. Falls back to local YAML files (Phase 1)
        # 4. Falls back to empty set if no data available
        #
        # This follows the Open-Closed Principle: new languages are added
        # by creating new JSON/YAML files, not by modifying this class.
        #
        # @param language_code [String] ISO 639-1 language code
        # @return [Hash{Symbol => Set}] Hash with :tiers and :metadata
        # Load frequency data for the language.
        #
        # Uses a tiered approach following OOP cache pattern:
        # 1. First tries FrequencyCache (Kelly Project from GitHub with caching)
        # 2. Falls back to local YAML files (legacy)
        # 3. Falls back to empty set if no data available
        #
        # This follows the Open-Closed Principle: new languages are added
        # by creating new JSON files, not by modifying this class.
        #
        # @param language_code [String] ISO 639-1 language code
        # @return [Hash{Symbol => Set}] Hash with :tiers and :metadata
        def load_frequency_data(language_code)
          # Phase 1: Try Kelly FrequencyCache (GitHub download + local caching)
          cache_result = try_load_from_frequency_cache(language_code)
          if cache_result && cache_result[:tiers] && cache_result[:tiers][:top_1000].any?
            @frequency_tiers = cache_result[:tiers]
            return @frequency_tiers
          end

          # Phase 2: Load from local YAML files (legacy)
          yaml_data = Data::CommonWordsLoader.load(language_code)

          if yaml_data[:tiers][:top_1000].any?
            @frequency_tiers = yaml_data[:tiers]
            return @frequency_tiers
          end

          # No data available for this language
          @frequency_tiers = {
            top_50: Set.new,
            top_200: Set.new,
            top_1000: Set.new
          }
          @frequency_tiers
        end

        private

        # Try to load frequency data from FrequencyCache (OOP cache pattern).
        #
        # Uses FrequencyCache to download Kelly frequency lists from GitHub
        # with automatic caching in $XDG_CACHE_HOME/kotoshu/frequency-lists/
        #
        # @param language_code [String] ISO 639-1 language code
        # @return [Hash, nil] Frequency data or nil if not available
        def try_load_from_frequency_cache(language_code)
          require_relative '../../../kotoshu/cache/frequency_cache'

          cache = Cache::FrequencyCache.new

          # Check if language is supported by Kelly
          return nil unless cache.available_languages.include?(language_code)

          begin
            # Try to get from cache (will download if not cached or expired)
            result = cache.get(language_code)
            return result if result
          rescue StandardError => e
            warn "Warning: Failed to load frequency cache for #{language_code}: #{e.message}" if $VERBOSE
          end

          nil
        end

        # Deprecated: Use FrequencyCache instead.
        # Kept for backwards compatibility during migration.
        def try_load_from_github(language_code); end
        def try_load_from_kelly(language_code); end
        def try_load_kelly_local(language_code); end
        def try_load_kelly_from_github(language_code); end
        # Kelly Project frequency lists are stored in:
        # frequency-list-kelly/data/{language_code}.json
        #
        # @param language_code [String] ISO 639-1 language code
        # @return [Hash, nil] Frequency data or nil if not available
        def try_load_from_kelly(language_code)
          # Try local paths first
          local_data = try_load_kelly_local(language_code)
          return local_data if local_data

          # If not found locally, try downloading from GitHub
          try_load_kelly_from_github(language_code)
        end

        # Try to load Kelly data from local file paths.
        #
        # @param language_code [String] ISO 639-1 language code
        # @return [Hash, nil] Frequency data or nil if not available
        def try_load_kelly_local(language_code)
          kelly_paths = [
            # Check if we're in the kotoshu/kotoshu subdirectory
            File.expand_path('../../../../frequency-list-kelly/data', __dir__),
            # Check if we're in the kotoshu repo with frequency-list-kelly sibling
            File.expand_path('../../frequency-list-kelly/data', __dir__),
            # Check if we're in the kotoshu/lib subdirectory
            File.expand_path('../../../frequency-list-kelly/data', __dir__),
            # User's local kotoshu clone
            File.expand_path('~/src/kotoshu/frequency-list-kelly/data'),
            # Environment variable override
            ENV['KELLY_DATA_PATH']
          ].compact.uniq

          kelly_paths.each do |path|
            potential_file = File.join(path, "#{language_code}.json")
            if File.exist?(potential_file)
              begin
                return Data::CommonWordsLoader.load_from_frequency_file(potential_file)
              rescue StandardError => e
                warn "Warning: Failed to load local Kelly data for #{language_code}: #{e.message}" if $VERBOSE
              end
            end
          end

          nil
        end

        # Try to download Kelly data from GitHub.
        #
        # Kelly data is cached in $XDG_CACHE_HOME/kotoshu/frequency-lists/
        #
        # @param language_code [String] ISO 639-1 language code
        # @return [Hash, nil] Frequency data or nil if not available
        def try_load_kelly_from_github(language_code)
          require 'net/http'
          require 'fileutils'

          kelly_languages = %w[ar zh en el it no ru sv]
          return nil unless kelly_languages.include?(language_code)

          # Cache in $XDG_CACHE_HOME/kotoshu/frequency-lists/ (same pattern as dictionaries)
          cache_dir = File.join(Kotoshu::Paths.cache_path, 'frequency-lists')
          FileUtils.mkdir_p(cache_dir)

          cached_file = File.join(cache_dir, "#{language_code}.json")
          cache_ttl = 604_800 # 7 days

          # Use cached file if it exists and is recent
          if File.exist?(cached_file)
            file_age = Time.now - File.mtime(cached_file)
            if file_age < cache_ttl
              begin
                data = Data::CommonWordsLoader.load_from_frequency_file(cached_file)
                return data[:tiers]
              rescue StandardError => e
                warn "Warning: Failed to load cached Kelly data for #{language_code}: #{e.message}" if $VERBOSE
              end
            end
          end

          # Download from GitHub (kotoshu/frequency-list-kelly repository)
          url = "https://raw.githubusercontent.com/kotoshu/frequency-list-kelly/main/data/#{language_code}.json"

          begin
            warn "Downloading Kelly frequency data for #{language_code} from GitHub..." if $VERBOSE

            uri = URI(url)
            response = Net::HTTP.get(uri)

            # Validate JSON before saving
            JSON.parse(response) # Validate it's valid JSON

            # Save to cache
            File.write(cached_file, response)

            data = Data::CommonWordsLoader.load_from_frequency_file(cached_file)
            data[:tiers]
          rescue StandardError => e
            warn "Warning: Failed to download Kelly data for #{language_code}: #{e.message}" if $VERBOSE
            nil
          end
        end
      end
    end
  end
end
