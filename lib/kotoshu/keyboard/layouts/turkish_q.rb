# frozen_string_literal: true

module Kotoshu
  module Keyboard
    module Layouts
      # Turkish-Q keyboard layout (standard Turkish physical layout).
      #
      # The Turkish-specific letters ı ğ ü ş i ö ç are real keys:
      # ı sits where i is on QWERTY, i replaces the semicolon key, and
      # ğ ü ş ö ç replace the bracket/apostrophe/slash family.
      #
      # The key grid is mirrored from the models repo eval harness
      # (kotoshu/models-fasttext-onnx eval/noise.py _TR_Q, wave 1 of the
      # model coverage expansion) so typo-adjacency used for suggestion
      # ranking matches the adjacency used to evaluate the models.
      # spec/kotoshu/keyboard/layouts/eval_grid_drift_spec.rb enforces
      # the sync.
      #
      # Languages: tr, tr-TR
      class TurkishQ < Layout
        # Key positions for the Turkish-Q layout.
        # Each key maps to [row, column] coordinates.
        KEY_POSITIONS = {
          # Number row
          '"' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3], '4' => [0, 4],
          '5' => [0, 5], '6' => [0, 6], '7' => [0, 7], '8' => [0, 8], '9' => [0, 9],
          '0' => [0, 10], '*' => [0, 11], '-' => [0, 12],
          # Top row (QWERTY + ı ğ ü)
          'q' => [1, 0], 'w' => [1, 1], 'e' => [1, 2], 'r' => [1, 3], 't' => [1, 4],
          'y' => [1, 5], 'u' => [1, 6], 'ı' => [1, 7], 'o' => [1, 8], 'p' => [1, 9],
          'ğ' => [1, 10], 'ü' => [1, 11],
          # Home row (ASDFG + ş i)
          'a' => [2, 0], 's' => [2, 1], 'd' => [2, 2], 'f' => [2, 3], 'g' => [2, 4],
          'h' => [2, 5], 'j' => [2, 6], 'k' => [2, 7], 'l' => [2, 8], 'ş' => [2, 9],
          'i' => [2, 10],
          # Bottom row (ZXCVB + ö ç)
          'z' => [3, 0], 'x' => [3, 1], 'c' => [3, 2], 'v' => [3, 3], 'b' => [3, 4],
          'n' => [3, 5], 'm' => [3, 6], 'ö' => [3, 7], 'ç' => [3, 8], '.' => [3, 9]
        }.freeze

        # Initialize the Turkish-Q layout.
        def initialize
          super(
            name: 'Turkish-Q',
            language_codes: %w[tr tr-TR],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
