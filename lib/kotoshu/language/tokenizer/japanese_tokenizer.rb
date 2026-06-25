# frozen_string_literal: true

require "suika"

module Kotoshu
  module Language
    module Tokenizer
      # Tokenizer for Japanese text.
      #
      # Uses Suika gem for morphological analysis.
      #
      # Suika is a pure Ruby Japanese morphological analyzer with a built-in
      # dictionary from mecab-ipadic. It provides proper tokenization with
      # part-of-speech information.
      #
      # @see https://github.com/yoshoku/suika
      class JapaneseTokenizer < Base
        # Japanese word separators - keep it simple since Suika handles tokenization
        WORD_SEPARATORS = /[\s"()\[\]{}<>,.;:!?\\\/|`~@#$%^&*·]/.freeze

        # Class variable to hold the Suika tagger instance
        @@tagger = nil

        def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          # Initialize tagger once (class variable for reuse)
          @@tagger ||= ::Suika::Tagger.new

          # Suika.parse returns an array of "surface\tfeatures" strings
          tokens = []
          parsed = @@tagger.parse(text)

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
          text.match?(/[\u3040-\u309F\u30A0-\u30FF]/) # Hiragana or Katakana
        end

        def word_separators
          WORD_SEPARATORS
        end
      end
    end
  end
end
