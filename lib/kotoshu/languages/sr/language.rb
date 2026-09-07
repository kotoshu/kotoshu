# frozen_string_literal: true

module Kotoshu
  module Languages
    # Serbian language implementation (plan 100, batch 3).
    #
    # Cyrillic composition like Bulgarian/Ukrainian: Serbian is
    # written in both scripts, but Cyrillic is the constitutional
    # primary and the script the staged dictionary carries — the
    # module registers sr for the Cyrillic grid
    # (Keyboard::Layouts::SerbianCyrillic); Serbian Latin (sr-Latn)
    # has its own module over the distinct staged Latin dictionary
    # (plan 110, Kotoshu::Languages::SerbianLatin). The Serbian
    # letters љ њ ђ ћ џ ј are real keys on that grid.
    class Serbian < LatinBase
      register "sr"
      register "sr-RS"

      def initialize(code: "sr", name: "Serbian")
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
        ["/usr/share/dict/serbian"]
      end
    end
  end
end
