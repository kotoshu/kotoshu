# frozen_string_literal: true

module Kotoshu
  module Languages
    # Estonian language implementation (plan 100, batch 3).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. The Estonian letters ä ö õ ü š ž are dead-key /
    # AltGr sequences over the US QWERTY grid
    # (Keyboard::Layouts::Latin::Estonian), like the eval model.
    class Estonian < LatinBase
      register "et"
      register "et-EE"

      def initialize(code: "et", name: "Estonian")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/estonian"]
      end
    end
  end
end
