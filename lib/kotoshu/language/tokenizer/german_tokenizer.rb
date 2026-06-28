# frozen_string_literal: true

module Kotoshu
  module Language
    module Tokenizer
      # Tokenizer for German text.
      #
      # Ported from LanguageTool's GermanWordTokenizer.
      #
      # Handles:
      # - Underscore as word character (not a separator)
      # - Single low quote (‚) as word character (not a separator)
      # - Umlauts (ä, ö, ü, ß)
      #
      # The LanguageTool implementation adds two characters to the word characters:
      # underscore (_) and single low quote (‚ - U+201A).
      class GermanTokenizer < Base
        # German-specific word separators (exclude underscore and single low quote)
        WORD_SEPARATORS = /[\s"()\[\]{}<>,.;:!?\\\/|`~@#$%^&*+\-·]/

        def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          # Split on word boundaries
          raw_tokens = text.split(WORD_SEPARATORS)

          # Filter and normalize
          raw_tokens
            .map { |token| normalize(token) }
            .reject { |token| skip_token?(token) }
        end

        protected

        def word_separators
          WORD_SEPARATORS
        end
      end
    end
  end
end
