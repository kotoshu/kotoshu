# frozen_string_literal: true

module Kotoshu
  module Languages
    # Bulgarian language implementation (plan 100, batch 3).
    #
    # Cyrillic composition like Ukrainian: the Cyrillic tokenizer
    # keeps Bulgarian-script words, the base normalizer suffices —
    # Bulgarian case folding has no special pairs. The Bulgarian-only
    # letter ъ (and ь) are real keys on the Bulgarian BDS grid
    # (Keyboard::Layouts::BulgarianBds), not the Russian JCUKEN the
    # pre-existing Cyrillic layout models.
    class Bulgarian < LatinBase
      register "bg"
      register "bg-BG"

      def initialize(code: "bg", name: "Bulgarian")
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
        ["/usr/share/dict/bulgarian"]
      end
    end
  end
end
