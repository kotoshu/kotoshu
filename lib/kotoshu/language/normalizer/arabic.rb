# frozen_string_literal: true

module Kotoshu
  module Language
    module Normalizer
      # Normalizer for Arabic script.
      #
      # Arabic has many presentation forms (the U+FE70..U+FEFF Arabic
      # Presentation Forms-A block plus the FB50..FDFF / FE70..FEFF
      # blocks for Presentation Forms-B) that look the same to a
      # reader but are distinct codepoints. Input text often arrives
      # in any of these forms depending on the source editor — same
      # word can be encoded three different ways and not match a
      # dictionary lookup. This normalizer canonicalizes them all to
      # the base U+0621..U+064A range.
      #
      # Also handles:
      # - NFC composition (combines base + combining marks).
      # - Optional diacritic (tashkeel) stripping for spell checking —
      #   Modern Standard Arabic is typically written without
      #   diacritics; the dictionary stores bare forms.
      # - Tatweel (U+0640) removal — a decorative elongation mark
      #   that creates variants of the same word.
      #
      # @example Default (strip diacritics)
      #   norm = Arabic.new
      #   norm.normalize_word("كِتَابٌ")  # => "كتاب"
      class Arabic < Base
        # Arabic Presentation Forms-A and Forms-B codepoints that
        # have a base-form equivalent in the U+0621..U+064A range.
        # Ruby's String#unicode_normalize(:nfc) handles the
        # composition for most pairs; the legacy Presentation Forms-B
        # range (FE70..FEFF) needs an explicit table because NFC
        # doesn't cover it.
        PRESENTATION_FORM_MAP = {
          "ﺍ" => "ا", "ﺎ" => "ا",
          "ﺏ" => "ب", "ﺑ" => "ب", "ﺒ" => "ب", "ﺓ" => "ة",
          "ﺕ" => "ت", "ﺗ" => "ت", "ﺘ" => "ت", "ﺚ" => "ث",
          "ﺛ" => "ث", "ﺜ" => "ث", "ﺝ" => "ج", "ﺟ" => "ج",
          "ﺠ" => "ج", "ﺡ" => "ح", "ﺣ" => "ح", "ﺤ" => "ح",
          "ﺥ" => "خ", "ﺧ" => "خ", "ﺨ" => "خ", "ﺩ" => "د",
          "ﺪ" => "د", "ﺫ" => "ذ", "ﺬ" => "ذ", "ﺭ" => "ر",
          "ﺮ" => "ر", "ﺯ" => "ز", "ﺰ" => "ز", "ﺱ" => "س",
          "ﺳ" => "س", "ﺴ" => "س", "ﺵ" => "ش", "ﺷ" => "ش",
          "ﺸ" => "ش", "ﺹ" => "ص", "ﺻ" => "ص", "ﺼ" => "ص",
          "ﺽ" => "ض", "ﺿ" => "ض", "ﻀ" => "ض", "ﻁ" => "ط",
          "ﻃ" => "ط", "ﻄ" => "ط", "ﻅ" => "ظ", "ﻇ" => "ظ",
          "ﻈ" => "ظ", "ﻉ" => "ع", "ﻋ" => "ع", "ﻌ" => "ع",
          "ﻍ" => "غ", "ﻏ" => "غ", "ﻐ" => "غ", "ﻑ" => "ف",
          "ﻓ" => "ف", "ﻔ" => "ف", "ﻕ" => "ق", "ﻗ" => "ق",
          "ﻘ" => "ق", "ﻙ" => "ك", "ﻛ" => "ك", "ﻜ" => "ك",
          "ﻝ" => "ل", "ﻟ" => "ل", "ﻠ" => "ل", "ﻡ" => "م",
          "ﻣ" => "م", "ﻤ" => "م", "ﻥ" => "ن", "ﻧ" => "ن",
          "ﻨ" => "ن", "ﻩ" => "ه", "ﻫ" => "ه", "ﻬ" => "ه",
          "ﻭ" => "و", "ﻮ" => "و", "ﻱ" => "ي", "ﻳ" => "ي",
          "ﻴ" => "ي", "ﻵ" => "آ", "ﻶ" => "آ", "ﻷ" => "أ",
          "ﻸ" => "أ", "ﻹ" => "إ", "ﻺ" => "إ", "ﻻ" => "لا",
          "ﻼ" => "لا"
        }.freeze

        # Arabic diacritics (tashkeel) — harakat, tanwin, shaddah,
        # sukun, dagger alef. Stripped for spell-checking since the
        # dictionary stores bare forms.
        DIACRITICS = /[ؐ-ًؚ-ٰٟۖ-ۜ۟-ۤۧ-۪ۨ-ۭ]/

        # Tatweel (kashida) — decorative horizontal elongation.
        TATWEEL = "ـ"

        # @param strip_diacritics [Boolean] default true. When true,
        #   tashkeel (vowel points) are removed before lookup.
        # @param strip_tatweel [Boolean] default true. When true,
        #   tatweel elongation marks are removed.
        def initialize(strip_diacritics: true, strip_tatweel: true)
          @strip_diacritics = strip_diacritics
          @strip_tatweel = strip_tatweel
        end

        # Normalize text: NFC + presentation-form canonicalization +
        # optional diacritic/tatweel stripping. Skips the Base class's
        # downcase step because Arabic has no case.
        #
        # @param text [String]
        # @param _options [Hash] ignored (Arabic has no case to fold)
        # @return [String]
        def normalize(text, _options = {})
          return "" if text.nil? || text.empty?

          result = text.unicode_normalize(:nfc)
          result = canonicalize_presentation_forms(result)
          result = result.gsub(DIACRITICS, "") if @strip_diacritics
          result = result.delete(TATWEEL) if @strip_tatweel
          result.strip
        end

        # Normalize a word: same as +normalize+ but operates on a
        # single token. Arabic words don't need different treatment.
        def normalize_word(word)
          normalize(word)
        end

        private

        # Replace every Presentation Forms-B character with its
        # base-form equivalent. Done character-by-character because
        # the mapping is irregular (one base letter may have up to
        # four positional forms: isolated, initial, medial, final).
        def canonicalize_presentation_forms(text)
          text.chars.map { |c| PRESENTATION_FORM_MAP.fetch(c, c) }.join
        end
      end
    end
  end
end
