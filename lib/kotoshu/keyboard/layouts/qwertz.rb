# frozen_string_literal: true

module Kotoshu
  module Keyboard
    module Layouts
      # QWERTZ keyboard layout
      #
      # Standard QWERTZ layout used for:
      # - German (de, de-DE, de-AT, de-CH)
      # - Austria (at)
      # - Switzerland (ch)
      #
      # Key differences from QWERTY:
      # - z and y are swapped (z/y → y/z)
      # - Has umlaut keys: ä, ö, ü
      # - Has ß key (Eszett)
      #
      # Key positions use [row, col] coordinates where:
      # - row 0: number row (^°1"2...)
      # - row 1: top row (qwertz...)
      # - row 2: home row (asdfg...)
      # - row 3: bottom row (yxcvb...) - note: y is here, not in top row
      class QWERTZ < Layout
        # Key positions for QWERTZ layout
        # Each key maps to [row, column] coordinates
        KEY_POSITIONS = {
          # Number row
          '^' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3], '4' => [0, 4],
          '5' => [0, 5], '6' => [0, 6], '7' => [0, 7], '8' => [0, 8], '9' => [0, 9],
          '0' => [0, 10], 'ß' => [0, 11], '´' => [0, 12],
          # Top row (QWERTZ - note z and y are swapped)
          'q' => [1, 0], 'w' => [1, 1], 'e' => [1, 2], 'r' => [1, 3], 't' => [1, 4],
          'z' => [1, 5], 'u' => [1, 6], 'i' => [1, 7], 'o' => [1, 8], 'p' => [1, 9],
          'ü' => [1, 10], '+' => [1, 11],
          # Home row (ASDFG)
          'a' => [2, 0], 's' => [2, 1], 'd' => [2, 2], 'f' => [2, 3], 'g' => [2, 4],
          'h' => [2, 5], 'j' => [2, 6], 'k' => [2, 7], 'l' => [2, 8], 'ö' => [2, 9],
          'ä' => [2, 10],
          # Bottom row (YXCVB - note y is here)
          'y' => [3, 0], 'x' => [3, 1], 'c' => [3, 2], 'v' => [3, 3], 'b' => [3, 4],
          'n' => [3, 5], 'm' => [3, 6], ',' => [3, 7], '.' => [3, 8], '-' => [3, 9]
        }.freeze

        # Initialize QWERTZ layout
        def initialize
          super(
            name: 'QWERTZ',
            language_codes: %w[de at ch de-DE de-AT de-CH],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
