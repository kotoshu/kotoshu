# frozen_string_literal: true

module Kotoshu
  module Grammar
    module Loaders
      # Maps LanguageTool POS tags (Penn Treebank style, with LT-specific
      # extensions) onto the reduced Kotoshu tagset (TODO.grammar/7).
      #
      # LT stores tags either as exact atoms ("VBZ") or — with
      # postag_regexp="yes" — as alternations/patterns ("NN.*",
      # "DT|PRP\\$", "VB[DZ]", "NNP?S"). This mapper decomposes both
      # forms into symbols understood by PosSequenceMatcher#pos_match?,
      # including the hierarchical groups (:VERB covers all verb
      # subtypes, :NOUN covers singular/plural/proper).
      module PosMapper
        # Exact LT tag → Kotoshu tag. nil means "cannot express".
        EXACT = {
          "NN" => :SING_NOUN, "NN:UN" => :SING_NOUN, "NN:U" => :SING_NOUN,
          "NNS" => :PLUR_NOUN,
          "NNP" => :PROPER_NOUN, "NNPS" => :PROPER_NOUN,
          "VB" => :VERB_BASE, "VBP" => :VERB_BASE, "VBZ" => :VERB_3SG,
          "VBD" => :VERB_PAST, "VBG" => :VERB_ING, "VBN" => :VERB_PARTICIPLE,
          "MD" => :MODAL,
          "JJ" => :ADJ, "JJR" => :ADJ, "JJS" => :ADJ,
          "RB" => :ADV, "RBR" => :ADV, "RBS" => :ADV,
          "IN" => :PREP, "TO" => :PREP,
          "DT" => :DET, "PRP$" => :DET, "PDT" => :DET, "PRP_S" => :DET,
          "PRP" => :PRON, "PRP_O" => :PRON,
          "CC" => :CONJ, "CD" => :NUMBER,
          "PCT" => :PUNCT, "," => :PUNCT, "." => :PUNCT,
          "UH" => :INTERJ, "EX" => :ANY,
          "WDT" => :WH, "WP" => :WH, "WP$" => :WH, "WRB" => :WH,
          "SENT_START" => :SENT_START, "SENT_END" => :SENT_END,
          "UNKNOWN" => :ANY
        }.freeze

        # Leading-letter prefix → hierarchical group tag. Longer
        # prefixes win (PRP_S before PRP).
        PREFIX = [
          ["PRP_S", :DET], ["PRP_O", :PRON], ["PRP", :PRON],
          ["VB", :VERB], ["NN", :NOUN], ["JJ", :ADJ], ["RB", :ADV],
          ["W", :WH],
          ["N", :NOUN], ["V", :VERB], ["J", :ADJ], ["R", :ADV],
          ["MD", :MODAL], ["CD", :NUMBER], ["IN", :PREP]
        ].freeze

        class << self
          # Map an LT postag. Returns a Kotoshu tag symbol, an array of
          # them (alternation), or nil when the tag cannot be expressed.
          #
          # @param postag [String] the LT tag or tag regexp
          # @param regexp [Boolean] true when LT set postag_regexp="yes"
          # @return [Symbol, Array<Symbol>, nil]
          def map(postag, regexp: false)
            return nil if postag.nil? || postag.empty?
            return EXACT[postag] if EXACT.key?(postag)

            regexp ? map_regexp(postag) : nil
          end

          private

          def map_regexp(pattern)
            atoms = pattern.split("|").flat_map { |alt| atoms_of(alt) }
            return nil if atoms.include?(nil)
            return nil if atoms.empty?

            tags = atoms.flatten.uniq
            tags.size == 1 ? tags.first : tags
          end

          # Reduce one alternative of the alternation to its atom(s).
          # Handles: "NN.*" prefix groups, "NNP?S"/"VBP?" optional
          # segments, "VB[DZ]" char classes, "\\$" escapes, ":UN"
          # LT-internal suffixes.
          def atoms_of(alt)
            stem = alt.gsub("\\$", "$").gsub("(?:", "(")

            # Trailing optional segment: "NN:UN?" → "NN:UN", "VBP?" → "VBP"
            trailing = stem.sub(/\?+\z/, "")
            return EXACT[trailing] if EXACT.key?(trailing)

            # Longest-prefix match against the original stem (so PRP_S
            # stays distinct from PRP): "VB[DZ]" → VB, "NNP?S" → NN.
            PREFIX.each do |prefix, tag|
              return tag if stem.start_with?(prefix)
            end
            nil
          end
        end
      end
    end
  end
end
