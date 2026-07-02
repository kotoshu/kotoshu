# frozen_string_literal: true

module Kotoshu
  module Languages
    # Arabic language implementation.
    #
    # Registers the Arabic language with {Language::Registry} under the
    # +ar+ and +ar-SA+ codes. Uses the {Language::Normalizer::Arabic}
    # normalizer (NFC + presentation-form canonicalization + tashkeel
    # stripping) so that the same word typed in different input
    # methods produces the same normalized form for dictionary lookup.
    #
    # @example
    #   lang = Kotoshu::Languages::Arabic.new
    #   lang.script_type  # => :arabic
    #   lang.rtl?         # => true
    class Arabic < Language::Base
      register "ar"
      register "ar-SA"

      def initialize(code: "ar", name: "Arabic", variant: nil)
        super
      end

      def description
        name
      end

      def tokenizer
        @tokenizer ||= Tokenizer.new
      end

      def normalizer
        @normalizer ||= Language::Normalizer::Arabic.new
      end

      def dictionary_class
        Dictionary::Custom
      end

      def default_dictionary_paths
        ["/usr/share/dict/arabic"]
      end

      def script_type
        :arabic
      end

      # Arabic is written right-to-left.
      def rtl?
        true
      end

      # Minimal Arabic tokenizer.
      #
      # Splits on whitespace and standard punctuation — Arabic text
      # is space-delimited. Uses Base#skip_token? which correctly
      # handles Unicode letters via \p{L}, so Arabic characters are
      # kept while pure numbers and single non-letter chars are
      # filtered.
      class Tokenizer < Language::Tokenizer::Base
        ARABIC_SEPARATORS = /[\s"()\[\]{}<>,.;:!?\\\/|`~@#$%^&*+\-·،؛؟]/

        def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          text.split(ARABIC_SEPARATORS)
            .map { |token| normalize(token) }
            .reject { |token| skip_token?(token) }
        end

        protected

        def normalize(token)
          token.strip
        end

        def word_separators
          ARABIC_SEPARATORS
        end
      end
    end
  end
end
