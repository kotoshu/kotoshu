# frozen_string_literal: true

module Kotoshu
  module Grammar
    # Urdu POS tagger over the CLE tagset (issue #279) — the lexicon
    # variant of {PosTagger}. The purchased 100k-word human-reviewed
    # CLE corpus compiles into the lexicon (word → tag); until then the
    # tagger covers the small closed classes that are stable Urdu
    # grammar (postpositions, auxiliaries, negation, punctuation) and
    # answers UNKNOWN for open-class words, so callers can route
    # unknown tokens however they need.
    #
    # The serving contract matches {PosTagger}: `tag` returns
    # [{word:, pos:, index:}] per token.
    class UrPosTagger
      # Stable Urdu closed classes — safe to embed pre-lexicon.
      POSTPOSITIONS = %w[کو کی کے سے میں نے پر تک بعد بغیر جیسا جیسے لیے].freeze
      AUXILIARIES   = %w[ہے ہیں ہوں تھا تھی تھے تھاں ہوگا ہوگی رہا رہی رہے سکتا سکتی سکتے چاہئے].freeze
      NEGATIONS     = %w[نہیں نہ مت].freeze
      PRONOUNS      = %w[وہ یہ میں ہم تم آپ اس اسے اسکا اُس ہماری تمہاری انہوں نے].freeze
      PUNCT_RE      = /\A\p{P}+\z/

      # CLE tag → reduced tag for the grammar-rule consumers (the
      # reduced vocabulary the English PosTagger uses).
      REDUCED = {
        "NN" => :NOUN, "NNP" => :PROPER_NOUN,
        "VB" => :VERB_BASE, "VBF" => :VERB, "VBI" => :VERB_BASE,
        "AUXT" => :AUX, "AUXA" => :AUX, "AUXM" => :AUX, "AUXP" => :AUX,
        "PRP" => :PRON, "PRR" => :PRON, "PRS" => :PRON, "PRD" => :PRON,
        "PRF" => :PRON, "APNA" => :PRON,
        "PSP" => :ADP,
        "JJ" => :ADJ, "RB" => :ADV,
        "PRT" => :PART, "NEG" => :NEG, "PDM" => :DET, "Q" => :DET,
        "CC" => :CONJ, "SC" => :CONJ, "SCK" => :CONJ, "SCP" => :CONJ,
        "CD" => :NUM, "OD" => :NUM,
        "PU" => :PUNCT, "SYM" => :PUNCT,
        "INJ" => :INTJ, "VALA" => :PART
      }.freeze

      attr_reader :lexicon

      # @param lexicon [Hash<String, String>] word => CLE tag; empty by
      #   default until the purchased corpus compiles in
      def initialize(lexicon: {})
        @lexicon = lexicon
      end

      # Compile the lexicon from parsed CLE pairs (the 100K purchase
      # drops in here).
      #
      # @param pairs [Array<Array<String, String>>] [word, tag] pairs
      # @return [Integer] lexicon size
      def compile_lexicon(pairs)
        pairs.each do |word, tag|
          next unless Grammar::PosTagset::Ur.tag?(tag)

          @lexicon[word] ||= tag
        end
        @lexicon.size
      end

      # Tag a sentence: token hashes matching the English tagger contract.
      #
      # @param text [String]
      # @return [Array<Hash>] [{word:, pos:, index:}] where pos is the
      #   CLE tag string (or :UNKNOWN for open-class words pre-lexicon)
      def tag(text)
        tokenize(text).each_with_index.map do |word, i|
          { word: word, pos: pos_for(word), index: i }
        end
      end

      # Urdu tokenizes on whitespace; punctuation ۔ ، ؛ etc. splits off.
      #
      # @param text [String]
      # @return [Array<String>]
      def tokenize(text)
        text.split.flat_map { |tok| tok.scan(/[[:word:]‌]+|[[:punct:]]+/) }.reject(&:empty?)
      end

      # Reduced-tag view for the rule engine.
      #
      # @param text [String]
      # @return [Array<Hash>] [{word:, pos:, reduced:, index:}]
      def tag_reduced(text)
        tag(text).map do |tok|
          tok[:reduced] = REDUCED[tok[:pos]] || :UNKNOWN
          tok
        end
      end

      private

      def pos_for(word)
        return @lexicon[word] if @lexicon.key?(word)
        return "PU" if word.match?(PUNCT_RE)
        return "PSP" if POSTPOSITIONS.include?(word)
        return "NEG" if NEGATIONS.include?(word)
        return "AUXT" if AUXILIARIES.include?(word)
        return "PRP" if PRONOUNS.include?(word)

        :UNKNOWN
      end
    end
  end
end
