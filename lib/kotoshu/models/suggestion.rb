# frozen_string_literal: true

module Kotoshu
  module Models
    # Value object for correction suggestions.
    #
    # Represents a suggested correction for a detected error,
    # with confidence score and metadata.
    #
    # @example Creating a suggestion
    #   suggestion = Suggestion.new("dessert", confidence: 0.92, source: :semantic)
    #   suggestion.to_s  # => "dessert [92%]"
    class Suggestion
      attr_reader :word, :confidence, :source, :metadata

      # Create a new suggestion.
      #
      # @param word [String] The suggested word
      # @param confidence [Float] Confidence score (0.0 to 1.0)
      # @param source [Symbol, nil] Source of the suggestion (e.g., :semantic, :edit_distance)
      # @param metadata [Hash] Additional metadata (optional)
      # @option metadata [WordEmbedding, nil] :embedding The word embedding
      # @option metadata [Float] :edit_distance Edit distance score
      # @option metadata [Float] :frequency_bonus Frequency score bonus
      # @option metadata [String] :explanation Explanation for the suggestion
      def initialize(word, confidence:, source: nil, metadata: {})
        raise ArgumentError, "Confidence must be 0-1" unless confidence.between?(0.0, 1.0)

        @word = word
        @confidence = confidence
        @source = source || :unknown
        @metadata = metadata.freeze
        freeze
      end

      # Comparison for sorting (higher confidence = better).
      #
      # @param other [Suggestion] Another suggestion
      # @return [Integer] Comparison result (-1, 0, 1)
      def <=>(other)
        return 0 unless other.is_a?(Suggestion)

        # Higher confidence = better rank (sort descending)
        other.confidence <=> @confidence
      end

      # Check if this equals another suggestion.
      #
      # @param other [Object] Another object
      # @return [Boolean] True if words match
      def ==(other)
        return false unless other.is_a?(Suggestion)

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
        if @source && @source != :unknown
          "#{@word} [#{(@confidence * 100).to_i}%] (#{@source})"
        else
          "#{@word} [#{(@confidence * 100).to_i}%]"
        end
      end
      alias_method :inspect, :to_s

      # Get the embedding if available.
      #
      # @return [WordEmbedding, nil] The embedding or nil
      def embedding
        @metadata[:embedding]
      end

      # Get the edit distance if available.
      #
      # @return [Float, nil] Edit distance or nil
      def edit_distance
        @metadata[:edit_distance]
      end

      # Check if this is a high-confidence suggestion.
      #
      # @return [Boolean] True if confidence > 0.8
      def high_confidence?
        @confidence > 0.8
      end

      # Get explanation text if available.
      #
      # @return [String, nil] Explanation or nil
      def explanation
        @metadata[:explanation]
      end
    end
  end
end
