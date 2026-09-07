# frozen_string_literal: true

module Kotoshu
  module Languages
    # Persian (Farsi) language implementation.
    #
    # Registers the Persian language with {Language::Registry} under
    # the +fa+ and +fa-IR+ codes. Uses the
    # {Language::Normalizer::Persian} normalizer (Arabic normalization
    # plus Arabic→Persian letter canonicalization).
    #
    # @example
    #   lang = Kotoshu::Languages::Persian.new
    #   lang.script_type  # => :arabic
    #   lang.rtl?         # => true
    #
    # Full-feature since plan 100 (batch 3): the spelling dictionary
    # downloads from the dictionaries repo (AVAILABLE_LANGUAGES) and
    # keyboard proximity uses the Persian standard grid
    # (Keyboard::Layouts::PersianStandard).
    class Persian < Language::Base
      register "fa"
      register "fa-IR"

      def initialize(code: "fa", name: "Persian", variant: nil)
        super
      end

      def description
        name
      end

      def tokenizer
        @tokenizer ||= Tokenizer.new
      end

      def normalizer
        @normalizer ||= Language::Normalizer::Persian.new
      end

      def dictionary_class
        Dictionary::Custom
      end

      def default_dictionary_paths
        ["/usr/share/dict/persian"]
      end

      def script_type
        :arabic
      end

      def rtl?
        true
      end

      class Tokenizer < Language::Tokenizer::Base
        PERSIAN_SEPARATORS = /[\s"()\[\]{}<>,.;:!?\\\/|`~@#$%^&*+\-·،؛؟]/

        def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          text.split(PERSIAN_SEPARATORS)
            .map { |token| normalize(token) }
            .reject { |token| skip_token?(token) }
        end

        # Spell-check word characters (plan 91 pattern, added by
        # plan 100): Arabic-script letters plus ZWNJ (U+200C) —
        # Persian compounds like می‌روم keep their nimb-fāsele inside
        # the word, and the staged dictionary carries tens of
        # thousands of ZWNJ forms.
        #
        # @return [Regexp] Regex matching a single word character
        def spellcheck_word_regex
          /[\p{Arabic}\u200C]/
        end

        protected

        def normalize(token)
          token.strip
        end

        def word_separators
          PERSIAN_SEPARATORS
        end
      end
    end
  end
end
