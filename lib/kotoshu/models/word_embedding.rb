# frozen_string_literal: true

module Kotoshu
  module Models
    # Immutable value object for word embeddings.
    #
    # Represents a word and its vector representation in a semantic space.
    # Used for semantic similarity calculations and nearest neighbor searches.
    #
    # @example Creating an embedding
    #   embedding = WordEmbedding.new("hello", [0.1, -0.2, 0.3], "en")
    #   embedding.similarity(other_embedding)  # => 0.85
    #
    # @see https://fasttext.cc/docs/en/crawl-vectors.html FastText crawl vectors
    class WordEmbedding
      attr_reader :word, :vector, :language_code, :dimension

      # Create a new word embedding.
      #
      # @param word [String] The word
      # @param vector [Array<Float>] The word's vector representation
      # @param language_code [String] ISO 639-1 language code
      # @param dimension [Integer] Vector dimension (default: 300 for FastText)
      # @raise [ArgumentError] if vector doesn't match dimension
      def initialize(word, vector, language_code, dimension: 300)
        raise ArgumentError, "Vector dimension mismatch" unless vector.size == dimension

        @word = word
        @vector = vector.freeze
        @language_code = language_code
        @dimension = dimension

        freeze
      end

      # Calculate cosine similarity with another embedding.
      #
      # Cosine similarity measures the cosine of the angle between two vectors.
      # Returns 1.0 for identical vectors, 0.0 for orthogonal vectors.
      #
      # @param other [WordEmbedding] Another embedding
      # @return [Float] Similarity score (0.0 to 1.0)
      # @raise [TypeError] if other is not a WordEmbedding
      def similarity(other)
        raise TypeError, "Must be WordEmbedding" unless other.is_a?(WordEmbedding)

        return 0.0 if @dimension != other.dimension

        dot_product = @vector.zip(other.vector).map { |a, b| a * b }.sum
        magnitude_a = vector_magnitude
        magnitude_b = other.vector_magnitude

        return 0.0 if magnitude_a.zero? || magnitude_b.zero?

        dot_product / (magnitude_a * magnitude_b)
      end

      # Calculate Euclidean distance from another embedding.
      #
      # @param other [WordEmbedding] Another embedding
      # @return [Float] Euclidean distance
      # @raise [TypeError] if other is not a WordEmbedding
      def distance(other)
        raise TypeError, "Must be WordEmbedding" unless other.is_a?(WordEmbedding)

        return Float::INFINITY if @dimension != other.dimension

        Math.sqrt(@vector.zip(other.vector).map { |a, b| (a - b)**2 }.sum)
      end

      # Check if this embedding is equal to another.
      #
      # @param other [Object] Another object
      # @return [Boolean] True if words and languages match
      def ==(other)
        return false unless other.is_a?(WordEmbedding)

        @word == other.word && @language_code == other.language_code
      end
      alias_method :eql?, :==

      # Hash code for hash table usage.
      #
      # @return [Integer] Hash code
      def hash
        [@word, @language_code].hash
      end

      # String representation.
      #
      # @return [String] Human-readable representation
      def to_s
        "#{self.class.name}[#{@word}, #{@language_code}, #{@dimension}D]"
      end
      alias_method :inspect, :to_s

      private

      # Calculate vector magnitude (Euclidean norm).
      #
      # @return [Float] Magnitude
      def vector_magnitude
        @magnitude ||= Math.sqrt(@vector.map { |x| x * x }.sum)
      end
    end
  end
end
