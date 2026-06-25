# frozen_string_literal: true

module Kotoshu
  module Language
    module Tokenizer
      # Tokenizer for Portuguese text.
      #
      # Ported from LanguageTool's PortugueseWordTokenizer.
      #
      # Handles:
      # - Decimal comma between digits (3,14)
      # - Dotted numbers (1.000.000)
      # - Dates (01.01.2024, 2024-01-01)
      # - Colons in time (12:25)
      # - Hyphens with do-not-split list
      # - Spaced decimals (2 000 000)
      class PortugueseTokenizer < Base
        # Portuguese word separators - most punctuation and whitespace
        # Note: We protect special patterns before splitting
        WORD_SEPARATORS = /[\s"()\[\]{}<>@€£\\$%‰‱ºªᵃᵒˢ|`~#^·]/.freeze

        # Placeholder characters (using non-printing characters)
        DECIMAL_COMMA_SUBST = "\uE001"
        NON_BREAKING_SPACE_SUBST = "\uE002"
        NON_BREAKING_DOT_SUBST = "\uE003"
        NON_BREAKING_COLON_SUBST = "\uE004"

        # Decimal comma between digits: 3,14
        DECIMAL_COMMA_PATTERN = /(\d),(\d)/

        # Dotted numbers: 1.000.000
        DOTTED_NUMBERS_PATTERN = /(\d)\.(\d)/

        # Colon in numbers (time): 12:25
        COLON_NUMBERS_PATTERN = /(\d):(\d)/

        # Date patterns: 01.01.2024, 2024-01-01
        DATE_PATTERN = /(\d{2})\.(\d{2})\.(\d{4})|(\d{4})\.(\d{2})\.(\d{2})|(\d{4})-(\d{2})-(\d{2})/

        # Spaced decimals: 2 000 000
        SPACED_DECIMAL_PATTERN = /(?<=^|[\s(])\d{1,3}( \d{3})+(?:[,#{DECIMAL_COMMA_SUBST}#{NON_BREAKING_DOT_SUBST}]\d+)?(?=\D|$)/

        # Do-not-split list (from LanguageTool)
        DO_NOT_SPLIT = %w[
          mers-cov mcgraw-hill sars-cov-2 sars-cov
          ph-metre ph-metres anti-ivg anti-uv anti-vih al-qaïda
        ].freeze

        def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          # Handle decimal commas
          if text.include?(",")
            text = text.gsub(DECIMAL_COMMA_PATTERN, "\\1#{DECIMAL_COMMA_SUBST}\\2")
          end

          # Handle dots in numbers and dates
          if text.include?(".")
            # Handle dates first (before dotted numbers to avoid conflicts)
            text = text.gsub(DATE_PATTERN) do |match|
              # match[0] is the full match, match[1-9] are the capture groups
              if match[1] && match[2] && match[3] # DD.MM.YYYY
                "#{match[1]}#{NON_BREAKING_DOT_SUBST}#{match[2]}#{NON_BREAKING_DOT_SUBST}#{match[3]}"
              elsif match[4] && match[5] && match[6] # YYYY.MM.DD
                "#{match[4]}#{NON_BREAKING_DOT_SUBST}#{match[5]}#{NON_BREAKING_DOT_SUBST}#{match[6]}"
              elsif match[7] && match[8] && match[9] # YYYY-MM-DD (keep as-is)
                match[0]
              else
                match[0]
              end
            end
            text = text.gsub(DOTTED_NUMBERS_PATTERN, "\\1#{NON_BREAKING_DOT_SUBST}\\2")
          end

          # Handle spaced decimals: 2 000 000
          text = handle_spaced_decimals(text)

          # Handle colons in time: 12:25
          if text.include?(":")
            text = text.gsub(COLON_NUMBERS_PATTERN, "\\1#{NON_BREAKING_COLON_SUBST}\\2")
          end

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
            .gsub(DECIMAL_COMMA_SUBST, ",")
            .gsub(NON_BREAKING_COLON_SUBST, ":")
            .gsub(NON_BREAKING_SPACE_SUBST, " ")
            .gsub(NON_BREAKING_DOT_SUBST, ".")
        end

        # Split a word into tokens, handling hyphens.
        #
        # @param word [String] Word to split
        # @return [Array<String>] Array of tokens
        def words_to_add(word)
          return [word] unless word.include?("-")

          # Check do-not-split list
          return [word] if DO_NOT_SPLIT.include?(word.downcase)

          # For now, split on hyphens if not in do-not-split list
          # Future: integrate with tagger for better handling
          word.split("-", -1).flat_map do |part|
            part.empty? ? ["-"] : [part]
          end
        end

        def word_separators
          WORD_SEPARATORS
        end

        private

        # Handle spaced decimals: 2 000 000.
        #
        # @param text [String] Input text
        # @return [String] Text with non-breaking spaces
        def handle_spaced_decimals(text)
          result = text
          text.scan(SPACED_DECIMAL_PATTERN) do
            match = Regexp.last_match
            split_number = match[0]
            split_number_adjusted = split_number.gsub(" ", NON_BREAKING_SPACE_SUBST)
            split_number_adjusted = split_number_adjusted.gsub("\u00A0", NON_BREAKING_SPACE_SUBST)
            result = result.sub(split_number, split_number_adjusted)
          end
          result
        end
      end
    end
  end
end
