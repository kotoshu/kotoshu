# frozen_string_literal: true

module Kotoshu
  module Algorithms
    # Word permutation algorithms for generating spelling variations.
    #
    # Ported from Spylls (Python) permutations.py
    #
    # These functions generate various word edits that are used by the
    # suggestion system to find possible corrections for misspelled words.
    #
    # Method names match Hunspell's suggest.cxx to maintain compatibility.
    module Permutations
      MAX_CHAR_DISTANCE = 4

      module_function

      # Uses REP table (typical misspellings) to replace patterns in word.
      #
      # If the pattern's replacement contains "_", it means replacing to " "
      # and yielding two different hypotheses:
      #   1. It was one (dictionary) word "foo bar" (checked as such)
      #   2. It was words ["foo", "bar"] (checked separately)
      #
      # @param word [String] The word to process
      # @param reptable [Array<Hash>] Array of replacement pattern hashes with :regexp and :replacement
      # @yield [String, Array<String>] Each suggestion (string or array of words)
      #
      # @example
      #   Kotoshu::Algorithms::Permutations.replchars("acces", [{regexp: /ac/, replacement: "ex"}]) do |sug|
      #     puts sug
      #   end
      def replchars(word, reptable)
        return if word.length < 2 || reptable.nil? || reptable.empty?

        reptable.each do |pattern|
          str = word.to_s
          pos = 0

          while (match_data = pattern[:regexp].match(str, pos))
            suggestion = str[0...match_data.begin(0)] +
                         pattern[:replacement].gsub('_', ' ') +
                         str[match_data.end(0)..]

            yield suggestion
            yield suggestion.split(' ') if suggestion.include?(' ')

            # Move past this match to find next occurrence
            pos = match_data.end(0)
            break if pos >= str.length
          end
        end
      end

      # Uses MAP table (sets of potentially similar chars) and tries to replace them recursively.
      #
      # Example: Assuming MAP has entry "aáã", and we have misspelling "anarchia":
      #   mapchars will produce: "ánarchia", "ánárchia", "ánárchiá", etc.
      #
      # @param word [String] The word to process
      # @param maptable [Array<Set<String>>] Array of character sets for mapping
      # @yield [String] Each variant with mapped characters
      #
      # @example
      #   Kotoshu::Algorithms::Permutations.mapchars("anarchia", [Set.new(['a', 'á', 'ã'])]) do |variant|
      #     puts variant
      #   end
      def mapchars(word, maptable)
        return if word.length < 2 || maptable.nil? || maptable.empty?

        mapchars_internal(word, 0, maptable) { |variant| yield variant }
      end

      # Produces permutations with adjacent chars swapped.
      #
      # For short (4 or 5 letters) words also produces double swaps: ahev -> have
      #
      # @param word [String] The word to process
      # @yield [String] Each swap variant
      def swapchar(word)
        return if word.length < 2

        chars = word.chars
        (0...chars.length - 1).each do |i|
          swapped = chars[0...i] + [chars[i + 1], chars[i]] + chars[(i + 2)..]
          yield swapped.join
        end

        # Try double swaps for short words
        # ahev -> have, owudl -> would
        if [4, 5].include?(word.length)
          yield word[1] + word[0] + (word.length == 5 ? word[2] : '') + word[-1] + word[-2]
          if word.length == 5
            yield word[0] + word[2] + word[1] + word[-1] + word[-2]
          end
        end
      end

      # Produces permutations with non-adjacent chars swapped (up to 4 chars distance).
      #
      # @param word [String] The word to process
      # @yield [String] Each long swap variant
      def longswapchar(word)
        chars = word.chars
        (0...chars.length - 2).each do |first|
          ((first + 2)...[first + MAX_CHAR_DISTANCE, chars.length].min).each do |second|
            swapped = chars[0...first] +
                     [chars[second]] +
                     chars[(first + 1)...second] +
                     [chars[first]] +
                     chars[(second + 1)..]
            yield swapped.join
          end
        end
      end

      # Produces permutations with chars replaced by adjacent chars on keyboard layout
      # ("vat -> cat") or downcased (if it was accidental uppercase).
      #
      # @param word [String] The word to process
      # @param layout [String] Keyboard layout string (KEY from aff file)
      # @yield [String] Each variant with replaced chars
      def badcharkey(word, layout)
        chars = word.chars
        chars.each_with_index do |c, i|
          before = word[0...i]
          after = word[(i + 1)..]

          # Try uppercasing if not already uppercase
          unless c == c.upcase
            yield before + c.upcase + after.to_s
          end

          next if layout.nil? || layout.empty?

          # Try adjacent keys on keyboard
          pos = layout.index(c)
          next unless pos

          while pos
            if pos.positive? && layout[pos - 1] != '|'
              yield before + layout[pos - 1] + after.to_s
            end
            if pos + 1 < layout.length && layout[pos + 1] != '|'
              yield before + layout[pos + 1] + after.to_s
            end
            pos = layout.index(c, pos + 1)
          end
        end
      end

      # Produces permutations with one char removed in all possible positions.
      #
      # @param word [String] The word to process
      # @yield [String] Each variant with one char removed
      def extrachar(word)
        return if word.length < 2

        word.length.times do |i|
          yield word[0...i] + word[(i + 1)..]
        end
      end

      # Produces permutations with one char inserted in all possible positions.
      #
      # List of chars is taken from TRY string -- if absent, tries nothing.
      # Chars are expected to be sorted in order of usage in language.
      #
      # @param word [String] The word to process
      # @param trystring [String] Characters to try inserting (from aff TRY directive)
      # @yield [String] Each variant with one char inserted
      def forgotchar(word, trystring)
        return if trystring.nil? || trystring.empty?

        trystring.each_char do |c|
          (0..word.length).each do |i|
            yield word[0...i] + c + word[i..]
          end
        end
      end

      # Produces permutations with one character moved by 2, 3 or 4 places forward or backward
      # (not 1, because adjacent swaps are already handled by swapchar).
      #
      # @param word [String] The word to process
      # @yield [String] Each variant with moved character
      def movechar(word)
        return if word.length < 2

        chars = word.chars

        # Move characters forward
        chars.each_with_index do |char, frompos|
          ((frompos + 3)...[chars.length, frompos + MAX_CHAR_DISTANCE + 1].min).each do |topos|
            moved = chars[0...frompos] + chars[(frompos + 1)...topos] + [char] + chars[topos..]
            yield moved.join
          end
        end

        # Move characters backward
        (chars.length - 1).downto(0) do |frompos|
          [[0, frompos - MAX_CHAR_DISTANCE + 1].max, frompos - 1].min.downto(0) do |topos|
            moved = chars[0...topos] + [chars[frompos]] + chars[topos...frompos] + chars[(frompos + 1)..]
            yield moved.join
          end
        end
      end

      # Produces permutations with chars replaced by chars in TRY set.
      #
      # @param word [String] The word to process
      # @param trystring [String] Characters to try replacing with (from aff TRY directive)
      # @yield [String] Each variant with replaced char
      def badchar(word, trystring)
        return if trystring.nil? || trystring.empty?

        trystring.each_char do |c|
          (word.length - 1).downto(0) do |i|
            next if word[i] == c

            yield word[0...i] + c + word[(i + 1)..]
          end
        end
      end

      # Produces permutations with accidental two-letter-doubling fixed.
      # Example: "vacacation" -> "vacation"
      #
      # @param word [String] The word to process
      # @yield [String] Each variant with fixed doubling
      def doubletwochars(word)
        return if word.length < 5

        (2...word.length).each do |i|
          # Check if word[i-2] == word[i] and word[i-3] == word[i-1]
          # Example: vacacation -> "ca" at positions 3-4, so "vac" at 2-4
          if word[i - 2] == word[i] && word[i - 3] == word[i - 1]
            yield word[0...(i - 1)] + word[(i + 1)..]
          end
        end
      end

      # Produces permutations of splitting word into two in all possible positions.
      #
      # @param word [String] The word to process
      # @yield [Array<String>] Each two-word split
      def twowords(word)
        (1...word.length).each do |i|
          yield [word[0...i], word[i..]]
        end
      end

      # Internal recursive method for mapchars.
      #
      # @param word [String] Current word state
      # @param start [Integer] Starting position for search
      # @param maptable [Array<Set<String>>] Character mapping table
      # @yield [String] Each variant
      def mapchars_internal(word, start, maptable)
        return if start >= word.length

        maptable.each do |options|
          options.each do |option|
            pos = word.index(option, start)
            next unless pos

            options.each do |other|
              next if other == option

              replaced = word[0...pos] + other + word[(pos + option.length)..]
              yield replaced

              # Recursively continue from this position
              mapchars_internal(replaced, pos + 1, maptable) { |variant| yield variant }
            end
          end
        end
      end

      private_class_method :mapchars_internal
    end
  end
end
