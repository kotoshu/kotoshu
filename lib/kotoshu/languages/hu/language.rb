# frozen_string_literal: true

module Kotoshu
  module Languages
    # Hungarian language implementation (plan 84, wave 1).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. Hungarian long vowels ő ű are dead-key sequences on the QWERTZ physical layout.
    class Hungarian < LatinBase
      register "hu"
      register "hu-HU"

      def initialize(code: "hu", name: "Hungarian")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/hungarian"]
      end
    end
  end
end
