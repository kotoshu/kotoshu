# frozen_string_literal: true

module Kotoshu
  module Grammar
    module PatternMatchers
      # Matcher for literal multi-word phrase confusions.
      #
      # Catches phrases where every word is individually valid but the
      # combination is a common error — typically phonetic confusions
      # like "could of" (should be "could have"). The spelling checker
      # passes these because each word is in the dictionary; only a
      # phrase-level grammar check catches them.
      #
      # The rule config declares the wrong phrase and its replacement:
      #
      #   conditions:
      #     - type: phrase_check
      #       wrong_phrase: "could of"
      #       suggestion: "could have"
      #
      # The matcher scans the token stream for consecutive tokens whose
      # downcased text matches +wrong_phrase+ (split on whitespace)
      # and emits one error per match.
      class PhraseMatcher < BaseMatcher
        # Match tokens against the phrase-confusion pattern.
        #
        # @param tokens [Array<Hash>] Array of token hashes
        # @param rule [Rule] The rule being checked
        # @return [Array<Hash>] Array of error hashes
        def match(tokens, rule)
          wrong_phrase = phrase_condition&.dig('wrong_phrase')
          suggestion = phrase_condition&.dig('suggestion')
          return [] unless wrong_phrase && suggestion

          wrong_tokens = wrong_phrase.downcase.split
          return [] if wrong_tokens.empty?

          matches = []
          tokens.each_with_index do |start_token, start_idx|
            next unless start_token[:token]&.downcase == wrong_tokens.first

            match_idx = find_match(tokens, start_idx, wrong_tokens)
            next unless match_idx

            matches << build_error(tokens, match_idx, wrong_tokens.length,
                                   wrong_phrase, suggestion, rule)
          end
          matches
        end

        private

        def phrase_condition
          @phrase_condition ||= @pattern['conditions']&.find do |c|
            c['type'] == 'phrase_check'
          end
        end

        # Walk forward from +start_idx+ and confirm the next
        # +expected.length+ tokens match +expected+ (case-insensitive).
        # Returns the start_idx on full match, nil otherwise.
        def find_match(tokens, start_idx, expected)
          expected.each_with_index do |word, offset|
            tok = tokens[start_idx + offset]
            return nil unless tok && tok[:token]&.downcase == word
          end
          start_idx
        end

        def build_error(tokens, start_idx, length, wrong_phrase, suggestion, rule)
          end_idx = start_idx + length - 1
          words = tokens[start_idx..end_idx].map { |t| t[:token] }.join(' ')
          {
            rule_id: rule.id,
            position: tokens[start_idx][:position],
            message: rule.message,
            suggestion: suggestion,
            context: words,
            suggestions: [suggestion],
            wrong_phrase: wrong_phrase
          }
        end
      end
    end
  end
end
