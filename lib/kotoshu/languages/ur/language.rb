# frozen_string_literal: true

module Kotoshu
  module Languages
    # Urdu language implementation.
    #
    # Registers under the +ur+ and +ur-PK+ codes. Arabic script, RTL,
    # whitespace-delimited (no intra-word segmentation needed at serving
    # time — the ja-v12 tokenizer-mismatch law does not apply).
    #
    # Normalization: Arabic→Urdu letter canonicalization (ك→ک, ي→ی) and
    # tatweel stripping via {Language::Normalizer::Urdu}; Urdu shares the
    # Arabic letter skeleton but carries its own letter repertoire (ٹ ڈ ڑ
    # ں ں ے ھ گ چ پ ژ).
    #
    # Keyboard proximity uses the CRULP Urdu phonetic grid
    # (Keyboard::Layouts::UrduPhonetic).
    #
    # Spelling sources: the CLE Urdu resources (CLE12T003 corpus,
    # CLE12L001 WordNet) power the dictionary package; attribution per
    # Schedule D of the Ribose⇄CLE license ships with the dictionary.
    class Urdu < Language::Base
      register "ur"
      register "ur-PK"

      def initialize(code: "ur", name: "Urdu", variant: nil)
        super
      end

      def description
        name
      end

      def tokenizer
        @tokenizer ||= Tokenizer.new
      end

      def normalizer
        @normalizer ||= Language::Normalizer::Urdu.new
      end

      def dictionary_class
        Dictionary::Custom
      end

      def default_dictionary_paths
        ["/usr/share/dict/urdu"]
      end

      def script_type
        :arabic
      end

      def rtl?
        true
      end

      class Tokenizer < Language::Tokenizer::Base
        # Arabic-script separators plus the Urdu full stop (۔) and
        # comma (،); ASCII punctuation included for mixed text.
        URDU_SEPARATORS = /[\s"()\[\]{}<>,.;:!?\\\/|`~@#$%^&*+\-·،؛؟۔]/

        def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          text.split(URDU_SEPARATORS)
            .map { |token| normalize(token) }
            .reject { |token| skip_token?(token) }
        end

        # Word characters: Arabic-script letters, the Urdu-specific
        # repertoire, ZWNJ (U+200C) and ZWJ (U+200D) — Urdu compounds
        # and the do-chashmi he cluster keep their joiners inside the
        # word.
        #
        # @return [Regexp]
        def spellcheck_word_regex
          /[\p{Arabic}‌‍]/
        end

        protected

        def normalize(token)
          token.strip
        end

        def word_separators
          URDU_SEPARATORS
        end
      end
    end
  end
end
