# frozen_string_literal: true

module Kotoshu
  module Languages
    # Norwegian Nynorsk (plan 107): the second Norwegian written
    # standard, wired while basic support opened the staged manifest —
    # dictionary and model are both staged (`nn` in the dictionaries
    # repo, `nn` in the models registry), so Nynorsk users get the
    # full-feature tier rather than the script fallback. Thin
    # composition like its Bokmål sibling — shared Latin tokenizer,
    # base normalizer, registry entry; å æ ø are real keys on the
    # Nordic layout the nb module resolves to.
    class NorwegianNynorsk < LatinBase
      register "nn"
      register "nn-NO"

      def initialize(code: "nn", name: "Norwegian Nynorsk")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/norwegian"]
      end
    end
  end
end
