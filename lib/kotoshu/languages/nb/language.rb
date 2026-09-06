# frozen_string_literal: true

module Kotoshu
  module Languages
    # Norwegian Bokmål (registry v1.3.0: models ship as `nb` from
    # fastText's Bokmål-dominated cc.no vectors; the Language registry
    # aliases `no` here). Thin composition like its Nordic siblings —
    # shared Latin tokenizer, base normalizer, registry entry; å æ ø
    # are real keys on the Nordic layout.
    class NorwegianBokmal < LatinBase
      register "nb"
      register "nb-NO"
      register "no"
      register "no-NO"

      def initialize(code: "nb", name: "Norwegian Bokmål")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/norwegian"]
      end
    end
  end
end
