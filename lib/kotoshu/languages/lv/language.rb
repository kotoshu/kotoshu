# frozen_string_literal: true

module Kotoshu
  module Languages
    # Latvian language implementation (plan 100, batch 3).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. The Latvian letters ā č ē ģ ī ķ ļ ņ š ū ž are
    # dead-key / AltGr sequences over the US QWERTY grid
    # (Keyboard::Layouts::Latin::Latvian), like the eval model.
    class Latvian < LatinBase
      register "lv"
      register "lv-LV"

      def initialize(code: "lv", name: "Latvian")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/latvian"]
      end
    end
  end
end
