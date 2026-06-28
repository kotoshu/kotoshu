# frozen_string_literal: true

module Kotoshu
  module Models
    # Value object for embedding search results (nearest neighbors).
    #
    # Represents a single suggestion from semantic similarity search,
    # with similarity score and optional embedding reference.
    #
    # @example Creating a neighbor
    #   neighbor = NearestNeighbor.new("hello", 0.85, embedding: emb)
    #   neighbor.to_s  # => "hello [85%]"
    class NearestNeighbor
      attr_reader :word, :similarity, :distance, :embedding

      # Create a new nearest neighbor result.
      #
      # @param word [String] The suggested word
      # @param similarity [Float] Cosine similarity (0.0 to 1.0)
      # @param embedding [WordEmbedding, nil] Optional embedding reference
      def initialize(word, similarity, embedding: nil)
        raise ArgumentError, "Similarity must be 0-1" unless similarity.between?(0.0, 1.0)

        @word = word
        @similarity = similarity
        @distance = 1.0 - similarity
        @embedding = embedding
        freeze
      end

      # Comparison for sorting (higher similarity = better).
      #
      # @param other [NearestNeighbor] Another neighbor
      # @return [Integer] Comparison result (-1, 0, 1)
      def <=>(other)
        return 0 unless other.is_a?(NearestNeighbor)

        # Higher similarity = better rank (sort descending)
        other.similarity <=> @similarity
      end

      # Check if this equals another neighbor.
      #
      # @param other [Object] Another object
      # @return [Boolean] True if words match
      def ==(other)
        return false unless other.is_a?(NearestNeighbor)

        @word == other.word
      end
      alias_method :eql?, :==

      # Hash code for hash table usage.
      #
      # @return [Integer] Hash code
      def hash
        @word.hash
      end

      # String representation with percentage.
      #
      # @return [String] Human-readable representation
      def to_s
        "#{@word} [#{(@similarity * 100).to_i}%]"
      end
      alias_method :inspect, :to_s

      # Check if this is a high-confidence suggestion.
      #
      # @return [Boolean] True if similarity > 0.8
      def high_confidence?
        @similarity > 0.8
      end

      # Get confidence level category.
      #
      # @return [Symbol] :high, :medium, or :low
      def confidence_level
        return :high if @similarity > 0.8
        return :medium if @similarity > 0.5

        :low
      end
    end
  end
end
