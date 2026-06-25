# frozen_string_literal: true

require_relative 'base_matcher'

module Kotoshu
  module Grammar
    module PatternMatchers
      # Matcher for there/their/they're confusion rules.
      #
      # This matcher detects when "there" is used where "their"
      # (possessive) is intended.
      class PossessiveContextMatcher < BaseMatcher
        # Match tokens against the there/their pattern.
        #
        # @param tokens [Array<Hash>] Array of token hashes
        # @param rule [Rule] The rule being checked
        # @return [Array<Hash>] Array of error hashes
        def match(tokens, rule)
          errors = []
          exceptions = rule.exceptions || {}

          location_indicators = exceptions['location_indicators'] || {}
          location_verbs = location_indicators['verbs'] || []
          possessive_nouns = location_indicators['possessive_nouns'] || []

          tokens.each_with_index do |token, idx|
            word = token[:token]&.downcase
            next unless word == 'there'

            next_token = tokens[idx + 1]
            next unless next_token

            next_word = next_token[:token]&.downcase

            # Skip if followed by verb (location/existence context)
            next if location_verbs.include?(next_word)

            uses_their = false

            # Check POS tags first
            next_pos = next_token[:pos_tag]
            if next_pos && ['NOUN', 'NOUN_PROPER', 'ADJ'].include?(next_pos)
              uses_their = true
            # Fallback to word list
            elsif possessive_nouns.include?(next_word)
              uses_their = true
            end

            if uses_their
              errors << build_error(token, next_token, rule)
            end
          end
          errors
        end

        private

        # Build an error hash.
        #
        # @param token [Hash] The token with "there"
        # @param next_token [Hash] The next token
        # @param rule [Rule] The rule being checked
        # @return [Hash] Error hash
        def build_error(token, next_token, rule)
          {
            rule_id: rule.id,
            position: token[:position],
            message: rule.message,
            suggestion: rule.suggestion,
            context: "\"#{token[:token]} #{next_token[:token]}\"",
            suggestions: [rule.suggestion]
          }
        end
      end
    end
  end
end
