# frozen_string_literal: true

module Kotoshu
  module Grammar
    module PatternMatchers
      # Matches a sequence of POS-tagged tokens against a pattern of
      # constraints (TODO.grammar/1). The workhorse for agreement,
      # confusion, and all rules converted from LanguageTool XML.
      #
      # Pattern DSL (YAML):
      #   pattern:
      #     - { pos: PRON_3SG }                   # one tag or array of tags
      #     - { pos: [VBZ, VBP] }                 # any-of
      #     - { word: [very, really] }            # exact word(s)
      #     - { regex: "^(un|in)" }               # full-token regex
      #     - { optional: true }                  # slot may be absent
      #     - { skip: 1 }                         # gap of up to 1 token after
      #     - { negated: true, pos: DET }         # must NOT be DET
      #     - { exception: [very] }               # anything but "very"
      #     - { exception_pos: DET }              # any POS except DET
      #     - { case_sensitive: true, word: Dei } # honor case
      #     - { pos: SENT_START }                 # sentence start position
      #     - { pos: SENT_END }                   # sentence end position
      #     - { pos: PUNCT }                      # any punctuation token
      #     - { pos: ANY }                        # wildcard
      #
      # Hierarchical groups: VERB covers all verb subtypes, NOUN covers
      # singular/plural/proper, PRON covers 3sg/plural, ADV covers ADV.
      class PosSequenceMatcher < BaseMatcher
        MAX_PATTERN = 12

        # Match tokens against the rule's pattern.
        #
        # @param tokens [Array<Hash>] token hashes (tagged, or raw words)
        # @param rule [PatternRule, Rule-like] object answering #pattern_data
        # @return [Array<Hash>] error hashes
        def match(tokens, rule)
          errors = []
          pattern = rule.pattern_data
          return errors if pattern.nil? || pattern.empty?
          return errors if pattern.length > MAX_PATTERN

          tagged = tag_tokens(tokens)
          return errors if tagged.empty?

          (0...tagged.length).each do |start|
            consumed = seq_match(tagged, pattern, 0, start, [])
            next if consumed.nil? || consumed.empty?

            errors << build_error(consumed, rule, tagged)
            break if rule.single_match?
          end
          errors
        end

        private

        def tag_tokens(tokens)
          return PosTagger.new.tag(tokens) if tokens.is_a?(String)
          return tokens if tokens.first&.key?(:pos)

          tagger = PosTagger.new
          tagger.tag(tokens.map { |t| t.is_a?(Hash) ? t[:word] : t.to_s }.join(" "))
        end

        # Recursive sequence matcher: try to satisfy pattern[p_i..] from
        # token t_i. Returns the consumed token list, or nil.
        def seq_match(tagged, pattern, p_i, t_i, consumed)
          return consumed if p_i == pattern.length

          constraint = pattern[p_i]
          option = symbolize(constraint)

          # Optional slot: try consuming it, else skip the slot entirely.
          if option[:optional]
            with_taken = try_take(tagged, pattern, p_i, t_i, consumed)
            return with_taken if with_taken

            return seq_match(tagged, pattern, p_i + 1, t_i, consumed)
          end

          try_take(tagged, pattern, p_i, t_i, consumed)
        end

        # Try to satisfy pattern[p_i] at token t_i (or at a position
        # marker), then recurse. Applies the constraint's skip allowance.
        def try_take(tagged, pattern, p_i, t_i, consumed)
          constraint = pattern[p_i]
          option = symbolize(constraint)

          # Position markers consume no token.
          pos = Array(option[:pos]).first.to_sym if option[:pos]
          if pos == :SENT_START
            return nil unless t_i.zero?

            return seq_match(tagged, pattern, p_i + 1, t_i, consumed)
          end
          if pos == :SENT_END
            # LT's SENT_END postag sits on the final token (usually
            # punctuation); consume it and apply its exceptions.
            return nil unless t_i == tagged.length - 1

            token = tagged[t_i]
            return nil unless token_match?(token, constraint, t_i, tagged)

            return seq_match(tagged, pattern, p_i + 1, t_i + 1, consumed + [token])
          end

          return nil if t_i >= tagged.length

          token = tagged[t_i]
          return nil unless token_match?(token, constraint, t_i, tagged)

          taken = consumed + [token]
          max_skip = option[:skip].to_i
          (0..max_skip).each do |gap|
            result = seq_match(tagged, pattern, p_i + 1, t_i + 1 + gap, taken)
            return result if result
          end
          nil
        end

        def token_match?(token, constraint, index, tagged)
          option = symbolize(constraint)
          matched = plain_match?(token, option, index, tagged)
          option[:negated] ? !matched : matched
        end

        def plain_match?(token, option, index, tagged)
          return false unless exception_ok?(token, option, index, tagged)

          pos_values = Array(option[:pos])
          return true if pos_values.first&.to_sym == :ANY
          return punctuation?(token) if pos_values.map { |p| p&.to_sym }.include?(:PUNCT)

          if option.key?(:pos) && !pos_list_match?(token, Array(option[:pos]))
            return false
          end
          if option.key?(:word) && !word_match?(token, option[:word], option[:case_sensitive])
            return false
          end
          if option.key?(:regex) && !regex_match?(token, option[:regex], option[:case_sensitive])
            return false
          end

          true
        end

        def exception_ok?(token, option, index, tagged)
          exc = option[:exception]
          if exc
            words = Array(exc)
            cmp = token[:word].to_s
            return false if words.any? { |w| option[:case_sensitive] ? w.to_s == cmp : w.to_s.downcase == cmp }
          end
          exc_pos = option[:exception_pos]
          if exc_pos && Array(exc_pos).any? { |p| pos_match?(token[:pos], p.to_sym) }
            return false
          end

          prev = option[:previous_exception]
          if prev && index.positive?
            before = tagged[index - 1][:word].to_s.downcase
            return false if Array(prev).any? { |w| w.downcase == before }
          end
          prev_regex = option[:previous_exception_regex]
          if prev_regex && index.positive?
            before = tagged[index - 1][:word].to_s
            Array(prev_regex).each do |pat|
              return false if before.match?(Regexp.new("\\A(?:#{pat})\\z", Regexp::IGNORECASE))
            rescue RegexpError
              next
            end
          end
          exc_regex = option[:exception_regex]
          if exc_regex
            cmp = option[:case_sensitive] ? token[:word].to_s : token[:word].to_s
            Array(exc_regex).each do |pat|
              flags = option[:case_sensitive] ? nil : Regexp::IGNORECASE
              return false if cmp.match?(Regexp.new("\\A(?:#{pat})\\z", flags))
            rescue RegexpError
              next
            end
          end
          true
        end

        def word_match?(token, words, case_sensitive)
          words = Array(words)
          if case_sensitive
            words.include?(token[:word].to_s)
          else
            words.any? { |w| w.to_s.downcase == token[:word].to_s.downcase }
          end
        end

        def regex_match?(token, pattern, case_sensitive)
          regexp = Regexp.new("\\A(?:#{pattern})\\z", case_sensitive ? nil : Regexp::IGNORECASE)
          token[:word].to_s.match?(regexp)
        rescue RegexpError
          false
        end

        def pos_list_match?(token, expected)
          expected.any? { |p| pos_match?(token[:pos], p.to_sym) }
        end

        def pos_match?(actual, expected)
          return true if actual == expected

          case expected
          when :VERB then %i[VERB VERB_BASE VERB_3SG VERB_PAST VERB_ING VERB_PARTICIPLE].include?(actual)
          when :NOUN then %i[NOUN SING_NOUN PLUR_NOUN PROPER_NOUN].include?(actual)
          when :PRON then %i[PRON PRON_1SG PRON_3SG PRON_PLURAL].include?(actual)
          else actual == expected
          end
        end

        def punctuation?(token)
          word = token.is_a?(Hash) ? token[:word].to_s : token.to_s
          !word.empty? && word.match?(/\A\p{P}+\z/)
        end

        def symbolize(constraint)
          constraint.each_with_object({}) do |(k, v), acc|
            acc[k.to_sym] = v
          end
        end

        # Build the error hash from consumed tokens.
        def build_error(window, rule, tagged)
          target = window.find { |t| t[:word].to_s != "" } || window.first
          start_index = window.first[:index] || tagged.index(window.first) || 0
          {
            type: rule.category,
            rule_id: rule.id,
            start_index: start_index,
            end_index: start_index + window.length - 1,
            target_word: target[:word],
            tokens: window.map { |t| t[:word] },
            message: interpolate(rule.message, window),
            suggestions: rule.suggestions_for(window)
          }
        end

        def interpolate(message, window)
          return message if message.nil?

          message.gsub(/\{\{(\d+)\}\}/) { window[Regexp.last_match(1).to_i]&.fetch(:word, "").to_s }
        end
      end
    end
  end
end
