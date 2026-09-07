# frozen_string_literal: true

module Kotoshu
  module Languages
    # Croatian language implementation (plan 100, batch 3).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. The five Croatian digraph letters š đ č ć ž are
    # real keys on the South-Slavic QWERTZ physical layout
    # (Keyboard::Layouts::Croatian), shared with Slovenian.
    class Croatian < LatinBase
      register "hr"
      register "hr-HR"

      def initialize(code: "hr", name: "Croatian")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/croatian"]
      end
    end
  end
end
