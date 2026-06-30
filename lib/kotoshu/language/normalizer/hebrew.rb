# frozen_string_literal: true

module Kotoshu
  module Language
    module Normalizer
      # Normalizer for Hebrew script.
      #
      # Modern Hebrew is typically written without niqqud (vowel
      # points); spell-checking dictionaries store the bare
      # consonant form. This normalizer:
      #
      # - Applies NFC composition.
      # - Strips niqqud (U+05B0..U+05BC range, plus geresh/gershayim
      #   when used as vowel marks — keeps them when used as
      #   punctuation).
      # - Optionally strips dagesh (U+05BC) — a dot inside a letter
      #   that affects pronunciation but is not represented in bare
      #   dictionary entries.
      # - Normalizes the maqaf (U+05BE, Hebrew hyphen) to ASCII hyphen
      #   for consistent tokenization.
      #
      # @example Default (strip niqqud)
      #   norm = Hebrew.new
      #   norm.normalize_word("שָׁלוֹם")  # => "שלום"
      class Hebrew < Base
        # Niqqud + cantillation marks. Hebrew points range U+0591
        # (etnahta) through U+05BD (meteg). Plus geresh (U+05F3),
        # gershayim (U+05F4) when used as accents. Plus paseq (U+05C0),
        # sof-pasuq (U+05C3), upper dot (U+05C4), lower dot (U+05C5),
        # qamats qatan (U+05C7), and raph (U+05BF).
        # Shin dot (U+05C1) and sin dot (U+05C2) are included so
        # שׁ and שׂ both normalize to ש.
        # Dagesh (U+05BC) is handled separately so callers can keep it.
        NIKKUD_AND_CANTILLATION = /[֑-ֻֽֿ׀-ׇׂׅׄ]/

        DAGESH = "ּ"
        MAQAF = "־"

        # @param strip_dagesh [Boolean] default true. When true,
        #   removes the dagesh dot from letters.
        # @param normalize_maqaf [Boolean] default true. When true,
        #   replaces the Hebrew hyphen (maqaf) with an ASCII hyphen
        #   for consistent tokenization.
        def initialize(strip_dagesh: true, normalize_maqaf: true)
          @strip_dagesh = strip_dagesh
          @normalize_maqaf = normalize_maqaf
        end

        # Normalize text: NFC + niqqud stripping + optional dagesh
        # stripping + maqaf normalization. Skips Base's downcase
        # step because Hebrew has no case.
        #
        # @param text [String]
        # @param _options [Hash] ignored
        # @return [String]
        def normalize(text, _options = {})
          return "" if text.nil? || text.empty?

          result = text.unicode_normalize(:nfc)
          result = result.gsub(NIKKUD_AND_CANTILLATION, "")
          result = result.delete(DAGESH) if @strip_dagesh
          result = result.tr(MAQAF, "-") if @normalize_maqaf
          result.strip
        end

        def normalize_word(word)
          normalize(word)
        end
      end
    end
  end
end
