# frozen_string_literal: true

module Kotoshu
  module Languages
    # Greek language implementation (plan 84, wave 1).
    #
    # Greek-aware composition: the Greek tokenizer keeps Greek-script
    # words (the Latin tokenizer's letter checks would drop them), and
    # the Greek normalizer handles the two script-specific folds:
    #
    # - final sigma: ΕΛΛΑΣ folds to ελλας (ς), not ελλασ (σ), matching
    #   dictionary forms;
    # - optional accent stripping (πάτησις -> πατησις) for
    #   accent-insensitive comparison, off by default because Greek
    #   Hunspell dictionaries carry accents.
    #
    # Keyboard proximity uses the Greek phonetic grid
    # (Keyboard::Layouts::GreekPhonetic).
    class Greek < LatinBase
      register "el"
      register "el-GR"

      def initialize(code: "el", name: "Greek")
        super
      end

      # Greek-script tokenizer.
      #
      # @return [Language::Tokenizer::GreekTokenizer]
      def tokenizer
        @tokenizer ||= Language::Tokenizer::GreekTokenizer.new
      end

      # Greek-aware normalizer (final sigma, accent stripping).
      #
      # @return [Language::Normalizer::Greek]
      def normalizer
        @normalizer ||= Language::Normalizer::Greek.new
      end

      def script_type
        :greek
      end

      def default_dictionary_paths
        ["/usr/share/dict/greek"]
      end
    end
  end
end
