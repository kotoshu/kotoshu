# frozen_string_literal: true

module Kotoshu
  module Languages
    # Lithuanian language implementation (plan 100, batch 3).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. The Lithuanian letters ą č ę ė į š ų ū ž are
    # dead-key / AltGr sequences over the US QWERTY grid
    # (Keyboard::Layouts::Latin::Lithuanian), like the eval model.
    class Lithuanian < LatinBase
      register "lt"
      register "lt-LT"

      def initialize(code: "lt", name: "Lithuanian")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/lithuanian"]
      end
    end
  end
end
