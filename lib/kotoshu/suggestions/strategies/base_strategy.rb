# frozen_string_literal: true

module Kotoshu
  module Suggestions
    module Strategies
      # Base class for suggestion strategies.
      #
      # Subclasses must implement the {#generate} method.
      #
      # @example Implementing a custom strategy
      #   class MyStrategy < BaseStrategy
      #     def generate(context)
      #       # Return suggestions based on context.word
      #       SuggestionSet.from_words(%w[word1 word2], source: :my_strategy)
      #     end
      #   end
      class BaseStrategy
        # @return [Symbol] Strategy name
        attr_reader :name

        # @return [Hash] Strategy configuration
        attr_reader :config

        # Create a new base strategy.
        #
        # @param name [String, Symbol] Strategy name
        # @param config [Hash] Configuration options
        # @option config [Integer] max_results Maximum results to return
        # @option config [Boolean] enabled Whether strategy is enabled
        def initialize(name: :base, **config)
          @name = name.to_sym
          @config = config
          @enabled = config.fetch(:enabled, true)
          @max_results = config.fetch(:max_results, 10)
        end

        # Generate suggestions for a word.
        #
        # @abstract Subclasses must implement this method.
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Generated suggestions
        # @raise [NotImplementedError] Subclass must implement
        def generate(context)
          raise NotImplementedError, "#{self.class} must implement #generate"
        end

        # Check if this strategy is enabled.
        #
        # @return [Boolean] True if enabled
        def enabled?
          @enabled
        end

        # Get the max results configuration.
        #
        # @param default [Integer] Default value if not set
        # @return [Integer] Max results
        def max_results(default = 10)
          @max_results || default
        end

        # Get a configuration value.
        #
        # @param key [Symbol] The config key
        # @param default [Object] Default value if not set
        # @return [Object] The config value
        def get_config(key, default = nil)
          @config.fetch(key, default)
        end

        # Check if a config value is present.
        #
        # @param key [Symbol] The config key
        # @return [Boolean] True if config has the key
        def has_config?(key)
          @config.key?(key)
        end

        # Get the priority for this strategy.
        #
        # @return [Integer] Priority (lower = higher priority)
        def priority
          @config.fetch(:priority, 100)
        end

        # Check if this strategy should handle the context.
        #
        # Default implementation checks if the word is not in the dictionary.
        # Subclasses can override for more specific logic.
        #
        # @param context [Context] The suggestion context
        # @return [Boolean] True if the strategy should handle this context
        def handles?(context)
          return false unless enabled?

          !dictionary_lookup(context, context.word)
        end

        # Create a suggestion from a word.
        #
        # @param word [String] The suggested word
        # @param distance [Integer] Edit distance
        # @param confidence [Float] Confidence score
        # @param metadata [Hash] Additional metadata for ranking
        # @return [Suggestion] New suggestion
        def create_suggestion(word, distance: 0, confidence: 1.0, **metadata)
          Suggestion.new(
            word: word,
            distance: distance,
            confidence: confidence,
            source: @name,
            **metadata
          )
        end

        # Create a suggestion set from words.
        #
        # @param words [Array<String>] Array of words
        # @param distances [Hash] Optional word => distance mapping
        # @param original_word [String] The original misspelled word (for ranking)
        # @return [SuggestionSet] New suggestion set
        def create_suggestion_set(words, distances: {}, original_word: nil)
          suggestions = words.map do |word|
            # Try case-sensitive first, then case-insensitive for distance lookup
            distance = if distances.key?(word)
                        distances[word]
                      else
                        distances.fetch(word.downcase, 1)
                      end
            confidence = calculate_confidence(distance)

            # Calculate n-gram similarity (like Hunspell) for better ranking
            ngram_score = if original_word
                            calculate_ngram_similarity(original_word, word)
                          else
                            0
                          end

            metadata = {
              original_length: original_word&.length || word.length,
              ngram_score: ngram_score
            }

            create_suggestion(word, distance: distance, confidence: confidence, **metadata)
          end
          SuggestionSet.new(suggestions, max_size: max_results)
        end

        # Calculate typo correction similarity between two words.
        #
        # This is a custom similarity metric designed specifically for spelling
        # correction, combining:
        # - Character overlap (how many characters are shared)
        # - Prefix weight (common prefix is very important for typos)
        # - Suffix weight (common ending is also important)
        # - Length penalty (very different lengths are less similar)
        #
        # Returns a value from 0.0 (no similarity) to 1.0 (identical).
        #
        # @param word1 [String] First word
        # @param word2 [String] Second word
        # @return [Float] Typo correction similarity (0.0 to 1.0)
        def calculate_ngram_similarity(word1, word2)
          return 0 if word1.nil? || word2.nil? || word1.empty? || word2.empty?

          w1 = word1.downcase
          w2 = word2.downcase

          # Identical strings have maximum similarity
          return 1.0 if w1 == w2

          len1 = w1.length
          len2 = w2.length
          max_len = [len1, len2].max

          # Calculate common prefix length (up to 4 characters)
          prefix_len = 0
          (0...[len1, len2, 4].min).each do |i|
            break if w1[i] != w2[i]
            prefix_len += 1
          end

          # Calculate common suffix length
          suffix_len = 0
          (1..[len1, len2, 4].min).each do |i|
            break if w1[-i] != w2[-i]
            suffix_len += 1
          end

          # Calculate character overlap (how many characters from w1 are in w2)
          w2_chars = w2.chars
          overlap = w1.chars.count { |c| w2_chars.include?(c) }

          # Calculate similarity score
          # 1. Base score from character overlap
          similarity = overlap.to_f / max_len

          # 2. Prefix bonus (common start is very important for typos)
          prefix_bonus = prefix_len * 0.15

          # 3. Suffix bonus (common ending is also important)
          suffix_bonus = suffix_len * 0.05

          # 4. Length penalty (very different lengths are less similar)
          length_diff = (len1 - len2).abs
          length_penalty = length_diff * 0.1

          # Combine all factors
          similarity = similarity + prefix_bonus + suffix_bonus - length_penalty

          # Cap at 1.0, floor at 0.0
          [[similarity, 1.0].min, 0.0].max
        end

        # Generate n-grams for a word.
        #
        # @param word [String] The word
        # @param n [Integer] N-gram size
        # @return [Set<String>] Set of n-grams
        def generate_ngrams(word, n)
          ngrams = Set.new
          (word.length - n + 1).times do |i|
            ngrams.add(word[i, n])
          end
          ngrams
        end

        # Convert strategy to string.
        #
        # @return [String] String representation
        def to_s
          "#{self.class.name}(name: #{@name}, enabled: #{enabled?})"
        end
        alias inspect to_s

        private

        # Look up a word in the dictionary.
        #
        # @param context [Context] The suggestion context
        # @param word [String] The word to look up
        # @return [Boolean] True if word exists
        def dictionary_lookup(context, word)
          dictionary = context.dictionary

          # Check if it's a dictionary backend with lookup method
          if dictionary.respond_to?(:lookup)
            dictionary.lookup(word)
          elsif dictionary.is_a?(::Kotoshu::Core::IndexedDictionary)
            dictionary.has_word?(word)
          elsif dictionary.respond_to?(:include?)
            dictionary.include?(word)
          elsif dictionary.is_a?(Hash)
            dictionary.key?(word)
          else
            false
          end
        end

        # Get all words from the dictionary.
        #
        # @param context [Context] The suggestion context
        # @return [Array<String>] All words
        def dictionary_words(context)
          dictionary = context.dictionary

          if dictionary.respond_to?(:words)
            dictionary.words
          elsif dictionary.is_a?(Array)
            dictionary
          elsif dictionary.is_a?(Hash)
            dictionary.keys
          elsif dictionary.is_a?(::Kotoshu::Core::IndexedDictionary)
            dictionary.words
          else
            []
          end
        end

        # Calculate confidence from distance.
        #
        # Higher distance = lower confidence.
        #
        # @param distance [Integer] Edit distance
        # @return [Float] Confidence score (0.0 to 1.0)
        def calculate_confidence(distance)
          return 1.0 if distance.zero?

          # Simple decay: confidence = 1 / (1 + distance)
          # Can be overridden by subclasses for more sophisticated calculations
          1.0 / (1.0 + distance)
        end
      end
    end
  end
end
