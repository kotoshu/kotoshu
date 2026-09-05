# frozen_string_literal: true

module Kotoshu
  module Languages
    # Ukrainian language implementation (plan 84, wave 1).
    #
    # Cyrillic composition: the Cyrillic tokenizer keeps
    # Ukrainian-script words (і ї є ґ included; the apostrophe stays a
    # word character for names like Мар'яна). The base normalizer
    # suffices — Ukrainian case folding has no special pairs.
    #
    # Keyboard proximity uses the Ukrainian JCUKEN grid
    # (Keyboard::Layouts::Ukrainian).
    class Ukrainian < LatinBase
      register "uk"
      register "uk-UA"

      def initialize(code: "uk", name: "Ukrainian")
        super
      end

      # Cyrillic-script tokenizer.
      #
      # @return [Language::Tokenizer::CyrillicTokenizer]
      def tokenizer
        @tokenizer ||= Language::Tokenizer::CyrillicTokenizer.new
      end

      def script_type
        :cyrillic
      end

      def default_dictionary_paths
        ["/usr/share/dict/ukrainian"]
      end
    end
  end
end
