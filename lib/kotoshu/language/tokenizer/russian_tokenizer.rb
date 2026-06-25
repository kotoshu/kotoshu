# frozen_string_literal: true

module Kotoshu
  module Language
    module Tokenizer
      # Tokenizer for Russian text.
      #
      # Ported from LanguageTool's RussianWordTokenizer.
      #
      # Handles:
      # - Apostrophe as word character
      # - Dot as word character (for abbreviations)
      # - Special abbreviations: б/у (second-hand), б/н (new)
      # - Spaced dots: .. , .
      class RussianTokenizer < Base
        # Russian-specific word separators (exclude apostrophe and dot)
        WORD_SEPARATORS = /[\s"()\[\]{}<>,;:!?\\\/|`~@#$%^&*+\-·]/.freeze

        # Special abbreviations that should not be split
        # Using non-printing characters as placeholders
        ABBREVIATION_PLACEHOLDERS = {
          "б/у" => "\u0001\u0001SOCR_BU\u0001\u0001",
          "б/н" => "\u0001\u0001SOCR_BN\u0001\u0001"
        }.freeze

        # Reverse placeholders for restoration
        PLACEHOLDER_RESTORE = {
          "\u0001\u0001SOCR_BU\u0001\u0001" => "б/у",
          "\u0001\u0001SOCR_BN\u0001\u0001" => "б/н",
          "\u0001\u0001SP_DDOT_SP\u0001\u0001" => " .. ",
          "\u0001\u0001SP_DOT_SP\u0001\u0001" => " . ",
          "\u0001\u0001SP_DOT\u0001\u0001" => "."
        }.freeze

        def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          # Replace abbreviations with placeholders
          text = replace_abbreviations(text)

          # Split on word boundaries
          raw_tokens = text.split(WORD_SEPARATORS)

          # Restore abbreviations and filter
          raw_tokens
            .map { |token| restore_abbreviations(token) }
            .map { |token| normalize(token) }
            .reject { |token| skip_token?(token) }
        end

        protected

        def word_separators
          WORD_SEPARATORS
        end

        private

        # Replace special abbreviations with placeholders.
        #
        # @param text [String] Input text
        # @return [String] Text with placeholders
        def replace_abbreviations(text)
          result = text
          ABBREVIATION_PLACEHOLDERS.each do |abbr, placeholder|
            result = result.gsub(abbr, placeholder)
          end

          # Handle spaced dots
          result = result.gsub(" .. ", "\u0001\u0001SP_DDOT_SP\u0001\u0001")
          result = result.gsub(" . ", "\u0001\u0001SP_DOT_SP\u0001\u0001")
          result = result.gsub(" .", " \u0001\u0001SP_DOT\u0001\u0001")

          # Restore spaced dots first, then single dot pattern
          result = result.gsub("\u0001\u0001SP_DDOT_SP\u0001\u0001", " .. ")
          result = result.gsub("\u0001\u0001SP_DOT_SP\u0001\u0001", " . ")

          result
        end

        # Restore abbreviations from placeholders.
        #
        # @param text [String] Text with placeholders
        # @return [String] Text with restored abbreviations
        def restore_abbreviations(text)
          result = text
          PLACEHOLDER_RESTORE.each do |placeholder, original|
            result = result.gsub(placeholder, original)
          end
          result
        end
      end
    end
  end
end
