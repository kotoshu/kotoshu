# frozen_string_literal: true

module Kotoshu
  module Languages
    # Indonesian language implementation (plan 100, batch 3).
    #
    # Thin composition like the wave-1 members: shared Latin
    # tokenizer, base normalizer, registry entry. Indonesian is typed
    # on the unmodified US QWERTY grid (Keyboard::Layouts::Latin::Indonesian)
    # — the language has no diacritics, so the Latin base covers it
    # without any per-language care.
    class Indonesian < LatinBase
      register "id"
      register "id-ID"

      def initialize(code: "id", name: "Indonesian")
        super
      end

      def default_dictionary_paths
        ["/usr/share/dict/indonesian"]
      end
    end
  end
end
