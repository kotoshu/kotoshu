# frozen_string: true

module Kotoshu
  module Keyboard
    module Layouts
      # Dubeolsik — the standard Korean 2-set keyboard layout.
      #
      # Source: KS X 5002 (2-set Hangeul keyboard), the national
      # standard every Korean IME ships. Each key produces one jamo
      # (shift doubles the fortis consonants); the IME composes
      # lead + vowel + tail into precomposed syllables, so the grid
      # this layout models is jamo-keyed: typo proximity is measured
      # on the jamo a slip actually hit, which is exactly the unit
      # vowel mergers and fortis/lenis confusions operate on. The
      # models repo eval harness models Korean slips as jamo
      # confusion pairs rather than a key grid (eval/noise.py
      # _KO_PAIRS), so there is no eval grid to drift-check against —
      # this grid cites the layout standard itself.
      #
      # Row 1 (QWERTY q..p): ㅂ ㅈ ㄷ ㄱ ㅅ ㅛ ㅕ ㅑ ㅐ ㅔ
      # Row 2 (a..l):        ㅁ ㄴ ㅇ ㄹ ㅎ ㅗ ㅓ ㅏ ㅣ
      # Row 3 (z..m):        ㅋ ㅌ ㅊ ㅍ ㅠ ㅜ ㅡ
      # Shift row 1:         ㅃ ㅉ ㄸ ㄲ ㅆ (and ㅒ ㅖ on o/p)
      class Dubeolsik < Layout
        # Jamo-to-key-position grid, [row, col] coordinates on the
        # three alphabetic rows (0-based col within each row, aligned
        # to the physical QWERTY key columns).
        KEY_POSITIONS = {
          # Top row
          'ㅂ' => [0, 0], 'ㅈ' => [0, 1], 'ㄷ' => [0, 2], 'ㄱ' => [0, 3],
          'ㅅ' => [0, 4], 'ㅛ' => [0, 5], 'ㅕ' => [0, 6], 'ㅑ' => [0, 7],
          'ㅐ' => [0, 8], 'ㅔ' => [0, 9],
          # Shift of the top row: fortis consonants and y-diphthongs
          'ㅃ' => [0, 0], 'ㅉ' => [0, 1], 'ㄸ' => [0, 2], 'ㄲ' => [0, 3],
          'ㅆ' => [0, 4], 'ㅒ' => [0, 8], 'ㅖ' => [0, 9],
          # Home row
          'ㅁ' => [1, 0], 'ㄴ' => [1, 1], 'ㅇ' => [1, 2], 'ㄹ' => [1, 3],
          'ㅎ' => [1, 4], 'ㅗ' => [1, 5], 'ㅓ' => [1, 6], 'ㅏ' => [1, 7],
          'ㅣ' => [1, 8],
          # Bottom row
          'ㅋ' => [2, 0], 'ㅌ' => [2, 1], 'ㅊ' => [2, 2], 'ㅍ' => [2, 3],
          'ㅠ' => [2, 4], 'ㅜ' => [2, 5], 'ㅡ' => [2, 6]
        }.freeze

        # Initialize Dubeolsik layout
        def initialize
          super(
            name: 'Dubeolsik',
            language_codes: %w[ko ko-KR],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
