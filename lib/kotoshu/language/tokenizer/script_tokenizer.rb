# frozen_string_literal: true

module Kotoshu
  module Language
    module Tokenizer
      # Regex-parameterized tokenizer for scripts without a dedicated
      # tokenizer class (plan 107 basic tier).
      #
      # Languages without a gem module still need the plan-91 contract
      # — #spellcheck_word_regex deciding which letters form words —
      # for their script. Latin, Cyrillic and Greek reuse their real
      # tokenizer classes; every other script (Arabic, Hebrew,
      # Armenian, Georgian, Devanagari, Hangul) is served by this
      # generic, word-run tokenizer parameterized with the script's
      # character class. Modules remain the upgrade path: when one
      # lands it brings tokenizer care (contractions, jamo, conjuncts)
      # and this fallback stops being consulted for that language.
      class ScriptTokenizer < Base
        # @param word_regex [Regexp] characters forming a word, as a
        #   single-character regex (the plan-91 set)
        def initialize(word_regex:)
          super()
          @word_regex = word_regex
        end

        # Tokenize text into words by scanning runs of word characters.
        #
        # @param text [String] Text to tokenize
        # @return [Array<String>] Array of tokens
        def tokenize(text)
          return [] if text.nil? || text.empty?

          text.scan(/#{@word_regex}+/).reject { |token| skip_token?(token) }
        end

        # Get word boundary regex.
        #
        # @return [Regexp] Word boundary regex
        def word_boundary_regex
          @word_regex
        end

        # Spell-check word characters (plan 91): the script set this
        # tokenizer was built with.
        #
        # @return [Regexp] Regex matching a single word character
        def spellcheck_word_regex
          @word_regex
        end

        protected

        # Get word characters.
        #
        # @return [String] Character class source
        def word_chars
          @word_regex.source
        end
      end
    end
  end
end
