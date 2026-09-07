# frozen_string_literal: true

module Kotoshu
  module Languages
    # Serbian Latin implementation (plan 110).
    #
    # The Latin script variant of Serbian, the last named gap in the
    # corpus after plan 107 opened the staged manifest. The data
    # decided the wiring: the dictionaries manifest stages a distinct
    # sr-Latn dictionary (LibreOffice, wooorm/dictionaries), so
    # sr-Latn resolves its own download rather than riding the
    # Cyrillic sr dictionary — and because sr and sr-Latn differ by
    # script, not vocabulary, a script-subtag code must survive
    # ResourceManager language normalization (plan 110) for the
    # staged Latin files to be reachable at all.
    #
    # Thin composition like its Croatian sibling: shared Latin
    # tokenizer (\p{Latin} covers š đ č ć ž), base normalizer,
    # registry entry. The five Latin digraph letters are real keys on
    # the South-Slavic QWERTZ grid
    # (Keyboard::Layouts::SerbianLatin, the physical arrangement the
    # hr and sl modules share).
    class SerbianLatin < LatinBase
      register "sr-Latn"

      def initialize(code: "sr-Latn", name: "Serbian (Latin)")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/serbian"]
      end
    end
  end
end
