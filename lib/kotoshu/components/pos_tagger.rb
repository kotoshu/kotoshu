# frozen_string_literal: true

module Kotoshu
  module Components
    # Base class for POS (Part-of-Speech) taggers.
    #
    # POS taggers assign grammatical categories (NOUN, VERB, ADJ, etc.) to tokens.
    # Different languages use different POS tagging strategies:
    # - Latin scripts: Dictionary-based (Hunspell flags → POS tags)
    # - CJK: Integrated with morphological analysis (tokenizer provides POS)
    # - German: Compound word decomposition affects tagging
    #
    # Common POS tags (Penn Treebank style):
    # - CC: Coordinating conjunction
    # - CD: Cardinal number
    # - DT: Determiner
    # - EX: Existential there
    # - FW: Foreign word
    # - IN: Preposition or subordinating conjunction
    # - JJ: Adjective
    # - JJR: Adjective, comparative
    # - JJS: Adjective, superlative
    # - LS: List item marker
    # - MD: Modal
    # - NN: Noun, singular or mass
    # - NNS: Noun, plural
    # - NNP: Proper noun, singular
    # - NNPS: Proper noun, plural
    # - PDT: Predeterminer
    # - POS: Possessive ending
    # - PRP: Personal pronoun
    # - PRP$: Possessive pronoun
    # - RB: Adverb
    # - RBR: Adverb, comparative
    # - RBS: Adverb, superlative
    # - RP: Particle
    # - SYM: Symbol
    # - TO: to
    # - UH: Interjection
    # - VB: Verb, base form
    # - VBD: Verb, past tense
    # - VBG: Verb, gerund or present participle
    # - VBN: Verb, past participle
    # - VBP: Verb, non-3rd person singular present
    # - VBZ: Verb, 3rd person singular present
    # - WDT: Wh-determiner
    # - WP: Wh-pronoun
    # - WP$: Possessive wh-pronoun
    # - WRB: Wh-adverb
    #
    # Language-specific tags:
    # - CJK uses its own tagset (e.g., Japanese: 名詞, 動詞, etc.)
    # - German uses STTS tagset
    #
    # @abstract Subclasses must implement #tag
    #
    # @example Tagging tokens
    #   tagger = EnglishPosTagger.new(aff_path: "en_US.aff", dic_path: "en_US.dic")
    #   tokens = [
    #     { token: "The", position: 0, length: 3 },
    #     { token: "dog", position: 4, length: 3 },
    #     { token: "runs", position: 8, length: 4 }
    #   ]
    #   tagged = tagger.tag(tokens)
    #   # => [
    #   #      { token: "The", position: 0, length: 3, pos_tag: "DET", lemma: "the" },
    #   #      { token: "dog", position: 4, length: 3, pos_tag: "NOUN", lemma: "dog" },
    #   #      { token: "runs", position: 8, length: 4, pos_tag: "VERB", lemma: "run" }
    #   #    ]
    class PosTagger
      # Tag tokens with POS information.
      #
      # Takes an array of token hashes (from Tokenizer#tokenize) and adds:
      # - :pos_tag (String, nil) - POS category (NOUN, VERB, etc.) or nil if unknown
      # - :lemma (String, nil) - Lemma/base form or nil if unknown
      #
      # @abstract Subclasses must implement
      # @param tokens [Array<Hash>] Array of token hashes from Tokenizer
      # @return [Array<Hash>] Token hashes with added :pos_tag and :lemma keys
      # @raise [NotImplementedError] if not implemented by subclass
      def tag(tokens)
        raise NotImplementedError, "#{self.class} must implement #tag"
      end

      # Tag a single word.
      #
      # Convenience method for single-word tagging.
      #
      # @param word [String] The word to tag
      # @return [Hash] Hash with :pos_tag and :lemma keys (may be nil)
      def tag_word(word)
        token = { token: word, position: 0, length: word.length }
        result = tag([token])
        result.first || { pos_tag: nil, lemma: nil }
      end
    end
  end
end
