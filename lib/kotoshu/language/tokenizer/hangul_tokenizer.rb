# frozen_string_literal: true

module Kotoshu
  module Language
    module Tokenizer
      # Tokenizer for Korean (plan 108).
      #
      # Korean text is space-delimited: an eojeol is a run of Hangul
      # characters between spaces or punctuation, and every character
      # inside the run belongs to the word — precomposed syllables
      # (U+AC00-D7A3) as typed, plus any bare jamo (combining jamo
      # U+1100-11FF, compatibility jamo U+3130-318F) that escaped IME
      # composition and attaches to the preceding block. The staged ko
      # dictionary stores words jamo-decomposed behind an ICONV table,
      # so both surface forms must stay word characters for the
      # spell-check extraction (plan 91) to hand the engine whole
      # eojeol.
      #
      # Word segmentation (morpheme splitting inside an eojeol) is out
      # of scope — like the pre-plan-108 basic tier, checking is
      # eojeol-granular, matching how the staged dictionary is keyed.
      class HangulTokenizer < Base
        # Precomposed syllables plus the two jamo blocks (regex source
        # text, like CyrillicTokenizer's word_chars).
        HANGUL_WORD_CHARS = "\\uAC00-\\uD7A3\\u1100-\\u11FF\\u3130-\\u318F"

        # One eojeol (a run of word characters).
        WORD_RUN = /[#{HANGUL_WORD_CHARS}]+/

        # One word character.
        WORD_CHAR = /[#{HANGUL_WORD_CHARS}]/

        # Tokenize text into eojeol.
        #
        # @param text [String] Text to tokenize
        # @return [Array<String>] Array of eojeol tokens
        def tokenize(text)
          return [] if text.nil? || text.empty?

          text.scan(WORD_RUN).reject { |token| skip_token?(token) }
        end

        # Get word boundary regex.
        #
        # @return [Regexp] Word boundary regex
        def word_boundary_regex
          WORD_CHAR
        end

        # Spell-check word characters (plan 91): the Hangul set —
        # syllable blocks and jamo, no apostrophe (Korean has no
        # in-word apostrophe) and no digits.
        #
        # @return [Regexp] Regex matching a single word character
        def spellcheck_word_regex
          WORD_CHAR
        end

        protected

        # Get word characters.
        #
        # @return [String] Character class source
        def word_chars
          HANGUL_WORD_CHARS
        end
      end
    end
  end
end
