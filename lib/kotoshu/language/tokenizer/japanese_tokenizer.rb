# frozen_string_literal: true

module Kotoshu
  module Language
    module Tokenizer
      # Tokenizer for Japanese text.
      #
      # Uses Suika gem for morphological analysis. Suika is a soft runtime
      # dependency — see {Kotoshu::Language::Suika} for load status and
      # {Kotoshu::SuikaUnavailable} for the error raised when Japanese
      # tokenization is requested without it.
      #
      # @see https://github.com/yoshoku/suika
      class JapaneseTokenizer < Base
        # Japanese word separators - keep it simple since Suika handles tokenization
        WORD_SEPARATORS = /[\s"()\[\]{}<>,.;:!?\\\/|`~@#$%^&*·]/

        def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          # Suika::Tagger is process-wide memoized in Language::Suika;
          # raises SuikaUnavailable when the gem is missing.
          tagger = Kotoshu::Language::Suika.tagger

          # Suika.parse returns an array of "surface\tfeatures" strings
          tokens = []
          parsed = tagger.parse(text)

          parsed.each do |token|
            # Suika returns: "すもも	名詞,一般,*,*,*,*,すもも,スモモ,スモモ"
            # The surface form is tab-separated from the POS features
            surface = token.split("\t").first
            tokens << surface if surface && !surface.strip.empty?
          end

          tokens
        end

        protected

        # Detect if text contains Japanese script.
        #
        # @param text [String] Text to check
        # @return [Boolean] True if Japanese
        def japanese?(text)
          text.match?(/[぀-ゟ゠-ヿ]/) # Hiragana or Katakana
        end

        def word_separators
          WORD_SEPARATORS
        end
      end
    end
  end
end
