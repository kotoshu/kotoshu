# frozen_string_literal: true

module Kotoshu
  module Readers
    # Affix data class for Hunspell affix rules.
    #
    # This class represents a prefix or suffix affix rule.
    #
    # @attr flag [String] The flag character identifying this rule
    # @attr crossproduct [Boolean] Whether this is a cross-product rule
    # @attr strip [String] Characters to strip from the word
    # @attr add [String] Characters to add to the word
    # @attr condition [String] Condition for applying this rule
    # @attr flags [Set<String>] Additional flags
    #
    # @example Creating a suffix affix
    #   Affix.new(
    #     type: :suffix,
    #     flag: 'H',
    #     crossproduct: false,
    #     strip: 'y',
    #     add: 'ieth',
    #     condition: 'y',
    #     flags: Set.new
    #   )
    class Affix
      attr_reader :type, :flag, :crossproduct, :strip, :add, :condition, :flags

      # Create a new affix.
      #
      # @param type [Symbol] :prefix or :suffix
      # @param flag [String] Flag character
      # @param crossproduct [Boolean] Whether cross-product
      # @param strip [String] Characters to strip
      # @param add [String] Characters to add
      # @param condition [String] Condition regex
      # @param flags [Set<String>] Additional flags
      def initialize(type:, flag:, crossproduct:, strip:, add:, condition:, flags: Set.new)
        @type = type
        @flag = flag
        @crossproduct = crossproduct
        @strip = strip
        @add = add
        @condition = condition
        @flags = flags
      end

      # Check if this is a prefix.
      #
      # @return [Boolean] True if prefix
      def prefix?
        @type == :prefix
      end

      # Check if this is a suffix.
      #
      # @return [Boolean] True if suffix
      def suffix?
        @type == :suffix
      end

      # String representation.
      #
      # @return [String] String representation
      def to_s
        type_str = prefix? ? 'Prefix' : 'Suffix'
        "#{type_str}(#{@add}: #{@flag}#{'×' if @crossproduct}/#{@flags.to_a.join(',')}, on #{condition})"
      end

      # Inspect string.
      #
      # @return [String] Inspect string
      def inspect
        to_s
      end
    end

    # Break pattern for word splitting.
    #
    # @attr pattern [String] The break pattern
    # @attr matcher [Regexp] Compiled matcher for the pattern
    class BreakPattern
      attr_reader :pattern, :matcher

      # Create a new break pattern.
      #
      # @param pattern [String] The pattern string
      def initialize(pattern)
        @pattern = pattern
        # Special chars like #, -, * should be escaped, but ^ and $ should be treated as pattern anchors
        regex_pattern = Regexp.escape(pattern).gsub('\\^', '^').gsub('\\$', '$')
        @matcher = if regex_pattern.start_with?('^') || regex_pattern.end_with?('$')
                     Regexp.new("(#{regex_pattern})")
                   else
                     Regexp.new(".(#{regex_pattern}).")
                   end
      end
    end

    # Ignore characters for lookup/suggest.
    #
    # @attr chars [String] Characters to ignore
    # @attr translation_table [Hash] Translation table for removal
    class Ignore
      attr_reader :chars, :translation_table

      # Create a new ignore set.
      #
      # @param chars [String] Characters to ignore
      def initialize(chars)
        @chars = chars
        # Create translation table that removes these characters
        @translation_table = chars.each_char.each_with_index.to_h
      end

      # Remove ignored characters from string.
      #
      # @param str [String] Input string
      # @return [String] String with ignored chars removed
      def remove(str)
        str.chars.reject { |c| @translation_table.key?(c) }.join
      end
    end

    # Replacement pattern for suggestions.
    #
    # @attr pattern [String] The pattern to match
    # @attr replacement [String] The replacement string
    # @attr matcher [Regexp] Compiled matcher for the pattern
    class RepPattern
      attr_reader :pattern, :replacement, :matcher

      # Create a new replacement pattern.
      #
      # @param pattern [String] The pattern string
      # @param replacement [String] The replacement string
      def initialize(pattern, replacement)
        @pattern = pattern
        @replacement = replacement
        @matcher = Regexp.new(pattern)
      end
    end

    # Conversion table for ICONV/OCONV.
    #
    # @attr pairs [Array<Array<String>>] Array of [pattern, replacement] pairs
    class ConvTable
      attr_reader :pairs

      # Create a new conversion table.
      #
      # @param pairs [Array<Array<String>>] Array of [pattern, replacement] pairs
      def initialize(pairs)
        @pairs = pairs
        @table = pairs.map { |pat1, pat2| compile_row(pat1, pat2) }.sort_by { |search, _| search.length }
      end

      # Apply conversions to word.
      #
      # Note: Python's `re.match(string, pos)` anchors at pos, but Ruby's
      # `Regexp#match?` searches from pos onward. We must check that the
      # match actually begins at pos, otherwise short conversions fire on
      # later positions in the word and produce nonsense like "ÉÉÉÉ" for
      # "bébé".
      #
      # Spylls uses Python's stable `sorted(..., key=lambda r: len(r[0]))`
      # which preserves declaration order for ties. Ruby's `sort_by` is
      # unstable, so we add the table index as a secondary key to mirror
      # Spylls. Without this, Nepali's ICONV reorders the `ZWNJ$ → ZWNJ`
      # no-op rule behind `ZWNJ → U+FFF0`, causing the trailing-ZWNJ word
      # to be normalized to U+FFF0 (and then dropped by IGNORE) so it
      # matches the dictionary.
      #
      # @param word [String] Input word
      # @return [String] Converted word
      def call(word)
        pos = 0
        result = ''

        while pos < word.length
          matches = @table.each_with_index.filter_map do |(search, pattern, _), idx|
            m = pattern.match(word, pos)
            next unless m && m.begin(0) == pos

            [search, idx]
          end.sort_by { |s, idx| [-s.length, idx] }

          if matches.any?
            search, idx = matches.first
            _, _, replacement = @table[idx]
            result += replacement
            pos += search.length
          else
            result += word[pos]
            pos += 1
          end
        end

        result
      end

      private

      def compile_row(pat1, pat2)
        pat1_clean = pat1.gsub('_', '')
        pat1_re = pat1_clean.dup
        pat1_re = "^#{pat1_re}" if pat1.start_with?('_')
        pat1_re = "#{pat1_re}$" if pat1.end_with?('_')

        [pat1_clean, Regexp.new(pat1_re), pat2.gsub('_', ' ')]
      end
    end

    # Compound rule pattern.
    #
    # @attr text [String] The rule text
    # @attr flags [Set<String>] Flags in this rule
    # @attr re [Regexp] Compiled regex for full matching
    # @attr partial_re [Regexp] Compiled regex for prefix matching
    class CompoundRule
      attr_reader :text, :flags, :re, :partial_re

      # Create a new compound rule.
      #
      # @param text [String] The rule text (e.g., "A*B?CD")
      def initialize(text)
        @text = text
        # Parse flags from rule text
        if text.include?('(')
          @flags = text.scan(/\((.+?)\)/).flatten.to_set
          parts = text.scan(/\([^*?]+?\)[*?]?/)
        else
          @flags = text.gsub(/[*?]/, '').chars.to_set
          # Handle ) as a flag character (used in sv dictionaries)
          parts = text.gsub(/(?<=[^*?])\)/, '\\)').gsub(/([^*?])/, '\1')
            .scan(/[^*?][*?]?/)
        end

        # Full-match regex: the entire flag-combination string must match.
        @re = Regexp.new("\\A#{parts.join}\\z")

        # Partial-match regex: any prefix of the rule is accepted. Built
        # by making each trailing part optional, from the end backwards:
        # parts ["A","B","C"] → "A(B(C?)?)?" which matches "A", "AB", "ABC".
        @partial_re = if parts.empty?
                        Regexp.new('\\A\\z')
                      else
                        Regexp.new("\\A#{build_partial(parts)}\\z")
                      end
      end

      # Check if flag sets fully match this rule.
      #
      # @param flag_sets [Array<Set<String>>] Array of flag sets
      # @return [Boolean] True if the entire flag-combination matches
      def fullmatch(flag_sets)
        relevant_flags = flag_sets.map { |f| @flags.intersection(f).to_a }
        return false if relevant_flags.empty? || relevant_flags.any?(&:empty?)

        relevant_flags[0].product(*relevant_flags[1..]).any? do |fc|
          @re.match?(fc.join)
        end
      end

      # Check if flag sets form a valid prefix of this rule.
      #
      # Used during compounds_by_rules recursion to prune branches that
      # can never lead to a full match.
      #
      # @param flag_sets [Array<Set<String>>] Array of flag sets
      # @return [Boolean] True if a prefix of the rule matches
      def partial_match(flag_sets)
        relevant_flags = flag_sets.map { |f| @flags.intersection(f).to_a }
        return false if relevant_flags.empty? || relevant_flags.any?(&:empty?)

        relevant_flags[0].product(*relevant_flags[1..]).any? do |fc|
          @partial_re.match?(fc.join)
        end
      end

      private

      # Build a regex where each trailing part becomes optional.
      #
      # ["A", "B", "C"] → "A(B(C?)?)?"
      def build_partial(parts)
        parts.reverse.reduce(nil) do |inner, part|
          inner ? "#{part}(#{inner})?" : "#{part}?"
        end.gsub('??', '?')
      end
    end

    # Compound pattern for checking compound words.
    #
    # @attr left [String] Left side pattern
    # @attr right [String] Right side pattern
    # @attr replacement [String, nil] Optional replacement
    class CompoundPattern
      attr_reader :left, :right, :replacement, :left_stem, :left_flag, :right_stem, :right_flag,
                  :left_no_affix, :right_no_affix

      # Create a new compound pattern.
      #
      # @param left [String] Left side pattern
      # @param right [String] Right side pattern
      # @param replacement [String, nil] Optional replacement
      def initialize(left, right, replacement = nil)
        @left = left
        @right = right
        @replacement = replacement

        # Parse left side. The separator from partition('/') distinguishes
        # "no slash" (no flag specified → nil, so the matcher skips the
        # flag check) from a slash with an empty flag.
        @left_stem, sep, @left_flag = left.partition('/')
        @left_flag = nil if sep.empty?
        @left_stem = '' if @left_stem == '0'
        @left_no_affix = @left_stem.empty? && left.start_with?('0')

        # Parse right side
        @right_stem, sep, @right_flag = right.partition('/')
        @right_flag = nil if sep.empty?
        @right_stem = '' if @right_stem == '0'
        @right_no_affix = @right_stem.empty? && right.start_with?('0')
      end

      # Check if this pattern matches the given left and right parts.
      #
      # @param left_part [AffixForm] Left part with stem, flags, is_base?
      # @param right_part [AffixForm] Right part with stem, flags, is_base?
      # @return [Boolean] True if matches
      def match?(left_part, right_part)
        return false unless left_part.stem.end_with?(@left_stem)
        return false unless right_part.stem.start_with?(@right_stem)
        return false if @left_no_affix && left_part.is_base?
        return false if @right_no_affix && right_part.is_base?
        return false if @left_flag && !left_part.flags.include?(@left_flag)
        return false if @right_flag && !right_part.flags.include?(@right_flag)

        true
      end
    end

    # Phonetic table for PHONE directive.
    #
    # Domain object wrapping the parsed PHONE rules. Rules are indexed by
    # their first letter so the metaphone algorithm can look up candidates
    # in O(1) per character position.
    #
    # @attr rules [Hash<String, Array<Rule>>] First-char → rule list
    class PhonetTable
      attr_reader :table, :rules

      # Pattern for matching phonetic rules.
      # Updated to support extended ASCII (Latin-1) characters like É, À, etc.
      RULE_PATTERN = /^(?<letters>[[:alpha:]]+)(\((?<optional>[[:alpha:]]+)\))?(?<lookahead>-+)?(?<flags>[\^$<]*)(?<priority>\d)?$/

      # Rule class for phonetic transformations.
      #
      # @attr search [Regexp] Search pattern
      # @attr replacement [String] Replacement string
      # @attr start [Boolean] Match at start
      # @attr end [Boolean] Match at end
      # @attr priority [Integer] Rule priority
      # @attr followup [Boolean] Follow-up rule
      Rule = Struct.new(:search, :replacement, :start, :end, :priority, :followup, keyword_init: true) do
        # Check if rule matches at position.
        #
        # @param word [String] Word to check
        # @param pos [Integer] Position in word
        # @return [Boolean] True if matches
        def match?(word, pos)
          return false if @start && pos > 0
          return @search.match?(word, pos) if @end

          @search.match?(word, pos)
        end
      end

      # Create a new phonetic table.
      #
      # @param table [Array<Array<String>>] Array of [pattern, replacement] pairs
      def initialize(table)
        @table = table
        @rules = Hash.new { |h, k| h[k] = [] }

        table.each do |search, replacement|
          @rules[search[0]] << parse_rule(search, replacement)
        end
      end

      # Whether this table contains any rules.
      #
      # @return [Boolean]
      def empty?
        @table.empty?
      end

      # Parse a phonetic rule.
      #
      # @param search [String] Search pattern
      # @param replacement [String] Replacement string ("_" means silent/empty,
      #   per aspell's phonetic convention which Hunspell inherited)
      # @return [Rule] Parsed rule
      def parse_rule(search, replacement)
        match = RULE_PATTERN.match(search)
        raise ArgumentError, "Not a proper rule: #{search.inspect}" unless match

        text = match['letters'].chars
        text << "[#{match['optional']}]" if match['optional']

        if match['lookahead']
          lookahead_len = match['lookahead'].length
          regex = text[0...-lookahead_len].join + "(?=#{text[-lookahead_len..].join})"
        else
          regex = text.join
        end

        # Aspell/Hunspell phonetic convention: "_" in the replacement column
        # means "produce nothing" (silent). Normalizing here means downstream
        # code can append the replacement verbatim.
        normalized_replacement = replacement == '_' ? '' : replacement

        Rule.new(
          search: Regexp.new(regex),
          replacement: normalized_replacement,
          start: match['flags']&.include?('^'),
          end: match['flags']&.include?('$'),
          priority: match['priority']&.to_i || 5,
          followup: !match['lookahead'].nil?
        )
      end
    end
  end
end
