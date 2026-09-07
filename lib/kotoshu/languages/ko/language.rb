# frozen_string_literal: true

module Kotoshu
  module Languages
    # Korean language implementation (plan 108).
    #
    # Registers +ko+ and +ko-KR+. The staged ko dictionary (LibreOffice
    # ko_KR, jamo-decomposed behind an ICONV table of all 11,172
    # syllables) serves checking through the standard Hunspell engine;
    # this module contributes the language wiring the basic tier
    # lacks: the eojeol-aware Hangul tokenizer for word extraction and
    # the Dubeolsik (KS X 5002) keyboard grid for jamo-proximity
    # suggestion ranking.
    #
    # @example
    #   lang = Kotoshu::Languages::Korean.new
    #   lang.script_type  # => :hangul
    #   lang.rtl?         # => false
    class Korean < Language::Base
      register "ko"
      register "ko-KR"

      def initialize(code: "ko", name: "Korean", variant: nil)
        super
      end

      def description
        name
      end

      def tokenizer
        @tokenizer ||= Language::Tokenizer::HangulTokenizer.new
      end

      def normalizer
        @normalizer ||= Language::Normalizer::Base.new
      end

      def dictionary_class
        Dictionary::Custom
      end

      def default_dictionary_paths
        ["/usr/share/dict/korean"]
      end

      def script_type
        :hangul
      end

      def rtl?
        false
      end
    end
  end
end
