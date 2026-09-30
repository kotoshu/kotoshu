# frozen_string_literal: true

module Kotoshu
  module Grammar
    # Rule-based POS tagger for English (TODO.grammar/1).
    #
    # Deterministic, no ML dependency, pure hash lookups and suffix
    # rules — target <1ms per sentence. Produces a reduced tagset
    # (the 17 tags grammar rules actually need, not the 45-tag Penn
    # Treebank set).
    #
    # The tagset:
    #   NOUN SING_NOUN PLUR_NOUN PROPER_NOUN
    #   VERB VERB_BASE VERB_3SG VERB_PAST VERB_ING VERB_PARTICIPLE
    #   ADJ ADV
    #   PREP DET PRON_3SG PRON_PLURAL MODAL AUX CONJ INTERJ NUMBER
    #
    # Tagging algorithm:
    #   1. Word-list lookup (irregulars, function words, closed classes)
    #   2. Suffix rules (-ing, -ed, -ly, -tion, etc.)
    #   3. Context disambiguation (DET → ADJ, MODAL → VERB_BASE)
    #   4. Capitalization → PROPER_NOUN (mid-sentence)
    #
    # @example
    #   tagger = PosTagger.new
    #   tagger.tag("He go to school")
    #   # => [{word:"He", pos:PRON_3SG}, {word:"go", pos:VERB_BASE}, ...]
    class PosTagger
      # The reduced tagset (17 tags — enough for grammar rules)
      TAGS = %i[
        NOUN SING_NOUN PLUR_NOUN PROPER_NOUN
        VERB VERB_BASE VERB_3SG VERB_PAST VERB_ING VERB_PARTICIPLE
        ADJ ADV PREP DET PRON_3SG PRON_PLURAL MODAL AUX CONJ INTERJ NUMBER
      ].freeze

      # Closed-class word lists (deterministic — no suffix needed)
      PRONOUNS_3SG = %w[he she it this that].freeze
      PRONOUNS_PLURAL = %w[they we you these those].freeze
      MODALS = %w[can could may might must shall should will would
                  ought need dare].freeze
      AUXILIARIES = %w[be am is are was were been being have has had
                       do does did].freeze
      DETERMINERS = %w[a an the this that these those my your his her
                       its our their every each some any no].freeze
      PREPOSITIONS = %w[in on at by for with from to of about over
                        under between among through during before
                        after above below near against without within
                        into onto upon across behind beyond despite
                        except inside outside toward towards].freeze
      CONJUNCTIONS = %w[and but or nor so yet for if then than when
                        while although because since unless until
                        whereas whether].freeze
      INTERJECTIONS = %w[oh ah eh um uh hey wow ouch oops].freeze
      NUMBERS = %w[one two three four five six seven eight nine ten
                   hundred thousand million billion].freeze

      # Common irregular verbs: base → [3sg, past, past_participle]
      IRREGULAR_VERBS = {
        "be" => %w[is was been], "have" => %w[has had had],
        "do" => %w[does did done], "go" => %w[goes went gone],
        "say" => %w[says said said], "make" => %w[makes made made],
        "know" => %w[knows knew known], "take" => %w[takes took taken],
        "see" => %w[sees saw seen], "come" => %w[comes came come],
        "get" => %w[gets got gotten], "give" => %w[gives gave given],
        "find" => %w[finds found found], "tell" => %w[tells told told],
        "write" => %w[writes wrote written], "run" => %w[runs ran run],
        "put" => %w[puts put put], "set" => %w[sets set set]
      }.freeze

      # Suffix → POS rules (checked after the word lists)
      SUFFIX_RULES = [
        { suffix: "ing", pos: :VERB_ING },
        { suffix: "edly", pos: :ADV },
        { suffix: "ly", pos: :ADV },
        { suffix: "tion", pos: :NOUN },
        { suffix: "sion", pos: :NOUN },
        { suffix: "ment", pos: :NOUN },
        { suffix: "ness", pos: :NOUN },
        { suffix: "ity", pos: :NOUN },
        { suffix: "ance", pos: :NOUN },
        { suffix: "ence", pos: :NOUN },
        { suffix: "able", pos: :ADJ },
        { suffix: "ible", pos: :ADJ },
        { suffix: "ous", pos: :ADJ },
        { suffix: "ful", pos: :ADJ },
        { suffix: "less", pos: :ADJ },
        { suffix: "ive", pos: :ADJ },
        { suffix: "ish", pos: :ADJ },
        { suffix: "al", pos: :ADJ },
        { suffix: "ic", pos: :ADJ },
        { suffix: "ed", pos: :VERB_PAST },
        { suffix: "er", pos: %i[NOUN ADJ] },
        { suffix: "est", pos: :ADJ },
        { suffix: "s", pos: :PLUR_NOUN }
      ].freeze

      # @param language [String] the language code (en for now)
      def initialize(language: "en")
        @language = language
      end

      # Tag a sentence: returns an array of token hashes.
      #
      # @param text [String] the sentence to tag
      # @return [Array<Hash>] [{word:, pos:, lemma:, index:}]
      def tag(text)
        words = tokenize(text)
        tokens = words.each_with_index.map do |word, i|
          { word: word, pos: pos_for(word, i, words), index: i }
        end
        disambiguate(tokens)
      end

      # Tokenize: split on whitespace + punctuation boundaries.
      #
      # @param text [String]
      # @return [Array<String>]
      def tokenize(text)
        text.scan(/[\w'-]+|[.,!?;:()"'\/]/).reject(&:empty?)
      end

      private

      # Determine POS for a single word, using context.
      def pos_for(word, index, all_words)
        lower = word.downcase

        # 1. Closed-class word lists
        return :PRON_3SG if PRONOUNS_3SG.include?(lower)
        return :PRON_PLURAL if PRONOUNS_PLURAL.include?(lower)
        return :MODAL if MODALS.include?(lower)
        return :AUX if AUXILIARIES.include?(lower)
        return :DET if DETERMINERS.include?(lower)
        return :PREP if PREPOSITIONS.include?(lower)
        return :CONJ if CONJUNCTIONS.include?(lower)
        return :INTERJ if INTERJECTIONS.include?(lower)
        return :NUMBER if NUMBERS.include?(lower) || lower.match?(/^\d/)
        return :VERB_3SG if ["is", "has"].include?(lower)
        return :VERB_PAST if ["was", "had"].include?(lower)
        return :VERB_BASE if IRREGULAR_VERBS.key?(lower)

        # Irregular verb forms
        IRREGULAR_VERBS.each do |_base, forms|
          return :VERB_3SG if lower == forms[0]
          return :VERB_PAST if lower == forms[1]
          return :VERB_PARTICIPLE if lower == forms[2]
        end

        # 2. Suffix rules
        SUFFIX_RULES.each do |rule|
          next unless lower.end_with?(rule[:suffix])
          return rule[:pos].first if rule[:pos].is_a?(Array) && word_list_hint(rule[:pos], lower)

          return rule[:pos].is_a?(Array) ? rule[:pos].first : rule[:pos]
        end

        # 3. Context: word after MODAL/AUX → VERB_BASE
        if index > 0
          prev = all_words[index - 1].downcase
          return :VERB_BASE if MODALS.include?(prev) || AUXILIARIES.include?(prev)
        end

        # 4. Capitalization → PROPER_NOUN (mid-sentence)
        return :PROPER_NOUN if index > 0 && word[0] == word[0].upcase && word[0].match?(/[A-Z]/)

        # 5. Default
        :NOUN
      end

      # Contextual disambiguation: refine ambiguous tags.
      def disambiguate(tokens)
        tokens.each_with_index do |token, i|
          # DET + X → if X is ADJ, keep; if X is NOUN, it's the head
          next_token = tokens[i + 1]
          prev_token = tokens[i - 1]

          # "the ___" → if tagged NOUN, could be ADJ (the big dog)
          if token[:pos] == :NOUN && prev_token&.dig(:pos) == :DET && next_token && next_token[:pos] == :NOUN
            token[:pos] = :ADJ
          end

          # DET before NOUN → keep DET
          next if token[:pos] == :DET && next_token && %i[NOUN SING_NOUN PLUR_NOUN PROPER_NOUN ADJ].include?(next_token[:pos])

          # "to" before VERB_BASE → PREP vs infinitive marker (both :PREP is fine for grammar rules)
        end
        tokens
      end

      # Heuristic for ambiguous suffix matches (er/est)
      def word_list_hint(candidates, word)
        # For now: default to the first candidate
        %i[NOUN ADJ].include?(candidates.first)
      end
    end
  end
end
