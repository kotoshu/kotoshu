# frozen_string_literal: true

module Kotoshu
  module Language
    module Tokenizer
      # Tokenizer for French text.
      #
      # Ported from LanguageTool's FrenchWordTokenizer.
      #
      # Handles:
      # - Apostrophes (l', d', qu', c'est, j'ai, etc.)
      # - Hyphens (c'est-à-dire, rendez-vous, etc.)
      # - Decimal points/commas
      # - Multiple contraction patterns (7 total)
      class FrenchTokenizer < Base
        # French word separators - most punctuation and whitespace
        # Note: apostrophe (') is NOT a separator in French (used for contractions)
        WORD_SEPARATORS = /[\s"()\[\]{}<>,.;:!?\\\/|`~@#$%^&*·]/

        # Do-not-split list (from LanguageTool)
        DO_NOT_SPLIT = %w[
          mers-cov mcgraw-hill sars-cov-2 sars-cov
          ph-metre ph-metres anti-ivg anti-uv anti-vih al-qaïda
          c'est-à-dire add-on add-ons rendez-vous garde-à-vous
          chez-eux chez-moi chez-nous chez-soi chez-toi chez-vous
          m'as-tu-vu
        ].freeze

        # Contraction patterns (from LanguageTool)
        # French contractions are complex: l', d', qu', c'est, j'ai, n'a, etc.
        CONTRACTION_PATTERNS = [
          # c' followed by word: c'est, c'était, etc.
          /^(c')$/i,
          # j' (je): j'ai, j'aime, etc.
          /^(j')$/i,
          # n' (ne): n'a, n'est, etc.
          /^(n')$/i,
          # m' (me): m'a, m'appelle, etc.
          /^(m')$/i,
          # t' (te): t'a, t'asseoir, etc.
          /^(t')$/i,
          # s' (se): s'a, s'appelle, etc.
          /^(s')$/i,
          # l' (le/la): l'a, l'homme, l'eau, etc.
          /^(l')$/i,
          # d' (de): d'un, d'une, d'abord, etc.
          /^(d')$/i,
          # qu' (que): qu'un, qu'une, qu'est, etc.
          /^(qu')$/i,
          # jusqu'à, jusqu'aux, etc.
          /^(jusqu')$/i,
          # puisque, puisqu'il, etc.
          /^(puisqu')$/i,
          # quoique, quoiqu'il, etc.
          /^(quoiqu')$/i,
          # lorsque, lorsqu'il, etc.
          /^(lorsqu')$/i,
        ].freeze

        def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          # Replace hyphen variants
          text = text.gsub("\u2010", "\u002d")
          text = text.gsub("\u2011", "\u002d")

          # Normalize apostrophes
          text = normalize_apostrophes(text)

          # Split on word boundaries
          raw_tokens = text.split(WORD_SEPARATORS)

          # Process each token
          tokens = []
          raw_tokens.each do |token|
            next if token.empty?

            # Try to split contractions and hyphenated words
            parts = split_french_word(token)
            tokens.concat(parts)
          end

          # Filter and normalize
          tokens
            .map { |token| normalize(token) }
            .reject { |token| skip_token?(token) }
        end

        protected

        # Normalize apostrophes to straight quotes.
        #
        # @param text [String] Input text
        # @return [String] Text with normalized apostrophes
        def normalize_apostrophes(text)
          text
            .gsub("'", "'")
            .gsub("'", "'")
            .gsub("'", "'")
        end

        # Split French word, handling contractions and hyphens.
        #
        # @param word [String] Word to split
        # @return [Array<String>] Array of tokens
        def split_french_word(word)
          # Check do-not-split list
          return [word] if DO_NOT_SPLIT.include?(word.downcase)

          # Handle hyphens first (but not for do-not-split words)
          if word.include?("-")
            # Check if it's a contraction pattern like "jusqu'à-ce"
            if word.match?(/^(jusqu'|[cç]'|j'|n'|m'|t'|s'|l'|d'|qu'|lorsqu'|puisqu'|quoiqu')/)
              # Split on hyphen for contractions
              parts = []
              word.split("-", -1).each do |part|
                next if part.empty?

                parts.concat(split_contractions(part))
              end
              return parts
            else
              # Regular hyphenated word - split it
              return word.split("-", -1).reject(&:empty?)
            end
          end

          # Handle contractions
          if word.include?("'")
            return split_contractions(word)
          end

          # No special handling needed
          [word]
        end

        # Split contractions into component parts.
        #
        # @param word [String] Word that might be a contraction
        # @return [Array<String>] Array of tokens
        def split_contractions(word)
          # Try each contraction pattern
          CONTRACTION_PATTERNS.each do |pattern|
            match = word.match(pattern)
            if match
              # Return the contraction and the rest of the word
              contraction = match[1]
              rest = word.sub(/^#{Regexp.escape(contraction)}/, "")
              return [contraction, rest] unless rest.empty?

              return [contraction]
            end
          end

          # Handle special case: word starts with apostrophe
          if word.match?(/^[cç]'|^[a-z]'/i)
            # Split at the apostrophe
            parts = word.split("'", 2)
            return parts if parts.length == 2
          end

          # No pattern matched, return the word as-is
          [word]
        end

        def word_separators
          WORD_SEPARATORS
        end
      end
    end
  end
end
