# frozen_string_literal: true

module Kotoshu
  module Languages
    # Czech language implementation (plan 84, wave 1).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. Czech diacritics (háček and čárka letters) are dead-key sequences on the QWERTZ physical layout.
    class Czech < LatinBase
      register "cs"
      register "cs-CZ"

      def initialize(code: "cs", name: "Czech")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/czech"]
      end
    end
  end
end
