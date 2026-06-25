# frozen_string_literal: true

module Kotoshu
  module Language
    module Tokenizer
      # Tokenizer for Spanish text.
      #
      # Ported from LanguageTool's SpanishWordTokenizer.
      #
      # Handles:
      # - Decimal point between digits (3.14)
      # - Decimal comma between digits (3,14)
      # - Ordinals (1.º, 2.ª, 1.er, 1.os, 1.as)
      # - Hyphens (with do-not-split list since no tagger)
      # - Soft hyphens
      # - Inverted punctuation (¡, ¿)
      class SpanishTokenizer < Base
        # Spanish word separators - most punctuation and whitespace
        # Note: We need to handle decimals specially, so we protect them first
        WORD_SEPARATORS = /[\s"()\[\]{}<>,.;:!?\\\/|`~@#$%^&*·]/.freeze

        # Decimal point between digits: 3.14
        DECIMAL_POINT = /(\d)\.(\d)/

        # Decimal comma between digits: 3,14
        DECIMAL_COMMA = /(\d),(\d)/

        # Ordinal patterns: 1.º, 2.ª, 1.er, 1.os, 1.as
        ORDINAL = /\b(\d+)\.(º|ª|o|a|er|os|as)\b/

        # Placeholders for special patterns
        DECIMAL_POINT_PLACEHOLDER = "\uE101"
        DECIMAL_COMMA_PLACEHOLDER = "\uE102"
        ORDINAL_PLACEHOLDER = "\uE103"

        # Soft hyphen
        SOFT_HYPHEN = "\u00AD"

        # Do-not-split list (from LanguageTool)
        DO_NOT_SPLIT = %w[
          mers-cov mcgraw-hill sars-cov-2 sars-cov
          ph-metre ph-metres
        ].freeze

        def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          # Replace hyphen variants
          text = text.gsub("\u2010", "\u002d")  # hyphen to hyphen-minus
          text = text.gsub("\u2011", "\u002d")  # non-breaking hyphen to hyphen-minus

          # Protect decimal points
          text = text.gsub(DECIMAL_POINT, "\\1#{DECIMAL_POINT_PLACEHOLDER}\\2")

          # Protect decimal commas
          text = text.gsub(DECIMAL_COMMA, "\\1#{DECIMAL_COMMA_PLACEHOLDER}\\2")

          # Protect ordinals
          text = text.gsub(ORDINAL, "\\1#{ORDINAL_PLACEHOLDER}\\2")

          # Split on word boundaries
          raw_tokens = text.split(WORD_SEPARATORS)

          # Process each token
          tokens = []
          raw_tokens.each do |token|
            next if token.empty?

            # Restore placeholders
            token = restore_placeholders(token)

            # Handle hyphenated words
            parts = words_to_add(token)
            tokens.concat(parts)
          end

          # Filter and normalize
          tokens
            .map { |token| normalize(token) }
            .reject { |token| skip_token?(token) }
        end

        protected

        # Restore placeholders to original characters.
        #
        # @param token [String] Token with placeholders
        # @return [String] Token with restored characters
        def restore_placeholders(token)
          token
            .gsub(DECIMAL_POINT_PLACEHOLDER, ".")
            .gsub(DECIMAL_COMMA_PLACEHOLDER, ",")
            .gsub(ORDINAL_PLACEHOLDER, ".")
        end

        # Split a word into tokens, handling hyphens.
        #
        # @param word [String] Word to split
        # @return [Array<String>] Array of tokens
        def words_to_add(word)
          return [word] unless word.include?("-")

          # Check do-not-split list
          return [word] if DO_NOT_SPLIT.include?(word.downcase)

          # Remove soft hyphens and check
          normalized = word.gsub(SOFT_HYPHEN, "").gsub("'", "'")

          # For now, split on hyphens if not in do-not-split list
          # Future: integrate with tagger for better handling
          normalized.split("-", -1).flat_map do |part|
            part.empty? ? ["-"] : [part]
          end
        end

        def word_separators
          WORD_SEPARATORS
        end
      end
    end
  end
end
