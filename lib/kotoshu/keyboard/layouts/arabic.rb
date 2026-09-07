# frozen_string_literal: true

module Kotoshu
  module Keyboard
    module Layouts
      # Arabic 101 keyboard layout (standard IBM PC Arabic layout).
      #
      # The Arabic letters sit on the QWERTY key faces: the number row
      # is shared with ASCII, and ض ص ث ق ف غ ع ه خ ح ج د / ش س ي ب ل ا
      # ت ن م ك ط / ئ ء ؤ ر لا ى ة و ز ظ fill the three letter rows.
      # Diacritics (tashkeel) are dead keys and are not in the grid;
      # the hamza carriers أ إ آ and the ه/ة ي/ى spelling slips are
      # handled at the normalizer level, not as physical keys.
      #
      # The key grid is mirrored from the models repo eval harness
      # (kotoshu/models-fasttext-onnx eval/noise.py _AR_101, plan 83
      # batch 2 of the model coverage expansion, verified there
      # against the kbdlayout.info Arabic 101 driver table) so
      # typo-adjacency used for suggestion ranking matches the
      # adjacency used to evaluate the models.
      # spec/kotoshu/keyboard/layouts/eval_grid_drift_spec.rb enforces
      # the sync.
      #
      # Languages: ar, ar-SA
      class Arabic101 < Layout
        # Key positions for the Arabic 101 layout.
        # Each key maps to [row, column] coordinates.
        KEY_POSITIONS = {
          # Number row
          'ذ' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3],
          '4' => [0, 4], '5' => [0, 5], '6' => [0, 6], '7' => [0, 7],
          '8' => [0, 8], '9' => [0, 9], '0' => [0, 10], '-' => [0, 11],
          '=' => [0, 12],
          # Top row (ض ص ث ق ف غ ع ه خ ح ج د)
          'ض' => [1, 0], 'ص' => [1, 1], 'ث' => [1, 2], 'ق' => [1, 3],
          'ف' => [1, 4], 'غ' => [1, 5], 'ع' => [1, 6], 'ه' => [1, 7],
          'خ' => [1, 8], 'ح' => [1, 9], 'ج' => [1, 10], 'د' => [1, 11],
          # Home row (ش س ي ب ل ا ت ن م ك ط)
          'ش' => [2, 0], 'س' => [2, 1], 'ي' => [2, 2], 'ب' => [2, 3],
          'ل' => [2, 4], 'ا' => [2, 5], 'ت' => [2, 6], 'ن' => [2, 7],
          'م' => [2, 8], 'ك' => [2, 9], 'ط' => [2, 10],
          # Bottom row (ئ ء ؤ ر لا ى ة و ز ظ)
          'ئ' => [3, 0], 'ء' => [3, 1], 'ؤ' => [3, 2], 'ر' => [3, 3],
          'لا' => [3, 4], 'ى' => [3, 5], 'ة' => [3, 6], 'و' => [3, 7],
          'ز' => [3, 8], 'ظ' => [3, 9]
        }.freeze

        # Initialize the Arabic 101 layout.
        def initialize
          super(
            name: 'Arabic-101',
            language_codes: %w[ar ar-SA],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
