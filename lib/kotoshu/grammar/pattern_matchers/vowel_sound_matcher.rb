# frozen_string_literal: true

module Kotoshu
  module Grammar
    module PatternMatchers
      # Matcher for a/an article usage rules.
      #
      # This matcher checks if "a" or "an" is used correctly before
      # vowel and consonant sounds.
      class VowelSoundMatcher < BaseMatcher
        VOWEL_SOUNDS = %w[a e i o u].freeze

        # Match tokens against the a/an pattern.
        #
        # @param tokens [Array<Hash>] Array of token hashes
        # @param rule [Rule] The rule being checked
        # @return [Array<Hash>] Array of error hashes
        def match(tokens, rule)
          errors = []
          tokens.each_cons(2) do |prev_token, current_token|
            prev_word = prev_token[:token]&.downcase
            next unless %w[a an].include?(prev_word)
            next unless prev_token[:pos_tag] == 'DET' || prev_token[:pos_tag].nil?

            next_word = current_token[:token]
            next if next_word.nil? || next_word.empty?

            expected = article_for(next_word, rule)
            if prev_word != expected
              errors << build_error(prev_token, current_token, expected, rule)
            end
          end
          errors
        end

        private

        # Determine the correct article for a word.
        #
        # @param word [String] The word to check
        # @param rule [Rule] The rule with exceptions
        # @return [String] "a" or "an"
        def article_for(word, rule)
          word_downcase = word.downcase
          exceptions = rule.exceptions || {}

          consonant_exceptions = exceptions['consonant_sound_exceptions'] || []
          return 'a' if consonant_exceptions.include?(word_downcase)

          silent_exceptions = exceptions['silent_consonant_exceptions'] || []
          return 'an' if silent_exceptions.include?(word_downcase)

          first_char = word_downcase[0]
          VOWEL_SOUNDS.include?(first_char) ? 'an' : 'a'
        end

        # Build an error hash.
        #
        # @param prev_token [Hash] The previous token (article)
        # @param current_token [Hash] The current token (word)
        # @param expected [String] The expected article
        # @param rule [Rule] The rule being checked
        # @return [Hash] Error hash
        def build_error(prev_token, current_token, expected, rule)
          prev_word = prev_token[:token]
          next_word = current_token[:token]
          message = rule.message.gsub('{expected}', expected).gsub('{word}', next_word)

          {
            rule_id: rule.id,
            position: prev_token[:position],
            message: message,
            suggestion: expected,
            context: "#{prev_word} #{next_word}",
            suggestions: [expected]
          }
        end
      end
    end
  end
end
