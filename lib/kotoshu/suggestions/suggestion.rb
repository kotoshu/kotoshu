# frozen_string_literal: true

require "lutaml/model"

module Kotoshu
  module Suggestions
    # A single suggestion with associated metadata and behavior.
    #
    # Serialized via lutaml-model. Use +to_hash+ / +Suggestion.as_json(instance)+ /
    # +Suggestion.from_hash(hash)+ / +Suggestion.from_json(string)+ for the
    # wire forms — no hand-rolled +to_h+ / +as_json+ on the model.
    class Suggestion < Lutaml::Model::Serializable
      attribute :word, :string
      attribute :distance, :integer, default: 0
      attribute :confidence, :float, default: 1.0
      attribute :source, :string, default: "unknown"
      attribute :metadata, :hash, default: {}

      # Support the legacy +**metadata+ kwarg catch-all so existing callers
      # (e.g., +Suggestion.new(word:, distance:, source:, original_length: 5)+)
      # continue to work; extra kwargs land in the +metadata+ attribute.
      # Source is stored as a string for clean serialization; +from_source?+
      # normalizes Symbol/String comparison so callers can pass either.
      #
      # +word+ defaults to nil purely to accommodate lutaml-model's
      # deserialization pathway, which allocates a shell via
      # +new(lutaml_register:)+ before applying attribute values through
      # the deserialize pipeline. Direct callers must still pass +word:+
      # — a Suggestion without a word is degenerate and not user-facing.
      def initialize(word: nil, distance: 0, confidence: 1.0, source: "unknown", **metadata)
        lutaml_register = metadata.delete(:lutaml_register)
        kwargs = {
          word: word,
          distance: distance,
          confidence: confidence,
          source: source.to_s,
          metadata: metadata
        }
        kwargs[:lutaml_register] = lutaml_register if lutaml_register
        super(**kwargs)
      end

      # Check if this is a high-confidence suggestion.
      #
      # @return [Boolean] True if confidence >= 0.8
      def high_confidence?
        confidence >= 0.8
      end

      # Check if this is a low-confidence suggestion.
      #
      # @return [Boolean] True if confidence < 0.5
      def low_confidence?
        confidence < 0.5
      end

      # Calculate combined score considering distance and confidence.
      #
      # @param distance_weight [Float] Weight for distance (default: 0.3)
      # @param confidence_weight [Float] Weight for confidence (default: 0.7)
      # @return [Float] Combined score (0.0 to 1.0, higher is better)
      def combined_score(distance_weight: 0.3, confidence_weight: 0.7)
        normalized_distance = [distance, 5].min / 5.0
        distance_score = 1.0 - normalized_distance

        (distance_score * distance_weight) + (confidence * confidence_weight)
      end

      # Check if this suggestion is the same word as another.
      #
      # @param other [Suggestion, String] The other suggestion or word string
      # @return [Boolean] True if words match (case-insensitive)
      def same_word?(other)
        other_word = other.is_a?(Suggestion) ? other.word : other.to_s
        word.downcase == other_word.downcase
      end

      # Check if this suggestion comes from a specific source.
      #
      # Source is stored as a string; comparison normalizes Symbol/String.
      #
      # @param source [String, Symbol] The source to check
      # @return [Boolean] True if this suggestion came from the source
      def from_source?(source)
        self.source == source.to_s
      end

      # Compare suggestions for sorting (higher combined score first).
      #
      # Ranking priority (following CSpell/Hunspell approach):
      # 1. Combined score (higher is better)
      # 2. Edit distance (lower is better)
      # 3. Length similarity (prefer similar length to original word)
      # 4. N-gram similarity (more shared n-grams is better)
      # 5. Alphabetical (ONLY as final tiebreaker)
      #
      # @param other [Suggestion] The other suggestion
      # @return [Integer, nil] -1, 0, or 1; nil if +other+ is not a Suggestion
      def <=>(other)
        return nil unless other.is_a?(Suggestion)

        score_cmp = other.combined_score <=> combined_score
        return score_cmp unless score_cmp.zero?

        distance_cmp = distance <=> other.distance
        return distance_cmp unless distance_cmp.zero?

        orig_len = metadata[:original_length] || word.length
        other_orig_len = other.metadata[:original_length] || other.word.length

        my_len_diff = (word.length - orig_len).abs
        other_len_diff = (other.word.length - other_orig_len).abs

        len_cmp = my_len_diff <=> other_len_diff
        return len_cmp unless len_cmp.zero?

        my_ngram = metadata[:ngram_score] || 0
        other_ngram = other.metadata[:ngram_score] || 0

        ngram_cmp = other_ngram <=> my_ngram
        return ngram_cmp unless ngram_cmp.zero?

        word.downcase <=> other.word.downcase
      end

      def ==(other)
        return false unless other.is_a?(Suggestion)

        word.downcase == other.word.downcase
      end
      alias eql? ==

      def hash
        word.downcase.hash
      end

      def to_s
        format("Suggestion(word: '%<word>s', distance: %<distance>d, confidence: %<confidence>.2f, source: %<source>s)",
               word: word, distance: distance, confidence: confidence, source: source)
      end

      alias inspect to_s

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
