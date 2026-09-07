# frozen_string_literal: true

module Kotoshu
  module Languages
    # Slovak language implementation (plan 100, batch 3).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. Slovak diacritics (á ä č ď é í ľ ĺ ň ó ô ŕ š ť
    # ú ý ž) are dead keys over the US QWERTY grid
    # (Keyboard::Layouts::Latin::Slovak), the Polish programmers'
    # pattern the eval harness also models.
    class Slovak < LatinBase
      register "sk"
      register "sk-SK"

      def initialize(code: "sk", name: "Slovak")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/slovak"]
      end
    end
  end
end
