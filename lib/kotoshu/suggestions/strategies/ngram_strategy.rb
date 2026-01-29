# frozen_string_literal: true

require_relative "base_strategy"

module Kotoshu
  module Suggestions
    module Strategies
      # N-gram suggestion strategy.
      #
      # Generates suggestions by finding words with high n-gram similarity.
      # N-grams are contiguous sequences of n characters.
      #
      # @example Creating an n-gram strategy
      #   strategy = NgramStrategy.new(n: 3)
      #   result = strategy.generate(context)
      class NgramStrategy < BaseStrategy
        # Create a new n-gram strategy.
        #
        # @param name [String, Symbol] Name of the strategy
        # @param config [Hash] Configuration options
        # @option config [Integer] n N-gram size (default: 3)
        # @option config [Float] min_similarity Minimum similarity threshold (0-1)
        # @option config [Integer] max_results Maximum results to return
        def initialize(name: :ngram, **config)
          super(name: name, **config)
        end

        # Generate suggestions based on n-gram similarity.
        #
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Suggestions with high n-gram similarity
        def generate(context)
          word = context.word
          n = get_config(:n, 3)
          min_sim = get_config(:min_similarity, 0.3)

          return create_suggestion_set([]) if word.length < n

          all_words = dictionary_words(context)

          # Get n-grams for input word
          word_ngrams = extract_ngrams(word, n)

          # Calculate n-gram similarity for each dictionary word
          results = {}
          all_words.each do |dict_word|
            next if dict_word == word
            next if dict_word.length < n

            similarity = ngram_similarity(word_ngrams, dict_word, n)
            next if similarity < min_sim

            # Convert similarity to distance (higher similarity = lower distance)
            dist = ((1 - similarity) * 10).to_i
            next if dist.zero?

            results[dict_word] ||= dist
            results[dict_word] = dist if dist < results[dict_word]
          end

          # Convert to suggestions sorted by similarity
          sorted_words = results.sort_by { |_, dist| dist }.map(&:first)
          create_suggestion_set(sorted_words)
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

        # Extract n-grams from a word.
        #
        # @param word [String] The word
        # @param n [Integer] N-gram size
        # @return [Hash] N-gram to count mapping
        def extract_ngrams(word, n)
          ngrams = Hash.new(0)

          (word.length - n + 1).times do |i|
            ngram = word[i...i + n]
            ngrams[ngram] += 1
          end

          ngrams
        end

        # Calculate n-gram similarity between two words.
        #
        # Uses the Jaccard similarity coefficient:
        # similarity = |intersection| / |union|
        #
        # @param word_ngrams [Hash] N-grams for the first word
        # @param other_word [String] The second word
        # @param n [Integer] N-gram size
        # @return [Float] Similarity score (0-1)
        def ngram_similarity(word_ngrams, other_word, n)
          other_ngrams = extract_ngrams(other_word, n)

          # Calculate intersection
          intersection = 0
          word_ngrams.each do |ngram, count|
            other_count = other_ngrams[ngram]
            intersection += [count, other_count].min if other_count
          end

          # Calculate union
          all_ngrams = word_ngrams.keys | other_ngrams.keys
          union = 0
          all_ngrams.each do |ngram|
            union += [word_ngrams[ngram] || 0, other_ngrams[ngram] || 0].max
          end

          return 0.0 if union.zero?

          intersection.to_f / union
        end
      end
    end
  end
end
