# frozen_string_literal: true

module Kotoshu
  module Algorithms
    # Soundex phonetic coding.
    #
    # Soundex is a phonetic algorithm developed by Robert C. Russell
    # and Margaret King Odell in the early 1900s. A word maps to a
    # four-character code (letter + 3 digits); words that sound alike
    # share a code, which is what {Suggestions::Strategies::PhoneticStrategy}
    # matches on.
    #
    # Coding rules (the gem's exact semantics — first letter verbatim,
    # H/W never reset the previous code, non-ASCII stripped after
    # upcase, letter-less words code to the empty string):
    #
    # - The first letter is kept verbatim and never coded.
    # - B/P/F/V code 1, C/S/K/G/J/Q/X/Z code 2, D/T code 3, L codes 4,
    #   M/N code 5, R codes 6; vowels and H/W code 0 (skipped).
    #   H and W do NOT reset the previous code; every other coded 0
    #   letter does.
    # - Adjacent letters sharing a code collapse to one digit.
    # - The code is truncated to and zero-padded to exactly 4 chars.
    #
    # @example
    #   Soundex.code("Robert")   # => "R163"
    #   Soundex.code("Rupert")   # => "R163"
    #   Soundex.code("Ashcraft") # => "A261"
    #   Soundex.code("é")        # => "" (no A-Z letters remain)
    module Soundex
      module_function

      # Calculate the Soundex code for a word.
      #
      # @param word [String, nil] The word
      # @return [String] The Soundex code (letter + 3 digits), or ""
      #   when the word has no A-Z letters
      def code(word)
        return "" if word.nil? || word.empty?

        letters = word.upcase.gsub(/[^A-Z]/, "")
        return "" if letters.empty?

        # Keep first letter. The code is built into one mutable
        # buffer (`<<`) instead of `code += digit`, which allocated
        # a fresh String per encoded letter — the phonetic sweep
        # pays this once per dictionary word.
        code = +letters[0]

        prev_code = encode(code)
        i = 1
        length = letters.length

        while code.length < 4 && i < length
          encoded = encode(letters[i])

          # Add code if different from previous (ignore h and w)
          code << encoded if encoded != "0" && encoded != prev_code

          prev_code = encoded if encoded != "0"
          i += 1
        end

        # Pad with zeros if needed
        code.ljust(4, "0")[0...4]
      end

      # Soundex encoding table.
      #
      # @param char [String] The character
      # @return [String] The encoded digit or "0" for no code
      def encode(char)
        case char.upcase
        when "B", "P", "F", "V"
          "1"
        when "C", "S", "K", "G", "J", "Q", "X", "Z"
          "2"
        when "D", "T"
          "3"
        when "L"
          "4"
        when "M", "N"
          "5"
        when "R"
          "6"
        else
          "0"
        end
      end
    end
  end
end
