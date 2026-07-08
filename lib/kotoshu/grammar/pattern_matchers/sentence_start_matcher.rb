# frozen_string_literal: true

module Kotoshu
  module Grammar
    module PatternMatchers
      # Matcher for sentence-start capitalization rules.
      #
      # English (and most Latin-script languages) capitalizes the
      # first word of every sentence. This matcher walks the token
      # stream tracking sentence boundaries and flags lowercase
      # sentence starts.
      #
      # A sentence starts:
      #   - at the beginning of the stream, OR
      #   - immediately after a token whose final character is a
      #     sentence-ending punctuation mark (. ! ?).
      #
      # The matcher only considers alphabetic tokens. Numbers,
      # symbols, and whitespace don't reset the sentence-start flag.
      #
      # Rule shape:
      #
      #   patterns:
      #     - conditions:
      #         - type: sentence_start_check
      #
      class SentenceStartMatcher < BaseMatcher
        SENTENCE_ENDERS = %w[. ! ?].freeze

        def match(tokens, rule)
          errors = []
          expecting_capital = true

          tokens.each do |token|
            word = token[:token]
            next if word.nil? || word.empty?

            if sentence_start_word?(word, expecting_capital)
              errors << build_error(token, rule)
            end

            # Any non-empty token resets the sentence-start expectation.
            # Only sentence-ending punctuation re-arms it (below).
            expecting_capital = false
            expecting_capital = true if ends_sentence?(word)
          end

          errors
        end

        protected

        def sentence_start_word?(word, expecting_capital)
          expecting_capital && alphabetic_word?(word) && first_letter_lowercase?(word)
        end

        def alphabetic_word?(word)
          !word.nil? && !word.empty? && word[0].match?(/[[:alpha:]]/)
        end

        def first_letter_lowercase?(word)
          first = word[0]
          first == first.downcase && first != first.upcase
        end

        def ends_sentence?(word)
          SENTENCE_ENDERS.include?(word[-1])
        end

        def build_error(token, rule)
          capitalized = token[:token].sub(/\A(\w)/) { $1.upcase }
          {
            rule_id: rule.id,
            position: token[:position],
            message: rule.message,
            suggestion: capitalized,
            context: "\"#{token[:token]}\"",
            suggestions: [capitalized]
          }
        end
      end
    end
  end
end
