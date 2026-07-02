# frozen_string_literal: true

module Kotoshu
  module Languages
    # Hebrew language implementation.
    #
    # Registers the Hebrew language with {Language::Registry} under the
    # +he+ and +he-IL+ codes. Uses the {Language::Normalizer::Hebrew}
    # normalizer (NFC + niqqud stripping + dagesh removal + maqaf
    # normalization) so that bare dictionary forms match against
    # user input that may include vowel points.
    #
    # @example
    #   lang = Kotoshu::Languages::Hebrew.new
    #   lang.script_type  # => :hebrew
    #   lang.rtl?         # => true
    class Hebrew < Language::Base
      register "he"
      register "he-IL"

      def initialize(code: "he", name: "Hebrew", variant: nil)
        super
      end

      def description
        name
      end

      def tokenizer
        @tokenizer ||= Tokenizer.new
      end

      def normalizer
        @normalizer ||= Language::Normalizer::Hebrew.new
      end

      def dictionary_class
        Dictionary::Custom
      end

      def default_dictionary_paths
        ["/usr/share/dict/hebrew"]
      end

      def script_type
        :hebrew
      end

      def rtl?
        true
      end

      # Minimal Hebrew tokenizer.
      #
      # Splits on whitespace and standard punctuation — Hebrew text
      # is space-delimited. Includes the Hebrew-specific geresh (׳)
      # and gershayim (״) as word characters (they are used inside
      # acronyms). Uses Base#skip_token? which correctly handles
      # Unicode letters via \p{L}.
      class Tokenizer < Language::Tokenizer::Base
        HEBREW_SEPARATORS = /[\s"()\[\]{}<>,.;:!?\\\/|`~@#$%^&*+\-·]/

        def tokenize(text)
          return [] if text.nil? || text.strip.empty?

          text.split(HEBREW_SEPARATORS)
            .map { |token| normalize(token) }
            .reject { |token| skip_token?(token) }
        end

        protected

        def normalize(token)
          token.strip
        end

        def word_separators
          HEBREW_SEPARATORS
        end
      end
    end
  end
end
