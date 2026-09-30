# frozen_string_literal: true

module Kotoshu
  module Grammar
    module PatternMatchers
      # Matches a sequence of POS-tagged tokens against a pattern of
      # POS constraints (TODO.grammar/1). This is the workhorse for
      # agreement rules, confusion rules, and any pattern that needs
      # syntactic context.
      #
      # Pattern DSL (YAML):
      #   pattern:
      #     - { pos: PRON_3SG }              # he/she/it
      #     - { pos: VERB_BASE }             # go, make, see
      #     - { word: [very, really] }       # specific words
      #     - { regex: "^(un|in)" }          # regex match
      #     - { pos: VERB_BASE, optional: true }  # optional slot
      #     - { pos: ADJ, exception: [very] } # ADJ but not "very"
      #
      # @example Subject-verb agreement rule
      #   pattern:
      #     - { pos: PRON_3SG }
      #     - { pos: VERB_BASE }
      #   message: "Third-person subject requires a third-person verb"
      #   suggestion: "{{1}}s"
      class PosSequenceMatcher < BaseMatcher
        # Match tokens against the POS pattern.
        #
        # @param tokens [Array<Hash>] token hashes from PosTagger
        # @param rule [Rule] the rule being checked
        # @return [Array<Hash>] error hashes
        def match(tokens, rule)
          errors = []
          pattern = rule.pattern_data
          return errors if pattern.nil? || pattern.empty?

          tagged = tag_tokens(tokens)
          (0..(tagged.length - pattern.length)).each do |start|
            window = tagged[start, pattern.length]
            next unless window_match?(window, pattern)

            errors << build_error(window, rule, start)
            break if rule.single_match?
          end
          errors
        end

        private

        # Tag tokens if not already tagged (the tagger runs lazily).
        def tag_tokens(tokens)
          return tokens if tokens.first&.key?(:pos)

          tagger = PosTagger.new
          tagger.tag(tokens.map { |t| t.is_a?(Hash) ? t[:word] : t.to_s }.join(" "))
        end

        # Check if a window of tokens matches the full pattern.
        def window_match?(window, pattern)
          window.zip(pattern).all? do |token, constraint|
            token_match?(token, constraint)
          end
        end

        # Check if a single token matches a single constraint.
        def token_match?(token, constraint)
          # Word match (exact or list)
          if constraint["word"]
            words = constraint["word"].is_a?(Array) ? constraint["word"] : [constraint["word"]]
            return false unless words.any? { |w| w.downcase == token[:word].downcase }
          end

          # Regex match
          if constraint["regex"] && !token[:word].downcase.match?(constraint["regex"])
            return false
          end

          # POS match
          if constraint["pos"]
            expected = constraint["pos"].to_sym
            actual = token[:pos]
            return false unless pos_match?(actual, expected)
          end

          # Negation / exception
          if constraint["exception"]
            exc = constraint["exception"].is_a?(Array) ? constraint["exception"] : [constraint["exception"]]
            return false if exc.any? { |w| w.downcase == token[:word].downcase }
          end

          true
        end

        # POS matching with hierarchical groups.
        def pos_match?(actual, expected)
          return true if actual == expected

          # Hierarchical: VERB matches all verb subtypes
          case expected
          when :VERB then %i[VERB VERB_BASE VERB_3SG VERB_PAST VERB_ING VERB_PARTICIPLE].include?(actual)
          when :NOUN then %i[NOUN SING_NOUN PLUR_NOUN PROPER_NOUN].include?(actual)
          when :ADJ then actual == :ADJ
          else actual == expected
          end
        end

        # Build the error hash from a matched window.
        def build_error(window, rule, start)
          target = window[0][:word]
          {
            type: rule.category,
            rule_id: rule.id,
            start_index: start,
            end_index: start + window.length - 1,
            target_word: target,
            tokens: window.map { |t| t[:word] },
            message: interpolate(rule.message, window),
            suggestions: rule.suggestions_for(window)
          }
        end

        # Interpolate {{0}}, {{1}}, etc. in the message.
        def interpolate(message, window)
          message.gsub(/\{\{(\d+)\}\}/) { window[Regexp.last_match(1).to_i][:word] }
        end
      end
    end
  end
end
