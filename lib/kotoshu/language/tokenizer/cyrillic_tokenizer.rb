# frozen_string_literal: true

module Kotoshu
  module Language
    module Tokenizer
      # Tokenizer for Cyrillic-script text without a language-specific
      # subclass (RussianTokenizer carries Russian abbreviation
      # handling; Ukrainian, Belarusian, Bulgarian, Serbian and friends
      # need only the script-aware split).
      #
      # Splits on the same punctuation/whitespace separators as the
      # Latin tokenizer, but keeps tokens that contain Cyrillic
      # letters — the Latin tokenizer's letter checks would drop a
      # pure Cyrillic word. The apostrophe stays a word character so
      # Ukrainian names like Мар'яна tokenize as one word.
      class CyrillicTokenizer < Base
        # Separators between Cyrillic words. The apostrophe is NOT a
        # separator (Ukrainian uses it inside words); the dot is, like
        # in the Latin tokenizer.
        WORD_SEPARATORS = /[\s"()\[\]{}<>,.;:!?\\\/|`~@#$%^&*+\-=_]/

        # Tokenize text into Cyrillic words.
        #
        # @param text [String] Text to tokenize
        # @return [Array<String>] Array of tokens
        def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          text.split(WORD_SEPARATORS)
            .map(&:strip)
            .reject { |token| skip_token?(token) }
        end

        # Get word boundary regex.
        #
        # @return [Regexp] Word boundary regex
        def word_boundary_regex
          /\p{Cyrillic}/
        end

        # Check if token should be skipped.
        #
        # Skips tokens that contain no Cyrillic letters; Base's rules
        # (empty, pure numbers) also apply.
        #
        # @param token [String] Token to check
        # @return [Boolean] True if should skip
        def skip_token?(token)
          return true if super

          !token.match?(/\p{Cyrillic}/)
        end

        protected

        # Get word characters.
        #
        # @return [String] Character class of Cyrillic letters and the
        #   apostrophe
        def word_chars
          "\\p{Cyrillic}'"
        end
      end
    end
  end
end
