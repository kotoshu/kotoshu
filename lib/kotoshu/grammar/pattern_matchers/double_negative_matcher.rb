# frozen_string_literal: true

module Kotoshu
  module Grammar
    module PatternMatchers
      # Matcher for double negative rules.
      #
      # Detects when multiple negative words appear within a certain
      # distance, with support for declared exception phrases. The
      # canonical exception is the "not only...but also" correlative
      # conjunction: both "not" and "also" are flagged as negatives,
      # but the construction is grammatical and must not fire.
      #
      # Exception phrases use the literal +...+ separator to indicate
      # arbitrary text between the prefix and suffix:
      #
      #   "not only...but also"
      #
      # means "not only" at some position, then any text, then "but
      # also". Every negative inside such a region is suppressed.
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

          regions = exception_regions(tokens, exception_phrases)

          negative_indices = tokens.each_with_index.filter_map do |token, idx|
            word = token[:token]&.downcase
            next unless negative?(word)
            next if regions.any? { |range| range.include?(idx) }

            idx
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
        def negative?(word)
          return false if word.nil? || word.empty?

          negatives = %w[not no neither nobody never nothing nowhere hardly barely scarcely]
          return true if negatives.include?(word)
          return true if word.end_with?("n't")

          false
        end

        # Locate every (start...end) region of the token stream that
        # matches one of the declared +exception_phrases+. Each phrase
        # is "<prefix>...<suffix>"; a region runs from the start of the
        # prefix match through the end of the corresponding suffix
        # match. If the suffix never matches, the region is not
        # recorded (the idiom was never closed).
        #
        # @param tokens [Array<Hash>]
        # @param exception_phrases [Array<String>]
        # @return [Array<Range>] Index ranges to suppress
        def exception_regions(tokens, exception_phrases)
          return [] if exception_phrases.empty?

          exception_phrases.flat_map do |phrase|
            phrase_regions(tokens, phrase)
          end
        end

        # Find every region for a single phrase.
        #
        # Two phrase shapes are supported:
        #
        # - "prefix...suffix" — correlative / open-ended idiom. Region
        #   runs from the start of the prefix match through the end of
        #   the next matching suffix. If the suffix never matches, the
        #   region is not recorded (idiom was never closed).
        # - "literal phrase" (no "...") — fixed n-gram. Region is the
        #   exact span of the match.
        def phrase_regions(tokens, phrase)
          if phrase.include?("...")
            split_phrase_regions(tokens, phrase)
          else
            literal_phrase_regions(tokens, phrase)
          end
        end

        # "prefix...suffix" form.
        def split_phrase_regions(tokens, phrase)
          prefix, suffix = phrase.split("...", 2)
          prefix_tokens = prefix.to_s.split.map(&:downcase)
          suffix_tokens = suffix.to_s.split.map(&:downcase)
          return [] if prefix_tokens.empty? || suffix_tokens.empty?

          regions = []
          tokens.each_index do |start_idx|
            next unless tokens_match?(tokens, start_idx, prefix_tokens)

            suffix_search_from = start_idx + prefix_tokens.length
            suffix_idx = (suffix_search_from...tokens.length).find do |i|
              tokens_match?(tokens, i, suffix_tokens)
            end
            next unless suffix_idx

            regions << (start_idx...(suffix_idx + suffix_tokens.length))
          end
          regions
        end

        # Literal n-gram form (no "...").
        def literal_phrase_regions(tokens, phrase)
          pattern = phrase.split.map(&:downcase)
          return [] if pattern.empty?

          regions = []
          tokens.each_index do |start_idx|
            next unless tokens_match?(tokens, start_idx, pattern)

            regions << (start_idx...(start_idx + pattern.length))
          end
          regions
        end

        # True if tokens[idx, idx + pattern.length] matches +pattern+
        # (case-insensitive, token-by-token).
        def tokens_match?(tokens, idx, pattern)
          return false if idx.negative?
          return false if idx + pattern.length > tokens.length

          pattern.each_with_index.all? do |word, offset|
            tokens[idx + offset][:token]&.downcase == word
          end
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
