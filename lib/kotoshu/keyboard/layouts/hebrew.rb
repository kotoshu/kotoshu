# frozen_string_literal: true

module Kotoshu
  module Keyboard
    module Layouts
      # Hebrew standard keyboard layout (SI-1452).
      #
      # The 27 Hebrew letters all sit on key faces in the standard
      # ordering, including the five final-letter forms ם ן ך ף ץ as
      # real keys. Niqqud (vowel points) are dead keys and are not in
      # the grid; geresh/gershayim are shift states, not base keys.
      #
      # The key grid is mirrored from the models repo eval harness
      # (kotoshu/models-fasttext-onnx eval/noise.py _HE_SI1452, plan 83
      # batch 2 of the model coverage expansion, verified there
      # against the Culmus SI-1452 layout table) so typo-adjacency
      # used for suggestion ranking matches the adjacency used to
      # evaluate the models.
      # spec/kotoshu/keyboard/layouts/eval_grid_drift_spec.rb enforces
      # the sync.
      #
      # Languages: he, he-IL
      class HebrewSI1452 < Layout
        # Key positions for the Hebrew SI-1452 layout.
        # Each key maps to [row, column] coordinates.
        KEY_POSITIONS = {
          # Number row
          '`' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3],
          '4' => [0, 4], '5' => [0, 5], '6' => [0, 6], '7' => [0, 7],
          '8' => [0, 8], '9' => [0, 9], '0' => [0, 10], '-' => [0, 11],
          '=' => [0, 12],
          # Top row (ק ר א ט ו ן ם פ)
          '/' => [1, 0], "'" => [1, 1], 'ק' => [1, 2], 'ר' => [1, 3],
          'א' => [1, 4], 'ט' => [1, 5], 'ו' => [1, 6], 'ן' => [1, 7],
          'ם' => [1, 8], 'פ' => [1, 9], '[' => [1, 10], ']' => [1, 11],
          # Home row (ש ד ג כ ע י ח ל ך ף)
          'ש' => [2, 0], 'ד' => [2, 1], 'ג' => [2, 2], 'כ' => [2, 3],
          'ע' => [2, 4], 'י' => [2, 5], 'ח' => [2, 6], 'ל' => [2, 7],
          'ך' => [2, 8], 'ף' => [2, 9], ',' => [2, 10],
          # Bottom row (ז ס ב ה נ מ צ ת ץ)
          'ז' => [3, 0], 'ס' => [3, 1], 'ב' => [3, 2], 'ה' => [3, 3],
          'נ' => [3, 4], 'מ' => [3, 5], 'צ' => [3, 6], 'ת' => [3, 7],
          'ץ' => [3, 8], '.' => [3, 9]
        }.freeze

        # Initialize the Hebrew SI-1452 layout.
        def initialize
          super(
            name: 'Hebrew-SI-1452',
            language_codes: %w[he he-IL],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
