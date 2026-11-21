# frozen_string_literal: true

module Kotoshu
  module Grammar
    module PosTagset
      # The CLE Urdu POS Tagset as canonical data (issue #277).
      #
      # Spec: "The CLE Urdu POS Tagset" (LREC 2014,
      # https://aclanthology.org/L14-1250/) — 12 major categories with
      # subdivisions, 32 tags, Penn Treebank + Common Tagset for Indian
      # Languages lineage. CLE applied this tagset to the 100k words of
      # the CLE Urdu Digest Corpus at 96.8% automatic accuracy; the
      # human-reviewed purchase rides the same spec.
      #
      # 31 of the 32 tags are attested in the complimentary human-verified
      # sample (pk-cle-urdu delivery, 2026-11-20). VB (bare verb) is
      # recorded from the paper's schema and flagged SPEC_DERIVED until
      # the full delivery attests it.
      module Ur
        # MAJOR: the 12 major categories of the CLE schema.
        MAJOR_CATEGORIES = {
          noun: "Nouns and proper nouns",
          verb: "Finite, infinitive and bare verb forms",
          auxiliary: "Auxiliary verbs by syntactic context",
          pronoun: "Personal, relative, reflexive, demonstrative, intensifier",
          postposition: "Urdu postpositions (case markers)",
          adjective: "Adjectives and adjective participles",
          adverb: "Adverbs",
          particle: "Particles, negation, demonstratives, quantifiers",
          conjunction: "Coordinating and subordinating conjunctions",
          number: "Cardinal and ordinal numbers",
          punctuation: "Punctuation and symbols",
          residual: "Interjections and residuals"
        }.freeze

        TAGS = {
          "NN" => { gloss: "noun", major: :noun },
          "NNP" => { gloss: "proper noun", major: :noun },
          "VB" => { gloss: "bare verb form (root/stem)", major: :verb,
                    note: "SPEC_DERIVED — not attested in the 2k sample" },
          "VBF" => { gloss: "finite verb", major: :verb },
          "VBI" => { gloss: "infinitive verb", major: :verb },
          "AUXT" => { gloss: "auxiliary, tense carrier", major: :auxiliary },
          "AUXA" => { gloss: "auxiliary, aspectual", major: :auxiliary },
          "AUXM" => { gloss: "auxiliary, modal", major: :auxiliary },
          "AUXP" => { gloss: "auxiliary, passive/copular", major: :auxiliary },
          "PRP" => { gloss: "personal pronoun", major: :pronoun },
          "PRR" => { gloss: "relative pronoun", major: :pronoun },
          "PRS" => { gloss: "reflexive pronoun", major: :pronoun },
          "PRD" => { gloss: "demonstrative pronoun", major: :pronoun },
          "PRF" => { gloss: "intensive/reflexive-focus pronoun", major: :pronoun },
          "APNA" => { gloss: "reflexive possessive اپنا", major: :pronoun },
          "PSP" => { gloss: "postposition (case marker)", major: :postposition },
          "JJ" => { gloss: "adjective", major: :adjective },
          "RB" => { gloss: "adverb", major: :adverb },
          "PRT" => { gloss: "particle", major: :particle },
          "NEG" => { gloss: "negation particle نہیں/نہ", major: :particle },
          "PDM" => { gloss: "demonstrative", major: :particle },
          "Q" => { gloss: "quantifier/frequency word", major: :particle },
          "CC" => { gloss: "coordinating conjunction", major: :conjunction },
          "SC" => { gloss: "subordinating conjunction", major: :conjunction },
          "SCK" => { gloss: "subordinating conjunction, conditional", major: :conjunction },
          "SCP" => { gloss: "subordinating conjunction, purpose", major: :conjunction },
          "CD" => { gloss: "cardinal number", major: :number },
          "OD" => { gloss: "ordinal number", major: :number },
          "PU" => { gloss: "punctuation", major: :punctuation },
          "SYM" => { gloss: "symbol", major: :punctuation },
          "VALA" => { gloss: "والا agentive-morpheme tag", major: :particle },
          "INJ" => { gloss: "interjection", major: :residual }
        }.freeze

        ALL = TAGS.keys.sort.freeze
        SPEC_DERIVED = TAGS.select { |_, v| v[:note] }.keys.freeze

        def self.tag?(tag)
          TAGS.key?(tag)
        end

        def self.major(tag)
          TAGS.dig(tag, :major)
        end

        def self.gloss(tag)
          TAGS.dig(tag, :gloss)
        end

        def self.major_count
          MAJOR_CATEGORIES.size
        end

        def self.size
          TAGS.size
        end
      end
    end
  end
end
