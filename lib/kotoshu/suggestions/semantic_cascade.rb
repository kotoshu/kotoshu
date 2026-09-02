# frozen_string_literal: true

module Kotoshu
  module Suggestions
    # Confidence cascade for the semantic rerank (TODO.impl/70).
    #
    # Formalizes the hybrid dictionary-first architecture: the
    # expensive, ONNX-backed semantic rerank only runs when the
    # traditional composite strategies are not already confident
    # about the word (dictionary verdict first, neural rerank only
    # for uncertain candidates).
    #
    # @example From the process configuration
    #   cascade = SemanticCascade.from_configuration(Kotoshu.configuration)
    #   cascade.skip?(suggestion_set.suggestions)  # => true / false
    #
    # @example With an explicit threshold
    #   SemanticCascade.new(threshold: 0.9)
    class SemanticCascade
      # Sentinel threshold meaning "always rerank" (the default).
      # NOT a plain >= comparison: composite confidence legitimately
      # reaches exactly 1.0 (distance-0 matches, the default
      # confidence of a fresh Suggestion), so `>= 1.0` would change
      # the default behavior — threshold 1.0 must mean never-skip.
      ALWAYS_RERANK = 1.0

      # @return [Float] The configured skip threshold
      attr_reader :threshold

      # Create a cascade decision object.
      #
      # @param threshold [Float, nil] Skip threshold in [0.0, 1.0];
      #   nil falls back to the always-rerank default
      def initialize(threshold: ALWAYS_RERANK)
        @threshold = threshold.nil? ? ALWAYS_RERANK : threshold.to_f
      end

      # Build from a Configuration, so the SCHEMA default and the
      # KOTOSHU_SEMANTIC_CASCADE_THRESHOLD ENV var apply automatically.
      #
      # @param configuration [Configuration] The configuration to read
      # @return [SemanticCascade]
      def self.from_configuration(configuration)
        new(threshold: configuration.semantic_cascade_threshold)
      end

      # Whether the cascade can ever skip. Only a threshold strictly
      # below 1.0 arms it; 0.0 means never rerank.
      #
      # @return [Boolean]
      def armed?
        threshold < ALWAYS_RERANK
      end

      # Whether the semantic rerank should be skipped for this pool of
      # traditional candidates. Skips only when the pool already has a
      # top candidate at or above the threshold; an empty pool never
      # skips (the dictionary path found nothing — the rerank may
      # still help).
      #
      # @param suggestions [Array<Suggestion>] Sorted traditional candidates
      # @return [Boolean]
      def skip?(suggestions)
        return false unless armed?

        top = suggestions.first
        return false unless top

        top.confidence >= threshold
      end
    end
  end
end
