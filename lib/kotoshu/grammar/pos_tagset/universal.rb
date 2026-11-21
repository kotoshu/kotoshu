# frozen_string_literal: true

module Kotoshu
  module Grammar
    module PosTagset
      # The Universal POS tagset (UD v2, https://universaldependencies.org/u/pos/)
      # as canonical data for the Latin languages (issue #289). UD is
      # CC BY-SA 4.0; the tagset names are the shared cross-language
      # vocabulary used by every UD treebank (de/es/fr treebanks
      # included), so per-language taggers and POS-keyed rules can share
      # one reduced mapping.
      module Universal
        TAGS = {
          "ADJ" => "adjective",
          "ADP" => "adposition (pre/postposition)",
          "ADV" => "adverb",
          "AUX" => "auxiliary verb",
          "CCONJ" => "coordinating conjunction",
          "DET" => "determiner",
          "INTJ" => "interjection",
          "NOUN" => "noun",
          "NUM" => "numeral",
          "PART" => "particle",
          "PRON" => "pronoun",
          "PROPN" => "proper noun",
          "PUNCT" => "punctuation",
          "SCONJ" => "subordinating conjunction",
          "SYM" => "symbol",
          "VERB" => "verb (finite and non-finite)",
          "X" => "other/unclassified"
        }.freeze

        ALL = TAGS.keys.sort.freeze

        def self.tag?(tag)
          TAGS.key?(tag)
        end

        def self.gloss(tag)
          TAGS[tag]
        end

        def self.size
          TAGS.size
        end
      end
    end
  end
end
