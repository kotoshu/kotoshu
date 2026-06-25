# frozen_string_literal: true

require_relative '../layout'

module Kotoshu
  module Keyboard
    module Layouts
      # AZERTY keyboard layout
      #
      # Standard AZERTY layout used for:
      # - French (fr, fr-FR)
      # - Belgium (be)
      #
      # Key differences from QWERTY:
      # - a and q are swapped (a/q → q/a)
      # - z and w are swapped (z/w → w/z)
      # - Number row is shifted (requires Shift for numbers)
      # - Has accent keys: é, à, ç, è, ù
      #
      # Key positions use [row, col] coordinates where:
      # - row 0: number/symbol row (²&é"'(-...)
      # - row 1: top row (azerty...)
      # - row 2: home row (qsdfg...)
      # - row 3: bottom row (wxcvb...) - note: w is here
      class AZERTY < Layout
        # Key positions for AZERTY layout
        # Each key maps to [row, column] coordinates
        KEY_POSITIONS = {
          # Top row (number/symbol row - numbers require Shift)
          '`' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3], '4' => [0, 4],
          '5' => [0, 5], '6' => [0, 6], '7' => [0, 7], '8' => [0, 8], '9' => [0, 9],
          '0' => [0, 10], ')' => [0, 11], '=' => [0, 12],
          # Top row (AZERTY - note a and q swapped, z and w swapped)
          'a' => [1, 0], 'z' => [1, 1], 'e' => [1, 2], 'r' => [1, 3], 't' => [1, 4],
          'y' => [1, 5], 'u' => [1, 6], 'i' => [1, 7], 'o' => [1, 8], 'p' => [1, 9],
          '^' => [1, 10], '$' => [1, 11],
          # Home row (QSDFG - note q is here)
          'q' => [2, 0], 's' => [2, 1], 'd' => [2, 2], 'f' => [2, 3], 'g' => [2, 4],
          'h' => [2, 5], 'j' => [2, 6], 'k' => [2, 7], 'l' => [2, 8], 'm' => [2, 9],
          'ù' => [2, 10],
          # Bottom row (WXCVB - note w is here)
          'w' => [3, 0], 'x' => [3, 1], 'c' => [3, 2], 'v' => [3, 3], 'b' => [3, 4],
          'n' => [3, 5], ',' => [3, 6], ';' => [3, 7], ':' => [3, 8], '!' => [3, 9]
        }.freeze

        # Initialize AZERTY layout
        def initialize
          super(
            name: 'AZERTY',
            language_codes: %w[fr be fr-FR],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
