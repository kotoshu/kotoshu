# frozen_string_literal: true

module Kotoshu
  module Language
    module Normalizer
      # Greek-aware normalizer.
      #
      # Two Greek-specific behaviors over the base normalizer:
      #
      # 1. Final sigma: uppercase words ending in Σ downcase to σ, but
      #    dictionary forms end in ς. ΕΛΛΑΣ must look up as ελλας, not
      #    ελλασ. Applied at word level (normalize_word), where the
      #    word boundary is known.
      # 2. Optional accent stripping (tonos and dialytika) for
      #    accent-insensitive comparison: πάτησις -> πατησις. Greek
      #    Hunspell dictionaries carry accents, so this is opt-in via
      #    the :strip_accents option (default false).
      class Greek < Base
        # Combining marks removed by accent stripping: Greek tonos,
        # dialytika and the polytonic accent/breath marks
        # (U+0300 through U+0345).
        COMBINING_MARKS = /[\u0300-\u0345]/

        private_constant :COMBINING_MARKS

        # Normalize text.
        #
        # @param text [String] Text to normalize
        # @param options [Hash] Normalization options
        # @option options [Boolean] :strip_accents (false) Remove
        #   Greek accents after downcasing
        # @return [String] Normalized text
        def normalize(text, options = {})
          result = super
          result = strip_accents(result) if options.fetch(:strip_accents, false)
          result
        end

        # Normalize a word for dictionary lookup.
        #
        # Downcase plus the final-sigma correction: a word ending in σ
        # folds to ς to match dictionary forms.
        #
        # @param word [String] Word to normalize
        # @return [String] Normalized word
        def normalize_word(word)
          normalized = super
          normalized.gsub(/σ\z/, "ς")
        end

        private

        # Strip Greek accents via NFD decomposition.
        #
        # @param text [String] Text to deaccent
        # @return [String] Text without Greek combining marks
        def strip_accents(text)
          text.unicode_normalize(:nfd).gsub(COMBINING_MARKS, "").unicode_normalize(:nfc)
        end
      end
    end
  end
end
