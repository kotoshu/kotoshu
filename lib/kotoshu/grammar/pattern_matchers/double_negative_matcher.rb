# frozen_string_literal: true

require_relative 'base_matcher'

module Kotoshu
  module Grammar
    module PatternMatchers
      # Matcher for double negative rules.
      #
      # This matcher detects when multiple negative words appear
      # within a certain distance.
      class DoubleNegativeMatcher < BaseMatcher
        # Match tokens against the double negative pattern.
        #
        # @param tokens [Array<Hash>] Array of token hashes
        # @param rule [Rule] The rule being checked
        # @return [Array<Hash>] Array of error hashes
        def match(tokens, rule)
          errors = []
          exceptions = rule.exceptions || {}
          exception_phrases = exceptions['phrases'] || []

          conditions = @pattern['conditions'] || []
          distance_condition = conditions.find { |c| c['type'] == 'distance_check' }
          max_distance = distance_condition&.dig('max_distance') || 15

          negative_indices = []
          tokens.each_with_index do |token, idx|
            word = token[:token]&.downcase
            next unless is_negative?(word)

            # Skip "not only... but also" pattern
            next if in_exception_phrase?(idx, tokens, exception_phrases)

            negative_indices << idx
          end

          negative_indices.each_cons(2) do |idx1, idx2|
            pos1 = tokens[idx1][:position]
            pos2 = tokens[idx2][:position]
            distance = pos2 - pos1
            next if distance > max_distance

            error = build_error(tokens, idx1, idx2, rule)
            errors << error if error
          end
          errors
        end

        private

        # Check if a word is a negative.
        #
        # @param word [String] The word to check
        # @return [Boolean] True if the word is a negative
        def is_negative?(word)
          return false if word.nil? || word.empty?

          negatives = %w[not no neither nobody never nothing nowhere hardly barely scarcely]
          return true if negatives.include?(word)
          return true if word.end_with?("n't")

          false
        end

        # Check if an index is part of an exception phrase.
        #
        # @param idx [Integer] The token index
        # @param tokens [Array<Hash>] Array of token hashes
        # @param exception_phrases [Array<String>] Exception phrases
        # @return [Boolean] True if in exception phrase
        def in_exception_phrase?(idx, tokens, exception_phrases)
          return false if exception_phrases.empty?

          # Check "not only... but also" pattern
          if idx > 0 && tokens[idx - 1][:token] == 'not' && tokens[idx + 1]&.dig(:token) == 'only'
            return true
          end

          false
        end

        # Build an error hash.
        #
        # @param tokens [Array<Hash>] Array of token hashes
        # @param idx1 [Integer] First negative index
        # @param idx2 [Integer] Second negative index
        # @param rule [Rule] The rule being checked
        # @return [Hash] Error hash
        def build_error(tokens, idx1, idx2, rule)
          words = tokens[idx1..idx2].map { |t| t[:token] }.join(' ')

          {
            rule_id: rule.id,
            position: tokens[idx1][:position],
            message: rule.message,
            suggestion: rule.suggestion,
            context: words,
            suggestions: rule.suggestion ? [rule.suggestion] : []
          }
        end
      end
    end
  end
end
