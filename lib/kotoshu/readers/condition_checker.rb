# frozen_string_literal: true

module Kotoshu
  module Readers
    # Base class for checking affix conditions.
    #
    # Hunspell affix rules specify conditions that the stem must match
    # before an affix can be applied. Different scripts may have different
    # interpretations of these conditions.
    #
    # @example Latin script condition checking
    #   checker = LatinScriptConditionChecker.compile('[^y]')
    #   checker.matches?('try')  # => true (doesn't end with 'y')
    #   checker.matches?('fly')  # => false (ends with 'y')
    #
    # @abstract Subclasses must implement the matches? method
    class ConditionChecker
      # Compile a condition string into a checker.
      #
      # @param condition [String] The condition string from .aff file
      # @param script [Symbol] The script type (:latin, :arabic, :hebrew, etc.)
      # @return [ConditionChecker] A checker instance
      def self.compile(condition, script: :latin)
        case script
        when :latin
          LatinScriptConditionChecker.compile(condition)
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
      def matches?(stem)
        true
      end
    end

    # Condition checker for Latin-script dictionaries.
    #
    # Handles Hunspell condition syntax for Latin scripts:
    # - '.' matches any stem
    # - 'y' or 'abc' (single char or string) matches stems ending with that string
    # - '[abc]' matches stems ending with 'a', 'b', or 'c'
    # - '[^y]' matches stems NOT ending with 'y'
    # - '[0-9]' matches stems ending with a digit
    # - '[aeiou]y' matches stems ending with vowel + 'y' (multi-char pattern)
    # - '[^aeiou]y' matches stems ending with consonant + 'y' (multi-char pattern)
    #
    # This is NOT suitable for RTL scripts or CJK languages.
    class LatinScriptConditionChecker < ConditionChecker
      attr_reader :pattern, :condition, :type

      # Compile a condition string.
      #
      # @param condition [String] The condition string (e.g., '[^y]', '[abc]', 'y', '.', '[aeiou]y')
      # @return [LatinScriptConditionChecker] A checker instance
      def self.compile(condition)
        return new(condition: nil, type: :any) if condition == '.'

        # Check if it's a bracket expression: [abc] or [^y] or [aeiou]y or [^aeiou]y
        # Note: [aeiou]y means "ends with vowel + y", not "ends with one of [aeiou]y"
        if condition =~ /^\[([^\]]+)\]/
          content = $1
          negated = content.start_with?('^')

          # Check if this is a multi-char pattern like [aeiou]y or [^aeiou]y
          # These should be used as regex patterns directly
          if content.length > 1
            # For multi-char patterns, use the whole condition as a regex
            new(condition: condition, type: :regex)
          elsif negated
            # Single character negation: [^x]
            chars = content[1..]
            new(condition: chars, type: :not_ends_with)
          else
            # Single character set: [x]
            new(condition: content, type: :ends_with_any)
          end
        else
          # Bare character or string - matches stems ENDING with this string
          new(condition: condition, type: :ends_with)
        end
      end

      def initialize(condition:, type:)
        @condition = condition
        @type = type
        @regex_pattern = compile_regex if type == :regex
      end

      # Compile a regex pattern for multi-character conditions.
      #
      # @return [Regexp, nil] Compiled regex or nil
      def compile_regex
        return nil unless @condition

        # Convert Hunspell condition to Ruby regex
        # [^aeiou]y -> /[^aeiou]y$/
        # [aeiou]y -> /[aeiou]y$/
        Regexp.new(@condition + '$')
      end

      # Check if the stem matches the condition.
      #
      # @param stem [String] The stem to check
      # @return [Boolean] True if the stem matches
      def matches?(stem)
        case @type
        when :any
          true
        when :ends_with
          stem.end_with?(@condition)
        when :ends_with_any
          @condition.chars.any? { |char| stem.end_with?(char) }
        when :not_ends_with
          # Check that stem doesn't end with ANY of the characters in the condition
          @condition.chars.none? { |char| stem.end_with?(char) }
        when :regex
          @regex_pattern.match?(stem)
        when :equals
          stem == @condition
        else
          false
        end
      end
    end
  end
end
