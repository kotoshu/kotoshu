# frozen_string_literal: true

module Kotoshu
  module Languages
    # Shared base for thin Latin-script language modules.
    #
    # The wave-1 modules (plan 84, Track B) are compositions, not
    # engines: the shared Latin tokenizer, the base normalizer, and a
    # registry entry. Language-specific care overrides one piece:
    # Turkish swaps in the Turkish normalizer (dotless-i folding),
    # Greek swaps in the Greek tokenizer and normalizer, Ukrainian the
    # Cyrillic tokenizer.
    #
    # The existing ten modules (ar de en es fa fr he ja pt ru) are
    # untouched and keep their own class bodies.
    class LatinBase < Language::Base
      # Latin tokenizer shared by every Latin-script module.
      #
      # @return [Language::Tokenizer::LatinTokenizer]
      def tokenizer
        @tokenizer ||= Language::Tokenizer::LatinTokenizer.new
      end

      # Base normalizer (whitespace, downcase).
      #
      # @return [Language::Normalizer::Base]
      def normalizer
        @normalizer ||= Language::Normalizer::Base.new
      end

      # Dictionary backend for this language.
      #
      # @return [Class]
      def dictionary_class
        Dictionary::UnixWords
      end

      # Script type.
      #
      # @return [Symbol] :latin
      def script_type
        :latin
      end

      # Create the tokenizer (memoized; tokenizers are stateless).
      #
      # @return [Language::Tokenizer::Base]
      def create_tokenizer
        tokenizer
      end
    end
  end
end
