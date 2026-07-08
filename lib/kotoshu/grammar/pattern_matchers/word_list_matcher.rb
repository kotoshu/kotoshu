# frozen_string_literal: true

module Kotoshu
  module Grammar
    module PatternMatchers
      # Matcher for word-list corrections.
      #
      # Flags any token whose lowercase form is a key in the rule's
      # +corrections+ map. Useful for proper-noun capitalization
      # (monday → Monday, english → English) where a single rule
      # covers dozens of word pairs.
      #
      # Rule shape:
      #
      #   patterns:
      #     - conditions:
      #         - type: word_list_check
      #           corrections:
      #             monday: Monday
      #             tuesday: Tuesday
      #             english: English
      #
      # The matcher only fires when the actual token text differs from
      # the mapped correction (so "Monday" doesn't get flagged).
      #
      class WordListMatcher < BaseMatcher
        def match(tokens, rule)
          corrections = word_list_condition&.dig('corrections') || {}
          return [] if corrections.empty?

          errors = []
          tokens.each do |token|
            word = token[:token]
            next unless word

            correction = corrections[word.downcase]
            next unless correction
            next if word == correction # already correct

            errors << build_error(token, correction, rule)
          end
          errors
        end

        private

        def word_list_condition
          @word_list_condition ||= @pattern['conditions']&.find do |c|
            c['type'] == 'word_list_check'
          end
        end

        def build_error(token, correction, rule)
          {
            rule_id: rule.id,
            position: token[:position],
            message: rule.message,
            suggestion: correction,
            context: "\"#{token[:token]}\"",
            suggestions: [correction]
          }
        end
      end
    end
  end
end
