# frozen_string_literal: true

module Kotoshu
  module Languages
    # Romanian language implementation (plan 84, wave 1).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. Romanian diacritics (ă â î ș ț) are AltGr sequences on the US physical layout.
    class Romanian < LatinBase
      register "ro"
      register "ro-RO"

      def initialize(code: "ro", name: "Romanian")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/romanian"]
      end
    end
  end
end
