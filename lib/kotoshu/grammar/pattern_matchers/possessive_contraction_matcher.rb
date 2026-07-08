# frozen_string_literal: true

module Kotoshu
  module Grammar
    module PatternMatchers
      # Matcher for possessive-vs-contraction confusion rules.
      #
      # Detects when a possessive form ("its", "your", "whose") is
      # used where the corresponding contraction ("it's", "you're",
      # "who's") is intended — or vice versa. The trigger is the
      # following token's POS tag or word form.
      #
      # Rule shape:
      #
      #   patterns:
      #     - context:
      #         target_token: "its"
      #         trigger_when_followed_by:
      #           tags: [ADJ, ADV]
      #           words: [been, going, getting]
      #       conditions:
      #         - type: possessive_contraction_check
      #
      # When the target token is followed by a token whose POS tag is
      # in +tags+ OR whose lowercased form is in +words+, emit an
      # error with +rule.suggestion+ as the replacement.
      #
      # Examples:
      #   "its cold"      → suggest "it's"  (cold is ADJ)
      #   "your ready"    → suggest "you're"
      #   "whose coming"  → suggest "who's"
      class PossessiveContractionMatcher < BaseMatcher
        def match(tokens, rule)
          errors = []
          target = pattern_target_token
          triggers = pattern_triggers

          tokens.each_with_index do |token, idx|
            next unless matches_target?(token, target)

            next_token = tokens[idx + 1]
            next unless next_token
            next unless triggers_match?(next_token, triggers)

            errors << build_error(token, next_token, rule)
          end
          errors
        end

        protected

        def pattern_target_token
          @pattern.dig('context', 'target_token')
        end

        def pattern_triggers
          @pattern.dig('context', 'trigger_when_followed_by') || {}
        end

        def matches_target?(token, target)
          target && token[:token]&.downcase == target.downcase
        end

        def triggers_match?(next_token, triggers)
          trigger_tags = triggers['tags'] || []
          trigger_words = (triggers['words'] || []).map(&:downcase)

          tag = next_token[:pos_tag]
          word = next_token[:token]&.downcase

          trigger_tags.include?(tag) || trigger_words.include?(word)
        end

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
