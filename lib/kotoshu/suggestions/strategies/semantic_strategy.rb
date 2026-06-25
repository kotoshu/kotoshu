# frozen_string_literal: true

require_relative 'base_strategy'
require_relative '../suggestion'
require_relative '../suggestion_set'
require_relative '../../embeddings'

module Kotoshu
  module Suggestions
    module Strategies
      # Semantic strategy using FastText ONNX embeddings.
      #
      # Provides embedding-based spell correction for:
      # - Typos: Re-ranks edit-distance candidates by semantic similarity
      # - Real-word errors: Detects when valid words are used incorrectly in context
      #
      # This strategy works alongside other strategies (EditDistance, Phonetic, etc.)
      # to provide comprehensive spell checking with semantic awareness.
      #
      # @example Basic usage
      #   strategy = SemanticStrategy.new(language_code: 'en')
      #   suggestions = strategy.generate(context)
      #
      # @example With preloaded embeddings (faster)
      #   strategy = SemanticStrategy.new(
      #     language_code: 'en',
      #     preload_embeddings: true
      #   )
      #   suggestions = strategy.generate(context)
      class SemanticStrategy < BaseStrategy
        # @return [String] Language code (ISO 639-1)
        attr_reader :language_code

        # @return [Embeddings::Vocabulary] The vocabulary
        attr_reader :vocabulary

        # @return [Embeddings::OnnxRuntimeModel] The ONNX model
        attr_reader :model

        # @return [Embeddings::SimilaritySearch] The similarity search
        attr_reader :search

        # Create a new semantic strategy.
        #
        # @param language_code [String] ISO 639-1 language code
        # @param cache [Cache::ModelCache, nil] Optional cache instance
        # @param preload_embeddings [Boolean] Whether to preload embeddings
        # @param max_context_window [Integer] Words to consider for context
        # @param min_semantic_similarity [Float] Minimum similarity for semantic suggestions
        # @param semantic_boost_weight [Float] Weight for semantic similarity in re-ranking
        # @param config [Hash] Additional configuration
        def initialize(language_code:, cache: nil, preload_embeddings: false,
                       max_context_window: 5, min_semantic_similarity: 0.5,
                       semantic_boost_weight: 0.3, **config)
          super(name: :semantic, **config)
          @language_code = language_code
          @max_context_window = max_context_window
          @min_semantic_similarity = min_semantic_similarity
          @semantic_boost_weight = semantic_boost_weight

          # Initialize embedding components
          initialize_embeddings(cache, preload_embeddings)
        end

        # Generate suggestions using semantic similarity.
        #
        # Handles two cases:
        # 1. Word not in vocabulary (typo): Re-ranks edit-distance candidates
        # 2. Word in vocabulary (real-word error): Finds semantically similar alternatives
        #
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Generated suggestions
        def generate(context)
          word = context.word
          max_results = context.max_results || max_results

          # Ensure embeddings are loaded
          return SuggestionSet.empty unless @search

          # Case 1: Word not in vocabulary (typo)
          unless @vocabulary.include?(word)
            return generate_for_typo(context)
          end

          # Case 2: Real-word error detection
          # Find semantically similar words that might be correct in context
          generate_for_real_word_error(context)
        end

        # Check if this strategy should handle the context.
        #
        # Semantic strategy handles:
        # - Words not in vocabulary (for typo re-ranking)
        # - Words in vocabulary (for real-word error detection)
        #
        # @param context [Context] The suggestion context
        # @return [Boolean] True if the strategy should handle this context
        def handles?(context)
          return false unless enabled?
          return false unless @search && @vocabulary

          # Handle all words - we filter in generate()
          true
        end

        # Get embedding for a word.
        #
        # @param word [String] The word
        # @return [Array<Float>, nil] Embedding vector or nil if not found
        def embedding_for(word)
          return nil unless @search

          @search.send(:get_embedding, word)
        end

        # Compute semantic similarity between two words.
        #
        # @param word1 [String] First word
        # @param word2 [String] Second word
        # @return [Float, nil] Cosine similarity or nil if either word not found
        def semantic_similarity(word1, word2)
          return nil unless @search

          @search.similarity(word1, word2)
        end

        # Find semantically similar words.
        #
        # @param word [String] The query word
        # @param k [Integer] Number of neighbors
        # @return [Array<Hash>] Array of {word, similarity} hashes
        def find_similar_words(word, k: 10)
          return [] unless @search

          @search.find_nearest(word, k: k, exclude_self: false)
        end

        # String representation.
        #
        # @return [String] String representation
        def to_s
          "SemanticStrategy(language: #{@language_code}, vocab_size: #{@vocabulary&.size || 0}, loaded: #{@search && true})"
        end
        alias inspect to_s

        private

        # Initialize embedding components.
        #
        # @param cache [Cache::ModelCache, nil] Cache instance
        # @param preload [Boolean] Whether to preload embeddings
        def initialize_embeddings(cache, preload)
          # Try to load from cache
          @search = Embeddings::SimilaritySearch.from_cache(
            @language_code,
            cache: cache,
            preload: preload
          )

          # Extract vocabulary and model from search
          if @search
            @vocabulary = @search.vocabulary
            @model = @search.model
          else
            @vocabulary = nil
            @model = nil

            warn "Warning: Could not load ONNX model for language '#{@language_code}'. Semantic strategy will be disabled." if $VERBOSE
          end
        end

        # Generate suggestions for a typo (word not in vocabulary).
        #
        # Uses semantic similarity to re-rank candidates from other strategies.
        #
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Re-ranked suggestions
        def generate_for_typo(context)
          word = context.word
          max_results = context.max_results || max_results

          # For typos, we find semantically similar words in vocabulary
          # that are also close in spelling (handled by edit distance strategy)
          neighbors = @search.find_nearest(
            word,
            k: max_results * 2,  # Get more candidates for filtering
            exclude_self: true,
            min_similarity: @min_semantic_similarity
          )

          return SuggestionSet.empty if neighbors.empty?

          # Convert to suggestions
          # Confidence is based on semantic similarity
          suggestions = neighbors.map do |neighbor|
            similarity = neighbor[:similarity]
            confidence = normalize_similarity(similarity)

            # Calculate "distance" as inverse of similarity
            # High similarity = low distance
            distance = similarity_to_distance(similarity)

            create_suggestion(
              neighbor[:word],
              distance: distance,
              confidence: confidence,
              semantic_similarity: similarity
            )
          end

          # Sort and limit
          SuggestionSet.new(suggestions, max_size: max_results)
        end

        # Generate suggestions for a real-word error.
        #
        # Finds semantically similar words that might be correct in context.
        #
        # @param context [Context] The suggestion context
        # @return [SuggestionSet] Alternative suggestions
        def generate_for_real_word_error(context)
          word = context.word
          max_results = context.max_results || max_results

          # Get context words from the surrounding text
          context_words = get_context_words(context)

          # Find semantically similar words
          neighbors = @search.find_nearest(
            word,
            k: max_results * 3,
            exclude_self: true,
            min_similarity: @min_semantic_similarity
          )

          return SuggestionSet.empty if neighbors.empty?

          # Re-rank by context similarity
          suggestions = neighbors.map do |neighbor|
            candidate_word = neighbor[:word]
            similarity = neighbor[:similarity]

            # Check if candidate makes more sense in context
            context_score = compute_context_fit(candidate_word, context_words)

            # Combine semantic similarity with context fit
            combined_score = (similarity * 0.7) + (context_score * 0.3)

            confidence = normalize_similarity(combined_score)
            distance = similarity_to_distance(combined_score)

            create_suggestion(
              candidate_word,
              distance: distance,
              confidence: confidence,
              semantic_similarity: similarity,
              context_score: context_score
            )
          end

          # Sort by combined score and limit
          SuggestionSet.new(suggestions.sort_by { |s| -s.metadata[:context_score] }, max_size: max_results)
        end

        # Get context words for semantic analysis.
        #
        # @param context [Context] The suggestion context
        # @return [Array<String>] Context words
        def get_context_words(context)
          # For now, return empty - context analysis would need full text
          # This could be extended in the future
          []
        end

        # Compute how well a word fits in context.
        #
        # @param candidate [String] Candidate word
        # @param context_words [Array<String>] Context words
        # @return [Float] Context fit score (0.0 to 1.0)
        def compute_context_fit(candidate, context_words)
          return 0.5 if context_words.empty?

          # Compute average similarity between candidate and context words
          similarities = context_words.map do |ctx_word|
            @search.similarity(candidate, ctx_word)
          end.compact

          return 0.5 if similarities.empty?

          similarities.sum / similarities.size
        end

        # Normalize similarity to confidence (0.0 to 1.0).
        #
        # @param similarity [Float] Cosine similarity (-1.0 to 1.0)
        # @return [Float] Normalized confidence (0.0 to 1.0)
        def normalize_similarity(similarity)
          # Map from [-1, 1] to [0, 1]
          ((similarity + 1) / 2.0).clamp(0.0, 1.0)
        end

        # Convert similarity to "distance" for ranking.
        #
        # @param similarity [Float] Cosine similarity (-1.0 to 1.0)
        # @return [Integer] Pseudo-distance (lower = better)
        def similarity_to_distance(similarity)
          # Map similarity to distance: higher similarity = lower distance
          # Similarity 1.0 -> distance 0
          # Similarity 0.0 -> distance 2
          # Similarity -1.0 -> distance 4
          ((1.0 - similarity) * 2).to_i.clamp(0, 5)
        end
      end
    end
  end
end
