# frozen_string_literal: true

module Kotoshu
  module Languages
    # Danish language implementation (plan 84, wave 1).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. Danish å æ ø are real keys on the Nordic physical layout (Keyboard::Layouts::Latin::Danish).
    class Danish < LatinBase
      register "da"
      register "da-DK"

      def initialize(code: "da", name: "Danish")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/danish"]
      end
    end
  end
end
