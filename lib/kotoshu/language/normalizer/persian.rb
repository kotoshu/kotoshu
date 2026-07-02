# frozen_string_literal: true

module Kotoshu
  module Language
    module Normalizer
      # Normalizer for Persian (Farsi) script.
      #
      # Extends {Arabic} with Persian-specific letter mappings.
      # Persian shares the Arabic script but uses different
      # codepoints for several letters that look the same to a
      # reader but are distinct in Unicode:
      #
      # - Arabic Yeh (ي U+064A) → Persian Yeh (ی U+06CC)
      # - Arabic Kaf (ك U+0643) → Persian Kaf (ک U+06A9)
      #
      # Input text from Arabic-origin sources may contain either
      # form. This normalizer maps both to the Persian form so a
      # dictionary storing Persian codepoints matches.
      class Persian < Arabic
        # Arabic → Persian letter canonicalization.
        PERSIAN_LETTER_MAP = {
          "ي" => "ی",  # Arabic Yeh → Persian Yeh
          "ك" => "ک"   # Arabic Kaf → Persian Kaf
        }.freeze

        def normalize(text, _options = {})
          return "" if text.nil? || text.empty?

          result = super
          PERSIAN_LETTER_MAP.each { |from, to| result = result.gsub(from, to) }
          result
        end
      end
    end
  end
end
