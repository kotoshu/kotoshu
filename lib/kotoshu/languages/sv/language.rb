# frozen_string_literal: true

module Kotoshu
  module Languages
    # Swedish language implementation (plan 84, wave 1).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. Swedish å ä ö are real keys on the Nordic physical layout (Keyboard::Layouts::Latin::Swedish).
    class Swedish < LatinBase
      register "sv"
      register "sv-SE"

      def initialize(code: "sv", name: "Swedish")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/swedish"]
      end
    end
  end
end
