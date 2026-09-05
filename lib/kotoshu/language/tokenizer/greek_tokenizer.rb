# frozen_string_literal: true

module Kotoshu
  module Language
    module Tokenizer
      # Tokenizer for Greek-script text.
      #
      # Splits on the same punctuation/whitespace separators as the
      # Latin tokenizer, but keeps tokens that contain Greek letters
      # (the Latin tokenizer's letter checks would drop a pure Greek
      # word). Greek punctuation keeps its separators; the Greek
      # question mark is the semicolon character and is treated as
      # punctuation, matching the physical Greek keyboard where it is
      # the shift of the question-mark key.
      class GreekTokenizer < Base
        # Separators between Greek words. Mirrors LatinTokenizer's
        # separator set; Greek text needs no contraction handling.
        WORD_SEPARATORS = /[\s"()\[\]{}<>,.;:!?\\\/|`~@#$%^&*+\-=_]/

        # Tokenize text into Greek words.
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
          /\p{Greek}/
        end

        # Check if token should be skipped.
        #
        # Skips tokens that contain no Greek letters; Base's rules
        # (empty, pure numbers) also apply.
        #
        # @param token [String] Token to check
        # @return [Boolean] True if should skip
        def skip_token?(token)
          return true if super

          !token.match?(/\p{Greek}/)
        end

        protected

        # Get word characters.
        #
        # @return [String] Character class of Greek letters
        def word_chars
          "\\p{Greek}"
        end
      end
    end
  end
end
