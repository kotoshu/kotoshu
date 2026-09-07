# frozen_string: true

module Kotoshu
  module Languages
    # Nepali language implementation (plan 108).
    #
    # Registers +ne+ and +ne-NP+. The staged ne dictionary (LibreOffice
    # ne_NP) serves checking through the standard Hunspell engine;
    # this module contributes the language wiring the basic tier
    # lacks: the Devanagari tokenizer that keeps matras and virama
    # conjuncts attached to their base consonant during word
    # extraction, and the Devanagari InScript grid (the Indian
    # national standard layout, mirrored from the models repo eval
    # harness) for typo-proximity suggestion ranking. The Nepali
    # Traditional Romanized layout is more common on the ground, but
    # it is not a documented standard the way InScript is — the same
    # choice the eval harness made.
    #
    # @example
    #   lang = Kotoshu::Languages::Nepali.new
    #   lang.script_type  # => :devanagari
    #   lang.rtl?         # => false
    class Nepali < Language::Base
      register "ne"
      register "ne-NP"

      def initialize(code: "ne", name: "Nepali", variant: nil)
        super
      end

      def description
        name
      end

      def tokenizer
        @tokenizer ||= Language::Tokenizer::DevanagariTokenizer.new
      end

      def normalizer
        @normalizer ||= Language::Normalizer::Base.new
      end

      def dictionary_class
        Dictionary::Custom
      end

      def default_dictionary_paths
        ["/usr/share/dict/nepali"]
      end

      def script_type
        :devanagari
      end

      def rtl?
        false
      end
    end
  end
end
