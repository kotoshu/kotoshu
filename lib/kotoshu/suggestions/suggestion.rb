# frozen_string_literal: true

module Kotoshu
  module Suggestions
    # A single suggestion with associated metadata and behavior.
    # This is MORE model-driven than Spylls which returns plain strings.
    class Suggestion
      attr_reader :word, :distance, :confidence, :source, :metadata

      # @param word [String] The suggested word
      # @param distance [Integer] Edit distance from original (lower is better)
      # @param confidence [Float] Confidence score (0.0 to 1.0, higher is better)
      # @param source [String, Symbol] The strategy that produced this suggestion
      # @param metadata [Hash] Additional metadata about the suggestion
      def initialize(word:, distance: 0, confidence: 1.0, source: :unknown, **metadata)
        @word = word
        @distance = distance
        @confidence = confidence
        @source = source
        @metadata = metadata
        freeze
      end

      # Check if this is a high-confidence suggestion.
      #
      # @return [Boolean] True if confidence >= 0.8
      def high_confidence?
        @confidence >= 0.8
      end

      # Check if this is a low-confidence suggestion.
      #
      # @return [Boolean] True if confidence < 0.5
      def low_confidence?
        @confidence < 0.5
      end

      # Calculate combined score considering distance and confidence.
      #
      # @param distance_weight [Float] Weight for distance (default: 0.3)
      # @param confidence_weight [Float] Weight for confidence (default: 0.7)
      # @return [Float] Combined score (0.0 to 1.0, higher is better)
      def combined_score(distance_weight: 0.3, confidence_weight: 0.7)
        # Normalize distance (assume max meaningful distance is 5)
        normalized_distance = [@distance, 5].min / 5.0
        distance_score = 1.0 - normalized_distance

        (distance_score * distance_weight) + (@confidence * confidence_weight)
      end

      # Check if this suggestion is the same word as another.
      #
      # @param other [Suggestion, String] The other suggestion or word string
      # @return [Boolean] True if words match (case-insensitive)
      def same_word?(other)
        other_word = other.is_a?(Suggestion) ? other.word : other.to_s
        @word.downcase == other_word.downcase
      end

      # Check if this suggestion comes from a specific source.
      #
      # @param source [String, Symbol] The source to check
      # @return [Boolean] True if this suggestion came from the source
      def from_source?(source)
        @source == source
      end

      # Compare suggestions for sorting (higher combined score first).
      #
      # @param other [Suggestion] The other suggestion
      # @return [Integer] -1, 0, or 1
      def <=>(other)
        # First by combined score (descending)
        score_cmp = other.combined_score <=> combined_score
        return score_cmp unless score_cmp.zero?

        # Then by distance (ascending)
        distance_cmp = @distance <=> other.distance
        return distance_cmp unless distance_cmp.zero?

        # Finally by word alphabetically (ascending)
        @word.downcase <=> other.word.downcase
      end

      # Check equality with another suggestion.
      #
      # @param other [Object] The other object
      # @return [Boolean] True if equal
      def ==(other)
        return false unless other.is_a?(Suggestion)
        @word.downcase == other.word.downcase
      end
      alias eql? ==

      # Hash value for use in Hash keys.
      #
      # @return [Integer] Hash code
      def hash
        @word.downcase.hash
      end

      # Convert suggestion to hash.
      #
      # @return [Hash] Suggestion as hash
      def to_h
        {
          word: @word,
          distance: @distance,
          confidence: @confidence,
          source: @source,
          combined_score: combined_score
        }.merge(@metadata)
      end

      # Convert suggestion to JSON-compatible hash.
      #
      # @return [Hash] JSON-compatible hash
      def as_json(*)
        to_h
      end

      # String representation.
      #
      # @return [String] String representation
      def to_s
        "Suggestion(word: '#{@word}', distance: #{@distance}, confidence: #{'%.2f' % @confidence}, source: #{@source})"
      end

      # Inspect the suggestion.
      #
      # @return [String] Inspection string
      def inspect
        to_s
      end

      # Create a suggestion from a simple word (convenience method).
      #
      # @param word [String] The word
      # @param source [String, Symbol] The source
      # @return [Suggestion] New suggestion
      def self.from_word(word, source: :unknown)
        new(word: word, distance: 0, confidence: 1.0, source: source)
      end
    end
  end
end
