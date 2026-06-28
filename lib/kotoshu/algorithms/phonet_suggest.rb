# frozen_string_literal: true

module Kotoshu
  module Algorithms
    # Phonetic suggestion algorithm provides suggestions based on phonetical
    # (pronunciation) similarity.
    #
    # Ported from Spylls (Python) phonet_suggest.py
    #
    # Requires .aff file to define PHONE table (extremely rare in known dictionaries).
    #
    # Internally:
    # 1. Selects words from dictionary similarly to ngram_suggest
    #    (and reuses its root_score)
    # 2. Scores their phonetic representations (calculated with metaphone)
    #    with phonetic representation of misspelling
    # 3. Chooses the most similar ones with final_score (ngram-based comparison)
    module PhonetSuggest
      MAX_ROOTS = 100

      class << self
        # Main entry point for phonetic suggestions.
        #
        # Note that both this method and NgramSuggest.suggest iterate through
        # the whole dictionary. Hunspell optimizes by doing it all in one
        # loop. Spylls (and Kotoshu) splits them for clarity.
        #
        # @param misspelling [String] The misspelled word
        # @param dictionary_words [Array<Hash>] Dictionary entries with stem and flags
        # @param table [Hash] Phone table with :rules hash mapping first char to rule list
        # @yield [String] Each suggestion
        #
        # The table structure should have:
        # - :rules => Hash mapping first character to array of rule hashes
        #   Each rule has: :search (Regexp), :replacement (String),
        #                  :start (Boolean), :end (Boolean)
        def suggest(misspelling, dictionary_words:, table:, &block)
          misspelling_lower = misspelling.downcase
          misspelling_ph = metaphone(table, misspelling_lower)

          scores = []

          # First, select words from dictionary whose stems are similar to misspelling
          # This cycle is exactly the same as the first cycle in ngram_suggest
          dictionary_words.each do |word|
            stem = word[:stem] || word

            # Skip words with length difference > 3
            next if (stem.length - misspelling.length).abs > 3

            # First, calculate "regular" similarity score, just like in ngram_suggest
            nscore = NgramSuggest.root_score(misspelling_lower, stem)

            # Check alternative spellings if available
            if word[:alt_spellings]
              word[:alt_spellings].each do |variant|
                nscore = [nscore, NgramSuggest.root_score(misspelling_lower, variant)].max
              end
            end

            next if nscore <= 2

            # Calculate metaphone score
            word_ph = metaphone(table, stem.downcase)
            score = 2 * StringMetrics.ngram(3, misspelling_ph, word_ph, longer_worse: true)

            # Use heap-like behavior: keep only MAX_ROOTS best results
            if scores.size >= MAX_ROOTS
              # Remove the worst score if we're at capacity
              scores.sort!.shift if scores.first && scores.first[0] < score
            end

            scores << [score, stem] if scores.size < MAX_ROOTS || scores.empty? || score > scores.first[0]
          end

          # Sort by (score, stem) tuple descending. Python's heap-based
          # nlargest uses full-tuple comparison, so ties on score are broken
          # by descending stem — matching that here is what reproduces
          # Spylls/Hunspell's phonet suggestion order.
          guesses = scores.sort { |a, b| b <=> a }

          # Final pass: re-score with the precise metric. The second sort
          # must be stable by score only — Python's sorted(key=..., reverse=True)
          # preserves the order from the previous sort for ties, which is
          # load-bearing for the phone.sug fixture.
          guesses2 = guesses.map do |score, word|
            final_scr = final_score(misspelling_lower, word.downcase)
            [score + final_scr, word]
          end.sort_by { |score, _| -score }

          guesses2.each do |_, sug|
            yield sug
          end
        end

        # Calculate score of suggestion against misspelling.
        #
        # @param word1 [String] Misspelling
        # @param word2 [String] Candidate suggestion
        # @return [Float] Final score
        def final_score(word1, word2)
          2 * StringMetrics.lcslen(word1, word2) -
            (word1.length - word2.length).abs +
            StringMetrics.leftcommonsubstring(word1, word2)
        end

        # Metaphone calculation.
        #
        # Production in Kotoshu is currently implemented naively as just
        # "search and replace" for rules. To see what potentially should be done,
        # look at aspell's original description:
        # http://aspell.net/man-html/Phonetic-Code.html
        #
        # @param table [Readers::PhonetTable] Phone table
        # @param word [String] Word to calculate metaphone for
        # @return [String] Metaphone representation
        def metaphone(table, word)
          return word if table.nil? || table.empty?

          rules = table.rules
          pos = 0
          word_upper = word.upcase
          result = +''

          while pos < word_upper.length
            char = word_upper[pos]
            matched = false

            # Get rules for this character
            char_rules = rules[char] || []
            char_rules.each do |rule|
              match_result = match_rule(rule, word_upper, pos)
              next unless match_result

              result += rule[:replacement]
              pos += match_result
              matched = true
              break
            end

            pos += 1 unless matched
          end

          result
        end

        # Check if a rule matches at the given position.
        #
        # @param rule [Hash] Rule hash with :search (Regexp), :start, :end
        # @param word [String] The word to match against
        # @param pos [Integer] Position in word
        # @return [Integer, nil] Length of match, or nil if no match
        def match_rule(rule, word, pos)
          # Check start constraint
          return nil if rule[:start] && pos > 0

          # Try to match
          match_data = if rule[:end]
                        # Full match from position
                        rule[:search].match(word[pos..])
                      else
                        # Regular match from position
                        rule[:search].match(word, pos)
                      end

          return nil unless match_data

          match_data.to_s.length
        end
      end
    end
  end
end
