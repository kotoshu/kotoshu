# frozen_string_literal: true

module Kotoshu
  module Keyboard
    module Layouts
      # Persian standard keyboard layout (ISIRI 9147).
      #
      # Shares the Arabic letter skeleton but carries the four Persian
      # letters as real keys: پ چ ژ گ replace their Arabic equivalents
      # at standard positions, and ک ی are the Persian keheh/yeh
      # keycaps. The ZWNJ and diacritics are dead keys and stay out of
      # the grid; the Arabic→Persian letter slips (ك→ک ي→ی) are
      # handled at the normalizer level.
      #
      # The key grid is mirrored from the models repo eval harness
      # (kotoshu/models-fasttext-onnx eval/noise.py _FA_STD, plan 83
      # batch 2 of the model coverage expansion, verified there
      # against ISIRI 9147 renderings) so typo-adjacency used for
      # suggestion ranking matches the adjacency used to evaluate the
      # models. spec/kotoshu/keyboard/layouts/eval_grid_drift_spec.rb
      # enforces the sync.
      #
      # Languages: fa, fa-IR
      class PersianStandard < Layout
        # Key positions for the Persian standard layout.
        # Each key maps to [row, column] coordinates.
        KEY_POSITIONS = {
          # Number row
          '`' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3],
          '4' => [0, 4], '5' => [0, 5], '6' => [0, 6], '7' => [0, 7],
          '8' => [0, 8], '9' => [0, 9], '0' => [0, 10], '-' => [0, 11],
          '=' => [0, 12],
          # Top row (ض ص ث ق ف غ ع ه خ ح ج چ)
          'ض' => [1, 0], 'ص' => [1, 1], 'ث' => [1, 2], 'ق' => [1, 3],
          'ف' => [1, 4], 'غ' => [1, 5], 'ع' => [1, 6], 'ه' => [1, 7],
          'خ' => [1, 8], 'ح' => [1, 9], 'ج' => [1, 10], 'چ' => [1, 11],
          # Home row (ش س ی ب ل ا ت ن م ک گ)
          'ش' => [2, 0], 'س' => [2, 1], 'ی' => [2, 2], 'ب' => [2, 3],
          'ل' => [2, 4], 'ا' => [2, 5], 'ت' => [2, 6], 'ن' => [2, 7],
          'م' => [2, 8], 'ک' => [2, 9], 'گ' => [2, 10],
          # Bottom row (ظ ط ز ر ذ د پ و ۀ .)
          'ظ' => [3, 0], 'ط' => [3, 1], 'ز' => [3, 2], 'ر' => [3, 3],
          'ذ' => [3, 4], 'د' => [3, 5], 'پ' => [3, 6], 'و' => [3, 7],
          'ۀ' => [3, 8], '.' => [3, 9]
        }.freeze

        # Initialize the Persian standard layout.
        def initialize
          super(
            name: 'Persian-Standard',
            language_codes: %w[fa fa-IR],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
