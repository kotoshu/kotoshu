# frozen_string_literal: true

require_relative '../layout'

module Kotoshu
  module Keyboard
    module Layouts
      # JCUKEN keyboard layout
      #
      # Standard JCUKEN layout used for:
      # - Russian (ru, ru-RU)
      # - Ukrainian (uk)
      # - Belarusian (be)
      # - Bulgarian (bg)
      #
      # This is the standard Cyrillic keyboard layout.
      # Key differences from QWERTY:
      # - Completely different alphabet (Cyrillic: 33 letters)
      # - JCUKEN mapping corresponds to QWERTY positions
      # - Has special keys: ё, ъ, ь
      #
      # Key positions use [row, col] coordinates where:
      # - row 0: number row (ё1"2...)
      # - row 1: top row (йцукен...)
      # - row 2: home row (фывап...)
      # - row 3: bottom row (ячсми...)
      class JCUKEN < Layout
        # Key positions for JCUKEN layout (Cyrillic)
        # Each key maps to [row, column] coordinates
        KEY_POSITIONS = {
          # Number row
          'ё' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3], '4' => [0, 4],
          '5' => [0, 5], '6' => [0, 6], '7' => [0, 7], '8' => [0, 8], '9' => [0, 9],
          '0' => [0, 10], '-' => [0, 11], '=' => [0, 12],
          # Top row (ЙЦУКЕН - corresponds to QWERTY)
          'й' => [1, 0], 'ц' => [1, 1], 'у' => [1, 2], 'к' => [1, 3], 'е' => [1, 4],
          'н' => [1, 5], 'г' => [1, 6], 'ш' => [1, 7], 'щ' => [1, 8], 'з' => [1, 9],
          'х' => [1, 10], 'ъ' => [1, 11],
          # Home row (ФЫВАПРОЛД - corresponds to ASDFGHJKL)
          'ф' => [2, 0], 'ы' => [2, 1], 'в' => [2, 2], 'а' => [2, 3], 'п' => [2, 4],
          'р' => [2, 5], 'о' => [2, 6], 'л' => [2, 7], 'д' => [2, 8], 'ж' => [2, 9],
          'э' => [2, 10],
          # Bottom row (ЯЧСМИТЬБЮ - corresponds to ZXCVBNM)
          'я' => [3, 0], 'ч' => [3, 1], 'с' => [3, 2], 'м' => [3, 3], 'и' => [3, 4],
          'т' => [3, 5], 'ь' => [3, 6], 'б' => [3, 7], 'ю' => [3, 8], '.' => [3, 9]
        }.freeze

        # Initialize JCUKEN layout
        def initialize
          super(
            name: 'JCUKEN',
            language_codes: %w[ru uk be bg ru-RU],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
