# frozen_string_literal: true

module Kotoshu
  module Languages
    # Vietnamese language implementation (plan 84, wave 1).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. Vietnamese tone and vowel marks are dead-key sequences over ASCII letters (VIQR-style typing).
    class Vietnamese < LatinBase
      register "vi"
      register "vi-VN"

      def initialize(code: "vi", name: "Vietnamese")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/vietnamese"]
      end
    end
  end
end
