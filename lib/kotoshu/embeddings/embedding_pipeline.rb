# frozen_string_literal: true

# EmbeddingPipeline - Unified API for embedding-based similarity search
#
# Provides a simple, unified interface for loading vocabulary and models,
# and performing similarity search. This is the recommended entry point.
#
# @example Simple usage (one line)
#   pipeline = Kotoshu::Embeddings::EmbeddingPipeline.from_cache(language: 'en')
#
# @example Full configuration
#   pipeline = Kotoshu::Embeddings::EmbeddingPipeline.new(
#     vocabulary: vocab,
#     model: model,
#     preload: true
#   )
#
# @example Finding similar words
#   neighbors = pipeline.find_nearest('semantic', k: 5)
#   neighbors.each { |r| puts "#{r[:word]}: #{r[:similarity].round(4)}" }
#
module Kotoshu
  module Embeddings
    class EmbeddingPipeline
      # @return [Vocabulary]
      attr_reader :vocabulary

      # @return [EmbeddingModel]
      attr_reader :model

      # @return [SimilarityEngine]
      attr_reader :similarity_engine

      # @return [Search]
      attr_reader :search

      # Create pipeline from cache (one-line initialization)
      #
      # @param language [String] ISO 639-1 language code
      # @param cache [Cache::ModelCache] Cache instance
      # @param preload [Boolean] Preload embeddings into memory
      # @param index [:exact, :auto] Search index type
      # @return [EmbeddingPipeline]
      #
      # @raise [ArgumentError] If no cached model found for language
      #
      def self.from_cache(language:, cache: nil, preload: false, index: :exact)
        cache ||= Kotoshu::Cache::ModelCache.new

        vocab_path = cache.find_vocab(language)
        model_path = cache.find_model(language, :onnx)

        unless vocab_path && model_path
          raise ArgumentError, "No cached model for language: #{language}. " \
                               "Run: ruby scripts/extract_vocabularies.rb --languages=#{language}"
        end

        from_files(
          vocab_path: vocab_path,
          model_path: model_path,
          language: language,
          preload: preload,
          index: index
        )
      end

      # Create pipeline from files
      #
      # @param vocab_path [String] Path to vocabulary JSON file
      # @param model_path [String] Path to ONNX model file
      # @param language [String] Language code
      # @param preload [Boolean] Preload embeddings
      # @param index [:exact, :auto] Search index type
      # @return [EmbeddingPipeline]
      #
      def self.from_files(vocab_path:, model_path:, language:, preload: false, index: :exact)
        vocab = Vocabulary.from_file(vocab_path, language_code: language)
        model = OnnxRuntimeModel.from_file(model_path, language_code: language)

        new(
          vocabulary: vocab,
          model: model,
          preload: preload,
          index: index
        )
      end

      # Create pipeline with full configuration
      #
      # @param vocabulary [Vocabulary] Vocabulary instance
      # @param model [EmbeddingModel] Model instance
      # @param preload [Boolean] Preload embeddings
      # @param index [:exact, :ann] Search index type (:exact = brute force, :ann = FAISS/HNSW)
      # @param pre_normalize [Boolean] Pre-normalize vectors
      # @param cache_size [Integer] Embedding cache size
      #
      def initialize(vocabulary:, model:, preload: false, index: :exact, pre_normalize: false, cache_size: 1000)
        @vocabulary = vocabulary
        @model = model
        @similarity_engine = SimilarityEngine.new(pre_normalize: pre_normalize)
        @cache_size = cache_size

        # Create search engine
        @search = Search.new(
          vocabulary: vocabulary,
          model: model,
          similarity_engine: @similarity_engine,
          pre_normalize: pre_normalize
        )

        preload_embeddings! if preload
      end

      # Find k nearest neighbors for a word
      #
      # @param word [String] Query word
      # @param k [Integer] Number of neighbors
      # @param exclude_self [Boolean] Exclude query word
      # @param min_similarity [Float] Minimum similarity threshold
      # @return [Array<Hash>] Array of {word, similarity, index}
      #
      def find_nearest(word, k: 10, exclude_self: true, min_similarity: 0.0)
        @search.find_nearest(word, k: k, exclude_self: exclude_self, min_similarity: min_similarity)
      end

      # Find nearest neighbors for multiple words
      #
      # @param words [Array<String>] Query words
      # @param k [Integer] Neighbors per word
      # @return [Hash<String, Array<Hash>>]
      #
      def find_nearest_batch(words, k: 10)
        @search.find_nearest_batch(words, k: k)
      end

      # Compute similarity between two words
      #
      # @param word1 [String] First word
      # @param word2 [String] Second word
      # @return [Float, nil] Similarity or nil if either word not found
      #
      def similarity(word1, word2)
        @search.similarity(word1, word2)
      end

      # Get embedding for a word
      #
      # @param word [String] Word
      # @return [Array<Float>, nil]
      #
      def get_embedding(word)
        @model.get_embedding_for_word(word, @vocabulary)
      end

      # Get embedding by index
      #
      # @param index [Integer] Word index
      # @return [Array<Float>, nil]
      #
      def get_embedding_by_index(index)
        @model.get_embedding(index)
      end

      # Check if word exists in vocabulary
      #
      # @param word [String] Word
      # @return [Boolean]
      #
      def include?(word)
        @vocabulary.include?(word)
      end

      # Preload all embeddings into memory
      #
      # @return [self]
      #
      def preload_embeddings!
        @model.load!
        @search.preload_embeddings!
        self
      end

      # Unload model from memory
      #
      # @return [self]
      #
      def unload!
        @model.unload!
        @search.clear_cache
        self
      end

      # Get pipeline statistics
      #
      # @return [Hash]
      #
      def stats
        {
          language: @vocabulary.language_code,
          vocabulary_size: @vocabulary.size,
          embedding_dimension: @model.dimension,
          model_loaded: @model.loaded?,
          embeddings_preloaded: @search.embeddings_loaded,
          cache_stats: @search.cache_size
        }
      end

      # Get model information
      #
      # @return [Hash]
      #
      def model_info
        @model.model_info
      end

      # String representation
      #
      # @return [String]
      #
      def to_s
        "EmbeddingPipeline(language: #{@vocabulary.language_code}, " \
          "vocab_size: #{@vocabulary.size}, " \
          "dimension: #{@model.dimension}, " \
          "loaded: #{@model.loaded?})"
      end
      alias inspect to_s

      # Convenience class methods
      class << self
        # Create pipeline for a specific language (shortcut)
        #
        # @param language [String] ISO 639-1 language code
        # @param kwargs [Hash] Additional options
        # @return [EmbeddingPipeline]
        #
        alias :[] :from_cache
      end
    end
  end
end
