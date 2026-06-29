# frozen_string_literal: true

module Kotoshu
  module Readers
    # Base class for checking affix conditions.
    #
    # Hunspell affix rules specify conditions that the stem must match
    # before an affix can be applied. Different scripts may have different
    # interpretations of these conditions.
    #
    # Conditions are anchored differently for prefixes vs suffixes:
    # - Suffix condition `y` matches stems that END with `y` (e.g. `[^y]$`)
    # - Prefix condition `ij` matches stems that START with `ij`
    #   (e.g. `^ij`)
    #
    # @example Latin script condition checking
    #   checker = LatinScriptConditionChecker.compile('[^y]', type: :suffix)
    #   checker.matches?('try')  # => true (doesn't end with 'y')
    #   checker.matches?('fly')  # => false (ends with 'y')
    #
    # @abstract Subclasses must implement the matches? method
    class ConditionChecker
      # Compile a condition string into a checker.
      #
      # @param condition [String] The condition string from .aff file
      # @param script [Symbol] The script type (:latin, :arabic, :hebrew, etc.)
      # @param type [Symbol] :suffix (anchor at end) or :prefix (anchor at start)
      # @return [ConditionChecker] A checker instance
      def self.compile(condition, script: :latin, type: :suffix)
        case script
        when :latin
          LatinScriptConditionChecker.compile(condition, type: type)
        else
          # For other scripts, create a passthrough checker
          # (condition is not applied)
          PassthroughConditionChecker.new
        end
      end

      # Check if the given stem matches this condition.
      #
      # @param stem [String] The stem to check
      # @return [Boolean] True if the stem matches
      def matches?(stem)
        raise NotImplementedError, "#{self.class} must implement #matches?"
      end
    end

    # Passthrough condition checker that always returns true.
    #
    # Used for scripts where Hunspell conditions don't apply or aren't supported.
    class PassthroughConditionChecker < ConditionChecker
      def matches?(_stem)
        true
      end
    end

    # Condition checker for Latin-script dictionaries.
    #
    # Hunspell conditions are regex-like patterns. Spylls compiles them
    # verbatim (with `-` escaped so it doesn't become a range inside an
    # unintended context) into a regex anchored at the start (for prefixes)
    # or end (for suffixes), and uses `re.search` to test.
    #
    # Examples (suffix unless noted):
    # - '.' matches any stem (regex: /.$/ finds end-of-string)
    # - 'y' matches stems ending with 'y' (regex: /y$/)
    # - '[^y]' matches stems NOT ending with 'y' (regex: /[^y]$/)
    # - '[aeiou]y' matches stems ending with vowel + 'y' (regex: /[aeiou]y$/)
    # - '.[^aeiou]y' matches stems whose last 3 chars are any-non-vowel-y
    # - 'wr.' (prefix) matches stems starting with 'wr' + any char
    #
    # This is NOT suitable for RTL scripts or CJK languages.
    class LatinScriptConditionChecker < ConditionChecker
      attr_reader :condition, :type, :anchor, :pattern

      # Compile a condition string.
      #
      # @param condition [String] The condition string (e.g., '[^y]', '[abc]', 'y', '.')
      # @param type [Symbol] :suffix (end-anchor) or :prefix (start-anchor)
      # @return [LatinScriptConditionChecker] A checker instance
      def self.compile(condition, type: :suffix)
        anchor = type == :prefix ? :start : :ending
        new(condition: condition, type: type, anchor: anchor)
      end

      def initialize(condition:, type:, anchor:)
        @condition = condition
        @type = type
        @anchor = anchor
        @pattern = compile_pattern
      end

      # Check if the stem matches the condition.
      #
      # @param stem [String] The stem to check
      # @return [Boolean] True if the stem matches
      def matches?(stem)
        return true if @condition.nil? || @condition.empty? || @condition == '.'

        @pattern.match?(stem)
      end

      private

      # Compile the condition into a Ruby Regexp.
      #
      # Mirrors Spylls: prefix → `^<condition>`, suffix → `<condition>$`,
      # with `-` escaped so it can appear literally inside the pattern.
      # The check uses `match?` (which searches), so the anchors do the
      # positional work.
      #
      # Returns a match-all regex for nil/empty conditions so the
      # constructor doesn't crash on those inputs (the #matches? method
      # already short-circuits on nil/empty/`.`).
      def compile_pattern
        return // if @condition.nil? || @condition.empty?

        escaped = @condition.gsub('-', '\\-')
        anchored = @anchor == :start ? "^#{escaped}" : "#{escaped}$"
        Regexp.new(anchored)
      end
    end
  end
end
