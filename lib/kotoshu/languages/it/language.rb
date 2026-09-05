# frozen_string_literal: true

module Kotoshu
  module Languages
    # Italian language implementation (plan 84, wave 1).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. Italian accents (à è é ì ò ù) are dead-key sequences on the US physical layout.
    class Italian < LatinBase
      register "it"
      register "it-IT"

      def initialize(code: "it", name: "Italian")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/italian"]
      end
    end
  end
end
