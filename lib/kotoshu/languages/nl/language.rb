# frozen_string_literal: true

module Kotoshu
  module Languages
    # Dutch language implementation (plan 84, wave 1).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. Dutch loanword accents (é ï ö ü) are dead-key sequences on the US physical layout.
    class Dutch < LatinBase
      register "nl"
      register "nl-NL"

      def initialize(code: "nl", name: "Dutch")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/dutch"]
      end
    end
  end
end
