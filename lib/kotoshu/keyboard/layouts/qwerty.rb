# frozen_string_literal: true

require_relative '../layout'

module Kotoshu
  module Keyboard
    module Layouts
      # QWERTY keyboard layout
      #
      # Standard QWERTY layout used for:
      # - English (en, en-US, en-GB, etc.)
      # - Spanish (es)
      # - Portuguese (pt, pt-BR, pt-PT)
      # - United States (us)
      #
      # Key positions use [row, col] coordinates where:
      # - row 0: number row (`1`2`3...)
      # - row 1: top row (qwerty...)
      # - row 2: home row (asdfg...)
      # - row 3: bottom row (zxcvb...)
      class QWERTY < Layout
        # Key positions for QWERTY layout
        # Each key maps to [row, column] coordinates
        KEY_POSITIONS = {
          # Number row
          '`' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3], '4' => [0, 4],
          '5' => [0, 5], '6' => [0, 6], '7' => [0, 7], '8' => [0, 8], '9' => [0, 9],
          '0' => [0, 10], '-' => [0, 11], '=' => [0, 12],
          # Top row (QWERTY)
          'q' => [1, 0], 'w' => [1, 1], 'e' => [1, 2], 'r' => [1, 3], 't' => [1, 4],
          'y' => [1, 5], 'u' => [1, 6], 'i' => [1, 7], 'o' => [1, 8], 'p' => [1, 9],
          '[' => [1, 10], ']' => [1, 11], '\\' => [1, 12],
          # Home row (ASDFG)
          'a' => [2, 0], 's' => [2, 1], 'd' => [2, 2], 'f' => [2, 3], 'g' => [2, 4],
          'h' => [2, 5], 'j' => [2, 6], 'k' => [2, 7], 'l' => [2, 8], ';' => [2, 9],
          '\'' => [2, 10],
          # Bottom row (ZXCVB)
          'z' => [3, 0], 'x' => [3, 1], 'c' => [3, 2], 'v' => [3, 3], 'b' => [3, 4],
          'n' => [3, 5], 'm' => [3, 6], ',' => [3, 7], '.' => [3, 8], '/' => [3, 9]
        }.freeze

        # Initialize QWERTY layout
        def initialize
          super(
            name: 'QWERTY',
            language_codes: %w[en es pt us en-US en-GB en-AU en-CA en-NZ en-ZA
                             es-ES es-MX pt-BR pt-PT],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
