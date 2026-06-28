# frozen_string_literal: true

module Kotoshu
  module Embeddings
    # Similarity search for embedding-based nearest neighbor lookup.
    #
    # Efficiently finds semantically similar words using cosine similarity.
    # Supports both on-the-fly computation and pre-computed embedding matrices.
    #
    # @example Basic usage
    #   search = SimilaritySearch.new(
    #     vocabulary: vocab,
    #     model: model
    #   )
    #   neighbors = search.find_nearest('hello', k: 10)
    #
    # @example With pre-loaded embedding matrix (faster)
    #   search = SimilaritySearch.new(
    #     vocabulary: vocab,
    #     model: model,
    #     preload_embeddings: true
    #   )
    #   neighbors = search.find_nearest('hello', k: 10)
    class SimilaritySearch
      # @return [Vocabulary] The vocabulary
      attr_reader :vocabulary

      # @return [OnnxRuntimeModel] The ONNX model
      attr_reader :model

      # @return [Boolean] Whether embeddings are pre-loaded
      attr_reader :embeddings_loaded

      # Create a new similarity search instance.
      #
      # @param vocabulary [Vocabulary] Word vocabulary
      # @param model [OnnxRuntimeModel] ONNX model for embeddings
      # @param preload_embeddings [Boolean] Whether to preload all embeddings
      # @param max_cache_size [Integer] Maximum embeddings to cache (if not preloading)
      def initialize(vocabulary:, model:, preload_embeddings: false, max_cache_size: 1000)
        @vocabulary = vocabulary
        @model = model
        @preload_embeddings = preload_embeddings
        @max_cache_size = max_cache_size

        # Embedding cache (word -> vector)
        @embedding_cache = {}

        # Pre-loaded embedding matrix (for faster search)
        @embedding_matrix = nil

        # Track whether embeddings are preloaded
        @embeddings_loaded = false

        # Load embeddings if requested
        preload_embeddings! if preload_embeddings
      end

      # Find k nearest neighbors for a word.
      #
      # @param query_word [String] The query word
      # @param k [Integer] Number of neighbors to return
      # @param exclude_self [Boolean] Whether to exclude the query word itself
      # @param min_similarity [Float] Minimum similarity threshold (0.0 to 1.0)
      # @return [Array<Hash>] Array of {word, similarity} hashes
      def find_nearest(query_word, k: 10, exclude_self: true, min_similarity: 0.0)
        # Get query embedding
        query_vec = get_embedding(query_word)
        return [] unless query_vec

        # Find neighbors
        if @embedding_matrix
          nearest_from_matrix(query_vec, k, exclude_self, min_similarity)
        else
          nearest_from_cache(query_vec, k, exclude_self, min_similarity)
        end
      end

      # Find k nearest neighbors for multiple words.
      #
      # @param query_words [Array<String>] Query words
      # @param k [Integer] Number of neighbors per word
      # @return [Hash<String, Array<Hash>>] Word to neighbors mapping
      def find_nearest_batch(query_words, k: 10)
        query_words.each_with_object({}) do |word, result|
          result[word] = find_nearest(word, k: k)
        end
      end

      # Compute similarity between two words.
      #
      # @param word1 [String] First word
      # @param word2 [String] Second word
      # @return [Float] Cosine similarity (-1.0 to 1.0, or nil if either word not found)
      def similarity(word1, word2)
        vec1 = get_embedding(word1)
        vec2 = get_embedding(word2)

        return nil unless vec1 && vec2

        cosine_similarity(vec1, vec2)
      end

      # Compute similarity between two embedding vectors.
      #
      # @param vec1 [Array<Float>] First vector
      # @param vec2 [Array<Float>] Second vector
      # @return [Float] Cosine similarity (-1.0 to 1.0)
      def cosine_similarity(vec1, vec2)
        return 0.0 if vec1.nil? || vec2.nil?

        # Compute dot product
        dot = vec1.zip(vec2).sum { |a, b| a * b }

        # Compute magnitudes
        norm1 = Math.sqrt(vec1.sum { |x| x * x })
        norm2 = Math.sqrt(vec2.sum { |x| x * x })

        return 0.0 if norm1.zero? || norm2.zero?

        dot / (norm1 * norm2)
      end

      # Preload all embeddings into memory for faster search.
      #
      # @return [Boolean] True if loaded successfully
      def preload_embeddings!
        return false if @embedding_matrix

        # Get all indices
        all_indices = (0...@vocabulary.size).to_a

        # Batch load embeddings
        vectors = @model.get_embeddings(all_indices)
        return false if vectors.nil? || vectors.empty?

        # Store as hash for now (could use Numo::SFloat for efficiency)
        @embedding_matrix = {}
        all_indices.zip(vectors).each do |idx, vec|
          @embedding_matrix[idx] = vec
        end

        @embeddings_loaded = true
        true
      rescue StandardError => e
        warn "Failed to preload embeddings: #{e.message}"
        false
      end

      # Clear the embedding cache.
      #
      # @return [self] Self for chaining
      def clear_cache
        @embedding_cache.clear
        @embedding_matrix = nil
        @embeddings_loaded = false
        self
      end

      # Get cache statistics.
      #
      # @return [Hash] Cache statistics
      def cache_stats
        stats = {
          size: @embedding_cache.size,
          max_size: @max_cache_size
        }
        stats[:hit_rate] = @cache_hits.to_f / (@cache_hits + @cache_misses) if defined?(@cache_hits)
        stats
      end

      # String representation.
      #
      # @return [String] String representation
      def to_s
        "SimilaritySearch(vocab_size: #{@vocabulary.size}, loaded: #{@embeddings_loaded})"
      end
      alias inspect to_s

      private

      # Get embedding for a word (with caching).
      #
      # @param word [String] The word
      # @return [Array<Float>, nil] Embedding vector or nil if not found
      def get_embedding(word)
        # Check cache first
        if @embedding_cache.key?(word)
          @cache_hits += 1 if defined?(@cache_hits)
          return @embedding_cache[word]
        end

        @cache_misses ||= 0
        @cache_hits ||= 0
        @cache_misses += 1

        # Get from model
        index = @vocabulary.lookup(word)
        return nil unless index

        vec = if @embedding_matrix
                @embedding_matrix[index]
              else
                @model.get_embedding(index)
              end

        return nil unless vec

        # Cache if not preloading (preload has all in memory already)
        unless @preload_embeddings
          # Evict oldest if cache is full
          if @embedding_cache.size >= @max_cache_size
            @embedding_cache.shift
          end
          @embedding_cache[word] = vec
        end

        vec
      end

      # Find nearest neighbors using pre-loaded matrix.
      #
      # @param query_vec [Array<Float>] Query embedding
      # @param k [Integer] Number of neighbors
      # @param exclude_self [Boolean] Whether to exclude exact matches
      # @param min_similarity [Float] Minimum similarity
      # @return [Array<Hash>] Nearest neighbors
      def nearest_from_matrix(query_vec, k, exclude_self, min_similarity)
        similarities = []

        @vocabulary.words.each do |word|
          index = @vocabulary.lookup(word)
          vec = @embedding_matrix[index]

          next unless vec

          sim = cosine_similarity(query_vec, vec)

          # Skip exact match if requested
          next if exclude_self && sim >= 0.9999

          # Skip below threshold
          next if sim < min_similarity

          similarities << { word: word, similarity: sim }
        end

        # Sort by similarity (descending) and take top k
        similarities.sort_by { |s| -s[:similarity] }.first(k)
      end

      # Find nearest neighbors using cache (no pre-loading).
      #
      # @param query_vec [Array<Float>] Query embedding
      # @param k [Integer] Number of neighbors
      # @param exclude_self [Boolean] Whether to exclude exact matches
      # @param min_similarity [Float] Minimum similarity
      # @return [Array<Hash>] Nearest neighbors
      def nearest_from_cache(query_vec, k, exclude_self, min_similarity)
        similarities = []

        # Sample from vocabulary for efficiency (or use common words)
        sample_words = sample_vocabulary(k * 10)

        sample_words.each do |word|
          vec = get_embedding(word)
          next unless vec

          sim = cosine_similarity(query_vec, vec)

          # Skip exact match if requested
          next if exclude_self && sim >= 0.9999

          # Skip below threshold
          next if sim < min_similarity

          similarities << { word: word, similarity: sim }
        end

        # Sort by similarity (descending) and take top k
        similarities.sort_by { |s| -s[:similarity] }.first(k)
      end

      # Sample words from vocabulary for search.
      #
      # Prioritizes common words (first N in vocabulary).
      #
      # @param n [Integer] Number of words to sample
      # @return [Array<String>] Sampled words
      def sample_vocabulary(n)
        # Use first N words (FastText orders by frequency)
        # plus a random sample of the rest
        common_size = [n / 2, 100].min
        random_size = n - common_size

        common = @vocabulary.common_words(n: common_size)

        if @vocabulary.size > common_size
          # Get a random sample from the rest
          rest = @vocabulary.words.drop(common_size)
          random_sample = rest.sample(random_size)
          common + random_sample
        else
          common
        end
      end

      # Create from cache.
      #
      # @param language_code [String] ISO 639-1 language code
      # @param cache [Cache::ModelCache, nil] Optional cache instance
      # @param preload [Boolean] Whether to preload embeddings
      # @return [SimilaritySearch, nil] New search instance or nil if not available
      def self.from_cache(language_code, cache: nil, preload: false)
        vocab = Vocabulary.from_cache(language_code, cache: cache)
        model = OnnxRuntimeModel.from_cache(language_code, cache: cache)

        return nil unless vocab && model

        new(
          vocabulary: vocab,
          model: model,
          preload_embeddings: preload
        )
      end
    end
  end
end
