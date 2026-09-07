# frozen_string_literal: true

module Kotoshu
  module Language
    module Tokenizer
      # Tokenizer for Devanagari-script languages (plan 108: ne).
      #
      # A Devanagari word is a run of block characters in which the
      # combining marks stay attached to their base: inherent-vowel
      # killers and matras (U+093E-094C), the virama (U+094D) that
      # forms conjunct consonants, anusvara/visarga/candrabindu and
      # the vowel signs — all share the Devanagari script property, so
      # one script run IS one grapheme-cluster sequence and the
      # plan-91 per-character regex machinery keeps each cluster
      # intact (क + ि renders as कि and extracts as one token).
      # ZWJ/ZWNJ (U+200C/U+200D) join the word set because conjunct
      # spellings insert them mid-word; the danda marks (U+0964-0965)
      # are sentence punctuation and the Devanagari digits
      # (U+0966-096F) are digits, so both stay separators — plan 91
      # keeps digits out of words in every script.
      class DevanagariTokenizer < Base
        # Devanagari block minus danda/digits/abbreviation sign, plus
        # ZWJ/ZWNJ (regex source text, like CyrillicTokenizer's
        # word_chars).
        DEVANAGARI_WORD_CHARS = "\\u0900-\\u0963\\u0971-\\u097F\\u200C\\u200D"

        # One word (a run of word characters).
        WORD_RUN = /[#{DEVANAGARI_WORD_CHARS}]+/

        # One word character.
        WORD_CHAR = /[#{DEVANAGARI_WORD_CHARS}]/

        # Tokenize text into words.
        #
        # @param text [String] Text to tokenize
        # @return [Array<String>] Array of tokens
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

        # Spell-check word characters (plan 91): the Devanagari set —
        # base consonants with their matras and virama conjuncts, no
        # digits and no Latin.
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
          DEVANAGARI_WORD_CHARS
        end
      end
    end
  end
end
