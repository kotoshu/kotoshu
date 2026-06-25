# frozen_string_literal: true

require_relative '../layout'

module Kotoshu
  module Keyboard
    module Layouts
      # Dvorak keyboard layout
      #
      # Dvorak Simplified Keyboard layout designed for efficiency:
      # - English (en, en-US) with Dvorak layout
      #
      # Key differences from QWERTY:
      # - Vowels (AOEUIDHTNS) on home row left
      # - Most common consonants on home row right
      # - Designed to minimize finger movement
      # - ~70% of keystrokes on home row (vs ~32% for QWERTY)
      #
      # Key positions use [row, col] coordinates where:
      # - row 0: number row (`1"2>...)
      # - row 1: top row (',.<pyfg...)
      # - row 2: home row (aoeuidhtns...)
      # - row 3: bottom row (;qjkxbmwvz)
      class Dvorak < Layout
        # Key positions for Dvorak layout
        # Each key maps to [row, column] coordinates
        KEY_POSITIONS = {
          # Number row
          '`' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3], '4' => [0, 4],
          '5' => [0, 5], '6' => [0, 6], '7' => [0, 7], '8' => [0, 8], '9' => [0, 9],
          '0' => [0, 10], '[' => [0, 11], ']' => [0, 12],
          # Top row (punctuation and high-frequency consonants)
          '\'' => [1, 0], ',' => [1, 1], '.' => [1, 2], 'p' => [1, 3], 'y' => [1, 4],
          'f' => [1, 5], 'g' => [1, 6], 'c' => [1, 7], 'r' => [1, 8], 'l' => [1, 9],
          '/' => [1, 10], '=' => [1, 11],
          # Home row (vowels left, high-frequency consonants right)
          'a' => [2, 0], 'o' => [2, 1], 'e' => [2, 2], 'u' => [2, 3], 'i' => [2, 4],
          'd' => [2, 5], 'h' => [2, 6], 't' => [2, 7], 'n' => [2, 8], 's' => [2, 9],
          '-' => [2, 10],
          # Bottom row (low-frequency letters)
          ';' => [3, 0], 'q' => [3, 1], 'j' => [3, 2], 'k' => [3, 3], 'x' => [3, 4],
          'b' => [3, 5], 'm' => [3, 6], 'w' => [3, 7], 'v' => [3, 8], 'z' => [3, 9]
        }.freeze

        # Initialize Dvorak layout
        def initialize
          super(
            name: 'Dvorak',
            language_codes: %w[en en-US],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
