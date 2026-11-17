# frozen_string_literal: true

module Kotoshu
  module Language
    module Normalizer
      # Normalizer for Urdu script.
      #
      # Extends {Arabic} with Urdu-specific letter canonicalization.
      # Urdu shares the Arabic script, and Arabic-origin text (and
      # Arabic keyboards) carry codepoints that look identical to a
      # reader but are distinct in Unicode:
      #
      # - Arabic Yeh (ي U+064A) → Urdu Yeh (ی U+06CC)
      # - Arabic Kaf (ك U+0643) → Urdu Kaf (ک U+06A9)
      # - Arabic full stop (۔ usage aside) and tatweel (ـ U+0640)
      #   stripped — tatweel is an Arabic justification character
      #   with no Urdu word-internal role.
      #
      # Both forms normalize to the Urdu codepoint so a dictionary
      # storing Urdu spellings matches Arabic-keyboard input.
      class Urdu < Arabic
        URDU_LETTER_MAP = {
          "ي" => "ی",  # Arabic Yeh → Urdu Yeh
          "ك" => "ک",  # Arabic Kaf → Urdu Kaf
          "ٱ" => "ا",  # Alif wasla → Alif
          "ـ" => ""    # Tatweel → removed
        }.freeze

        def normalize(text, _options = {})
          return "" if text.nil? || text.empty?

          result = super
          URDU_LETTER_MAP.each { |from, to| result = result.gsub(from, to) }
          result
        end
      end
    end
  end
end
