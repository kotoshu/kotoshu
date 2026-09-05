# frozen_string_literal: true

module Kotoshu
  module Languages
    # Polish language implementation (plan 84, wave 1).
    #
    # Thin composition: shared Latin tokenizer, base normalizer,
    # registry entry. Polish diacritics (ą ć ę ł ń ó ś ź ż) are AltGr sequences on the programmers layout.
    class Polish < LatinBase
      register "pl"
      register "pl-PL"

      def initialize(code: "pl", name: "Polish")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/polish"]
      end
    end
  end
end
