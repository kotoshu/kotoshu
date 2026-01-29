# frozen_string_literal: true

module Kotoshu
  module Models
    # Affix rule model for Hunspell-style affix processing.
    #
    # Affix rules define how prefixes and suffixes can be added or removed
    # from words to generate morphological variants.
    #
    # This is a value object that represents a single affix rule.
    #
    # @note This class is immutable and frozen on initialization.
    #
    # @example Creating a prefix rule
    #   rule = Models::AffixRule.new(
    #     type: :prefix,
    #     flag: "A",
    #     strip: "",
    #     add: "re",
    #     condition: "."
    #   )
    #   rule.prefix?   # => true
    #   rule.suffix?   # => false
    class AffixRule
      # @return [Symbol] The affix type (:prefix or :suffix)
      attr_reader :type

      # @return [String] The flag character identifying this rule
      attr_reader :flag

      # @return [String] Characters to strip from the word
      attr_reader :strip

      # @return [String] Characters to add to the word
      attr_reader :add

      # @return [String, Regexp] Condition for applying this rule
      attr_reader :condition

      # @return [Boolean] Whether this is a cross-product rule
      attr_reader :cross_product

      # Affix rule types.
      TYPES = {
        prefix: "PFX",
        suffix: "SFX"
      }.freeze

      # Create a new AffixRule.
      #
      # @param type [Symbol] The affix type (:prefix or :suffix)
      # @param flag [String] The flag character
      # @param strip [String] Characters to strip
      # @param add [String] Characters to add
      # @param condition [String, Regexp] Condition for applying
      # @param cross_product [Boolean] Whether this is cross-product
      def initialize(type:, flag:, strip:, add:, condition: ".", cross_product: false)
        raise ArgumentError, "Invalid type: #{type}" unless %i[prefix suffix].include?(type)
        raise ArgumentError, "Flag cannot be empty" if flag.nil? || flag.empty?

        @type = type
        @flag = flag.dup.freeze
        @strip = strip.dup.freeze
        @add = add.dup.freeze
        @condition = condition.is_a?(Regexp) ? condition : compile_condition(condition)
        @cross_product = cross_product

        freeze
      end

      # Check if this is a prefix rule.
      #
      # @return [Boolean] True if prefix
      def prefix?
        @type == :prefix
      end

      # Check if this is a suffix rule.
      #
      # @return [Boolean] True if suffix
      def suffix?
        @type == :suffix
      end

      # Check if this rule can be applied to a word.
      #
      # @param word [String] The word to check
      # @return [Boolean] True if the rule applies
      def applies_to?(word)
        return false if word.nil? || word.empty?

        word.match?(@condition)
      end

      # Apply this rule to a word.
      #
      # @param word [String] The word to modify
      # @return [String, nil] The modified word, or nil if rule doesn't apply
      def apply(word)
        return nil unless applies_to?(word)

        result = if prefix?
                   # Strip from beginning, add prefix
                   word.start_with?(@strip) ? @add + word[@strip.length..] : nil
                 else
                   # Strip from end, add suffix
                   word.end_with?(@strip) ? word[0...-@strip.length] + @add : nil
                 end

        result
      end

      # Remove this affix from a word (reverse operation).
      #
      # @param word [String] The word to modify
      # @return [String, nil] The stripped word, or nil if affix doesn't match
      def remove(word)
        return nil unless applies_to?(word)

        result = if prefix?
                   # Remove prefix if it matches
                   word.start_with?(@add) ? @strip + word[@add.length..] : nil
                 else
                   # Remove suffix if it matches
                   word.end_with?(@add) ? word[0...-@add.length] + @strip : nil
                 end

        result
      end

      # Get the Hunspell representation.
      #
      # @return [String] The affix line for Hunspell format
      def to_hunspell
        type_code = TYPES[@type]
        cross = @cross_product ? "Y" : "N"
        "#{type_code} #{@flag} #{cross} #{@strip.length == 0 ? "0" : @strip} " \
        "#{@add} #{@condition.is_a?(Regexp) ? condition_to_s : @condition}"
      end

      # Convert to hash.
      #
      # @return [Hash] Hash representation
      def to_h
        {
          type: @type,
          flag: @flag,
          strip: @strip,
          add: @add,
          condition: @condition.is_a?(Regexp) ? @condition.source : @condition,
          cross_product: @cross_product
        }
      end

      # Check equality based on all attributes.
      #
      # @param other [AffixRule] The other rule
      # @return [Boolean] True if equal
      def ==(other)
        return false unless other.is_a?(AffixRule)
        @type == other.type &&
          @flag == other.flag &&
          @strip == other.strip &&
          @add == other.add &&
          @condition == other.condition &&
          @cross_product == other.cross_product
      end
      alias eql? ==

      # Hash based on all attributes.
      #
      # @return [Integer] Hash code
      def hash
        [@type, @flag, @strip, @add, @cross_product].hash
      end

      # Compare rules by flag.
      #
      # @param other [AffixRule] The other rule
      # @return [Integer] Comparison result
      def <=>(other)
        return nil unless other.is_a?(AffixRule)
        @flag <=> other.flag
      end

      private

      # Compile condition string to regex.
      #
      # @param condition [String] The condition string
      # @return [Regexp] The compiled regex
      def compile_condition(condition)
        return // if condition == "."

        # Hunspell uses '.' for match-all, '[...]' for character classes
        # and '^[...]' for negated classes. Convert to Ruby regex.
        regex_str = condition.dup

        # Convert [...] to Ruby character class
        regex_str = regex_str.gsub(/\[([^\]]+)\]/, "(?:\\1)")

        # Convert ^[...] to negative lookahead
        # Convert ^ to negative lookahead for single character
        regex_str = regex_str.gsub("\\^(\\w)", "(?!\\1).")

        # Anchor to end for suffix, beginning for prefix
        if @type == :suffix
          Regexp.new("#{regex_str}\\$")
        else
          Regexp.new("\\^#{regex_str}")
        end
      end

      # Convert regex condition back to string.
      #
      # @return [String] The condition string
      def condition_to_s
        source = @condition.source

        # Remove anchors
        source = source.gsub("\\^", "").gsub("\\$", "")

        # Convert negative lookaheads back
        source = source.gsub("\\(\\?\\!([^)]+)\\)\\.", "^\\1")

        # Convert non-capturing groups back
        source = source.gsub("\\(\\?:", "[").gsub("\\)", "]")

        source
      end

      # Create an affix rule from a Hunspell affix line.
      #
      # @param line [String] The affix line
      # @param type [Symbol] The rule type (:prefix or :suffix)
      # @return [AffixRule] New affix rule
      #
      # @example Parsing a Hunspell prefix rule
      #   AffixRule.from_hunspell("PFX A Y 1 re .", :prefix)
      #
      # @example Parsing a Hunspell suffix rule
      #   AffixRule.from_hunspell("SFX V N 2 ive e", :suffix)
      def self.from_hunspell(line, type)
        parts = line.split
        return nil if parts.length < 5

        flag = parts[1]
        cross_product = parts[2] == "Y"
        strip = parts[3] == "0" ? "" : parts[3]
        add = parts[4]
        condition = parts[5] || "."

        new(
          type: type,
          flag: flag,
          strip: strip,
          add: add,
          condition: condition,
          cross_product: cross_product
        )
      end
    end
  end
end
