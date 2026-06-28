# frozen_string_literal: true

# SimilarityEngine - Compute similarity between embedding vectors
#
# Provides various similarity/distance metrics with optimizations like
# norm caching and pre-normalized vector support.
#
# @example Basic usage
#   engine = Kotoshu::Embeddings::SimilarityEngine.new
#   engine.cosine([1.0, 0.0], [1.0, 0.0])  # => 1.0
#
# @example Pre-normalized vectors (faster)
#   engine = Kotoshu::Embeddings::SimilarityEngine.new(pre_normalize: true)
#   engine.pre_normalize([1.0, 0.0])  # => [1.0, 0.0]
#
module Kotoshu
  module Embeddings
    class SimilarityEngine
      include SimilarityEngineProtocol

      # Default embedding dimension for norm cache initialization
      DEFAULT_CACHE_SIZE = 10_000

      # @return [Boolean] Whether vectors are pre-normalized
      attr_reader :pre_normalize

      # @return [Integer] Number of cache hits
      attr_reader :cache_hits

      # @return [Integer] Number of cache misses
      attr_reader :cache_misses

      # Create a new similarity engine
      #
      # @param pre_normalize [Boolean] Whether to pre-normalize vectors
      # @param cache_norms [Boolean] Whether to cache vector norms
      #
      def initialize(pre_normalize: false, cache_norms: true)
        @pre_normalize = pre_normalize
        @cache_norms = cache_norms
        @norm_cache = cache_norms ? {} : nil
        @cache_hits = 0
        @cache_misses = 0
      end

      # Compute cosine similarity between two vectors
      #
      # Cosine similarity = dot(v1, v2) / (||v1|| * ||v2||)
      # Range: -1.0 (opposite) to 1.0 (identical)
      #
      # @param vec1 [Array<Float>] First vector
      # @param vec2 [Array<Float>] Second vector
      # @return [Float] Cosine similarity, or 0.0 if either vector is nil/empty
      #
      def cosine(vec1, vec2)
        return 0.0 if vec1.nil? || vec2.nil? || vec1.empty? || vec2.empty?

        norm1 = get_norm(vec1)
        norm2 = get_norm(vec2)

        return 0.0 if norm1.zero? || norm2.zero?

        dot = dot_product(vec1, vec2)
        dot / (norm1 * norm2)
      end

      # Compute dot product between two vectors
      #
      # @param vec1 [Array<Float>] First vector
      # @param vec2 [Array<Float>] Second vector
      # @return [Float] Dot product
      #
      def dot_product(vec1, vec2)
        return 0.0 if vec1.nil? || vec2.nil? || vec1.empty? || vec2.empty?

        vec1.zip(vec2).sum { |a, b| a * b }
      end

      # Compute Euclidean distance between two vectors
      #
      # @param vec1 [Array<Float>] First vector
      # @param vec2 [Array<Float>] Second vector
      # @return [Float] Euclidean distance
      #
      def euclidean(vec1, vec2)
        return 0.0 if vec1.nil? || vec2.nil? || vec1.empty? || vec2.empty?
        return 0.0 if vec1.equal?(vec2)

        sum = 0.0
        vec1.zip(vec2) do |a, b|
          diff = a - b
          sum += diff * diff
        end
        Math.sqrt(sum)
      end

      # Compute Manhattan (L1) distance between two vectors
      #
      # @param vec1 [Array<Float>] First vector
      # @param vec2 [Array<Float>] Second vector
      # @return [Float] Manhattan distance
      #
      def manhattan(vec1, vec2)
        return 0.0 if vec1.nil? || vec2.nil? || vec1.empty? || vec2.empty?

        vec1.zip(vec2).sum { |a, b| (a - b).abs }
      end

      # Pre-normalize a vector to unit length
      #
      # @param vec [Array<Float>] Vector to normalize
      # @return [Array<Float>] Normalized vector
      #
      def pre_normalize(vec)
        return vec.dup if vec.nil? || vec.empty?

        norm = get_norm(vec)
        return vec.dup if norm.zero?

        vec.map { |x| x / norm }
      end

      # Normalize and compute similarity in one pass
      #
      # For pre-normalized vectors, this is just dot product (much faster).
      #
      # @param vec1 [Array<Float>] First vector
      # @param vec2 [Array<Float>] Second vector
      # @return [Float] Cosine similarity
      #
      def normalize_and_compute(vec1, vec2)
        return 0.0 if vec1.nil? || vec2.nil? || vec1.empty? || vec2.empty?

        if @pre_normalize
          # For normalized vectors, cosine similarity = dot product
          dot_product(vec1, vec2)
        else
          cosine(vec1, vec2)
        end
      end

      # Check if vectors are normalized (unit length)
      #
      # @param vec [Array<Float>] Vector to check
      # @return [Boolean] True if vector is normalized
      #
      def is_normalized?(vec)
        return true if vec.nil? || vec.empty?

        norm = get_norm(vec)
        (norm - 1.0).abs < Float::EPSILON * 10
      end

      # Check if normalization is required for accurate similarity
      #
      # @return [Boolean] True if normalization should be applied
      #
      def normalization_required?
        !@pre_normalize
      end

      # Clear the norm cache
      #
      # @return [self]
      #
      def clear_cache
        @norm_cache&.clear
        @cache_hits = 0
        @cache_misses = 0
        self
      end

      # Get cache statistics
      #
      # @return [Hash] Cache statistics
      #
      def cache_stats
        total = @cache_hits + @cache_misses
        {
          hits: @cache_hits,
          misses: @cache_misses,
          hit_rate: total.zero? ? 0.0 : @cache_hits.to_f / total,
          cache_size: @norm_cache&.size || 0
        }
      end

      # Compute similarity for a batch of vector pairs
      #
      # More efficient than calling cosine() repeatedly.
      #
      # @param pairs [Array<Array<Array<Float>>>] Array of [vec1, vec2] pairs
      # @return [Array<Float>] Array of similarities
      #
      def cosine_batch(pairs)
        pairs.map { |v1, v2| cosine(v1, v2) }
      end

      # Compute all pairwise similarities for a set of vectors
      #
      # @param vectors [Array<Array<Float>>>] Array of vectors
      # @return [Array<Array<Float>>] Similarity matrix
      #
      def compute_all_pairs(vectors)
        n = vectors.length
        matrix = Array.new(n) { Array.new(n, 0.0) }

        (0...n).each do |i|
          matrix[i][i] = 1.0
          ((i + 1)...n).each do |j|
            sim = cosine(vectors[i], vectors[j])
            matrix[i][j] = sim
            matrix[j][i] = sim
          end
        end

        matrix
      end

      private

      # Get norm with caching
      #
      # @param vec [Array<Float>] Vector
      # @return [Float] Vector norm (magnitude)
      #
      def get_norm(vec)
        return 0.0 if vec.nil? || vec.empty?

        if @norm_cache && @norm_cache.key?(vec.object_id)
          @cache_hits += 1
          return @norm_cache[vec.object_id]
        end

        @cache_misses += 1 if @norm_cache

        norm = Math.sqrt(vec.sum { |x| x * x })

        if @norm_cache
          # Avoid memory leaks by limiting cache size
          if @norm_cache.size >= 100_000
            @norm_cache.shift
          end
          @norm_cache[vec.object_id] = norm
        end

        norm
      end
    end
  end
end
