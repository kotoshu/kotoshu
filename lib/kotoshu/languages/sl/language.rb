# frozen_string_literal: true

module Kotoshu
  module Languages
    # Slovenian language implementation (plan 100, batch 3).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. The Slovenian letters č š ž (plus the Croatian
    # đ ć the grid also carries) are real keys on the South-Slavic
    # QWERTZ physical layout (Keyboard::Layouts::Slovenian), shared
    # with Croatian.
    class Slovenian < LatinBase
      register "sl"
      register "sl-SI"

      def initialize(code: "sl", name: "Slovenian")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/slovenian"]
      end
    end
  end
end
