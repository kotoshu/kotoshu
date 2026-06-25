# frozen_string_literal: true

module Kotoshu
  module Models
    # Abstract base class for word embedding models.
    #
    # Provides a unified interface for loading and querying word embeddings
    # from different sources (FastText, Word2Vec, GloVe, ONNX, etc.).
    #
    # @example Using an embedding model
    #   model = FastTextModel.new('cc.en.300.vec')
    #   embedding = model.embedding_for('hello')
    #   similarity = model.similarity('hello', 'world')
    #   neighbors = model.nearest_neighbors('hello', k: 10)
    #
    # @abstract Subclasses must implement {#embedding_for} and {#vocabulary}
    class EmbeddingModel
      attr_reader :language_code, :dimension, :vocabulary_size

      # Create a new embedding model.
      #
      # @param language_code [String] ISO 639-1 language code
      # @param dimension [Integer] Vector dimensionality (e.g., 300)
      def initialize(language_code:, dimension:)
        raise ArgumentError, "Language code cannot be nil" if language_code.nil?
        raise ArgumentError, "Dimension must be positive" unless dimension&.positive?

        @language_code = language_code
        @dimension = dimension
        @vocabulary_size = 0
        freeze
      end

      # Get embedding vector for a word.
      #
      # @param word [String] The word to lookup
      # @return [WordEmbedding, nil] Embedding vector or nil if not found
      # @abstract Subclass must implement
      def embedding_for(word)
        raise NotImplementedError, "#{self.class} must implement #embedding_for"
      end

      # Check if a word is in the vocabulary.
      #
      # @param word [String] The word to check
      # @return [Boolean] True if word exists in vocabulary
      def has_word?(word)
        vocabulary.include?(word)
      end

      # Calculate cosine similarity between two words.
      #
      # @param word1 [String] First word
      # @param word2 [String] Second word
      # @return [Float, nil] Similarity score (0.0 to 1.0) or nil if words not found
      def similarity(word1, word2)
        emb1 = embedding_for(word1)
        emb2 = embedding_for(word2)

        return nil unless emb1 && emb2

        emb1.similarity(emb2)
      end

      # Calculate Euclidean distance between two words.
      #
      # @param word1 [String] First word
      # @param word2 [String] Second word
      # @return [Float, nil] Distance or nil if words not found
      def distance(word1, word2)
        emb1 = embedding_for(word1)
        emb2 = embedding_for(word2)

        return nil unless emb1 && emb2

        emb1.distance(emb2)
      end

      # Find k nearest neighbors for a word.
      #
      # @param word [String] The query word
      # @param k [Integer] Number of neighbors to return
      # @return [Array<NearestNeighbor>] Nearest neighbors sorted by similarity
      def nearest_neighbors(word, k: 10)
        embedding = embedding_for(word)
        return [] unless embedding

        # Calculate similarity with all words in vocabulary
        neighbors = vocabulary.map do |vocab_word|
          next if vocab_word == word

          vocab_embedding = embedding_for(vocab_word)
          next unless vocab_embedding

          sim = embedding.similarity(vocab_embedding)
          NearestNeighbor.new(
            word: vocab_word,
            similarity: sim,
            distance: embedding.distance(vocab_embedding),
            embedding: vocab_embedding
          )
        end.compact

        # Sort by similarity (descending) and take top k
        neighbors.sort.reverse.first(k)
      end

      # Find k nearest neighbors for an embedding vector.
      #
      # @param embedding [WordEmbedding] The query embedding
      # @param k [Integer] Number of neighbors to return
      # @return [Array<NearestNeighbor>] Nearest neighbors sorted by similarity
      def nearest_neighbors_for_embedding(embedding, k: 10)
        return [] unless embedding

        # Calculate similarity with all words in vocabulary
        neighbors = vocabulary.map do |vocab_word|
          vocab_embedding = embedding_for(vocab_word)
          next unless vocab_embedding

          sim = embedding.similarity(vocab_embedding)
          NearestNeighbor.new(
            word: vocab_word,
            similarity: sim,
            distance: embedding.distance(vocab_embedding),
            embedding: vocab_embedding
          )
        end.compact

        # Sort by similarity (descending) and take top k
        neighbors.sort.reverse.first(k)
      end

      # Get model metadata.
      #
      # @return [Hash] Model metadata
      def metadata
        {
          language_code: @language_code,
          dimension: @dimension,
          vocabulary_size: @vocabulary_size,
          model_type: self.class.name
        }
      end

      # Get the vocabulary (all words in the model).
      #
      # @return [Array<String>] Vocabulary words
      # @abstract Subclass must implement
      def vocabulary
        raise NotImplementedError, "#{self.class} must implement #vocabulary"
      end

      # Check if model is loaded.
      #
      # @return [Boolean] True if model is loaded and ready
      def loaded?
        @vocabulary_size&.positive? || vocabulary&.any?
      end

      # Get model statistics.
      #
      # @return [Hash] Statistics about the model
      def statistics
        {
          language: @language_code,
          dimension: @dimension,
          vocabulary_size: @vocabulary_size,
          loaded: loaded?
        }
      end

      # String representation.
      #
      # @return [String] Human-readable representation
      def to_s
        "#{self.class.name}(language: #{@language_code}, dim: #{@dimension}, vocab: #{@vocabulary_size})"
      end
      alias_method :inspect, :to_s
    end
  end
end
