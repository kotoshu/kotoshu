# frozen_string_literal: true

module Kotoshu
  module Languages
    # Turkish language implementation (plan 84, wave 1).
    #
    # Thin composition plus one piece of real care: Turkish case
    # folding. Turkish has a separate dotted/dotless i pair (I/ı and
    # i/İ), so a Unicode-default downcase maps uppercase words onto
    # letter sequences no Turkish dictionary contains. The Turkish
    # normalizer uses Ruby's :turkic case mapping (I -> ı, İ -> i),
    # so İZMİR looks up as izmir and ISTANBUL as ıstanbul.
    #
    # The ı ğ ü ş i ö ç letters are real keys on the Turkish-Q
    # physical layout (Keyboard::Layouts::TurkishQ).
    class Turkish < LatinBase
      register "tr"
      register "tr-TR"

      def initialize(code: "tr", name: "Turkish")
        super
      end

      # Turkish-aware normalizer (dotless-i case folding).
      #
      # @return [Language::Normalizer::Turkish]
      def normalizer
        @normalizer ||= Language::Normalizer::Turkish.new
      end

      def default_dictionary_paths
        ["/usr/share/dict/turkish"]
      end
    end
  end
end
