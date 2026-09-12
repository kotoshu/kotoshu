# frozen_string_literal: true

module Kotoshu
  module Suggestions
    # The typo-retrieval merge (plan 131): the bi-encoder's rescored
    # slate joins AHEAD of the base suggestions — it surfaces
    # corrections a frequency-ranked sweep misses — with duplicates
    # (same word) dropped from the base side and the set capped at the
    # caller's limit. A pure function over real SuggestionSets; the
    # spellchecker calls it only when the opt-in layer is armed.
    module TypoMerge
      # @param base [SuggestionSet] the engine's own suggestions
      # @param typo [SuggestionSet] the typo-retrieval slate
      # @param limit [Integer] final cap
      # @return [SuggestionSet] merged set, order adopted verbatim
      def self.call(base:, typo:, limit:)
        return base if typo.empty?

        typo_words = typo.map(&:word)
        merged = typo.suggestions +
          base.suggestions.reject { |suggestion| typo_words.include?(suggestion.word) }
        SuggestionSet.new(merged.first(limit), max_size: limit, ranked: true)
      end
    end
  end
end
