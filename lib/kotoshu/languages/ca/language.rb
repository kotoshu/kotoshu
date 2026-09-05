# frozen_string_literal: true

module Kotoshu
  module Languages
    # Catalan language implementation (plan 84, wave 1).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. Catalan diacritics (à é í ó ú ç l·l) are dead-key sequences on the Spanish physical layout.
    class Catalan < LatinBase
      register "ca"
      register "ca-ES"

      def initialize(code: "ca", name: "Catalan")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/catalan"]
      end
    end
  end
end
