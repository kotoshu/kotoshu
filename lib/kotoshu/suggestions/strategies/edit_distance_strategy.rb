# frozen_string_literal: true

require_relative "base_strategy"
require_relative "../../core/indexed_dictionary"

module Kotoshu
  module Suggestions
    module Strategies
      # Edit distance suggestion strategy.
      # Generates suggestions by finding words with small edit distance.
      #
      # This is MORE OOP than Spylls which uses standalone functions
      # for edit distance operations.
      class EditDistanceStrategy < BaseStrategy
        # @param name [String, Symbol] Name of the strategy
        # @param config [Hash] Configuration options
        # @option config [Integer] max_distance Maximum edit distance (default: 2)
        # @option config [Integer] max_results Maximum results to return (default: 10)
        def initialize(name: :edit_distance, **config)
          super(name: name, **config)
        end

        # Generate suggestions based on edit distance.
        #
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Suggestions within max_distance
        def generate(context)
          word = context.word
          max_dist = get_config(:max_distance, 2)

          # Get all dictionary words
          all_words = dictionary_words(context)

          # Calculate edit distances and find close matches
          results = {}
          all_words.each do |dict_word|
            next if dict_word == word

            dist = edit_distance(word, dict_word)
            next if dist > max_dist || dist.zero?

            # Keep the best (minimum) distance for each word
            results[dict_word] ||= dist
            results[dict_word] = dist if dist < results[dict_word]
          end

          # Convert to suggestions sorted by distance
          sorted_words = results.sort_by { |_, dist| dist }.map(&:first)
          create_suggestion_set(sorted_words, distances: results)
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

          if dictionary.is_a?(Core::IndexedDictionary)
            dictionary.all_words
          elsif dictionary.respond_to?(:words)
            dictionary.words
          elsif dictionary.is_a?(Hash)
            dictionary.keys
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
          elsif dictionary.is_a?(Core::IndexedDictionary)
            dictionary.has_word?(word)
          elsif dictionary.respond_to?(:include?)
            dictionary.include?(word)
          elsif dictionary.is_a?(Hash)
            dictionary.key?(word)
          else
            false
          end
        end

        # Calculate Levenshtein edit distance between two strings.
        # This is the classic dynamic programming algorithm.
        #
        # @param str1 [String] First string
        # @param str2 [String] Second string
        # @return [Integer] Edit distance
        def edit_distance(str1, str2)
          # Handle empty strings
          return str2.length if str1.empty?
          return str1.length if str2.empty?

          # Use smaller string for the inner loop
          if str1.length > str2.length
            str1, str2 = str2, str1
          end

          # Previous row of distances
          previous = (0..str1.length).to_a

          str2.each_char.with_index do |char2, j|
            # Current row starts with the distance for empty str1
            current = [j + 1]

            str1.each_char.with_index do |char1, i|
              # Calculate costs
              insert_cost = current[i] + 1
              delete_cost = previous[i + 1] + 1
              substitute_cost = previous[i] + (char1 == char2 ? 0 : 1)

              current << [insert_cost, delete_cost, substitute_cost].min
            end

            previous = current
          end

          previous.last
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
      end
    end
  end
end
