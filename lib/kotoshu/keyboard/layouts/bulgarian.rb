# frozen_string_literal: true

module Kotoshu
  module Keyboard
    module Layouts
      # Bulgarian BDS keyboard layout (БДС 5237:1978, KBDBUL.DLL).
      #
      # The national Bulgarian phonetic-adjacent ordering: ы у е и ш щ
      # к с д з ц / ь я а о ж г т н в м ч / ю й ъ э ф х п р л б. The
      # Bulgarian-only letters ъ ь are real keys (unlike JCUKEN, where
      # ъ sits top-right and ы is the home-row opener).
      #
      # The key grid is mirrored from the models repo eval harness
      # (kotoshu/models-fasttext-onnx eval/noise.py _BG_BDS, plan 83
      # batch 2 of the model coverage expansion, verified there
      # against the kbdlayout.info KBDBUL driver table) so
      # typo-adjacency used for suggestion ranking matches the
      # adjacency used to evaluate the models.
      # spec/kotoshu/keyboard/layouts/eval_grid_drift_spec.rb enforces
      # the sync.
      #
      # Languages: bg, bg-BG
      class BulgarianBds < Layout
        # Key positions for the Bulgarian BDS layout.
        # Each key maps to [row, column] coordinates.
        KEY_POSITIONS = {
          # Number row
          ')' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3],
          '4' => [0, 4], '5' => [0, 5], '6' => [0, 6], '7' => [0, 7],
          '8' => [0, 8], '9' => [0, 9], '0' => [0, 10], '$' => [0, 11],
          '€' => [0, 12],
          # Top row (ы у е и ш щ к с д з ц)
          'ы' => [1, 0], 'у' => [1, 1], 'е' => [1, 2], 'и' => [1, 3],
          'ш' => [1, 4], 'щ' => [1, 5], 'к' => [1, 6], 'с' => [1, 7],
          'д' => [1, 8], 'з' => [1, 9], 'ц' => [1, 10],
          # Home row (ь я а о ж г т н в м ч)
          'ь' => [2, 0], 'я' => [2, 1], 'а' => [2, 2], 'о' => [2, 3],
          'ж' => [2, 4], 'г' => [2, 5], 'т' => [2, 6], 'н' => [2, 7],
          'в' => [2, 8], 'м' => [2, 9], 'ч' => [2, 10],
          # Bottom row (ю й ъ э ф х п р л б)
          'ю' => [3, 0], 'й' => [3, 1], 'ъ' => [3, 2], 'э' => [3, 3],
          'ф' => [3, 4], 'х' => [3, 5], 'п' => [3, 6], 'р' => [3, 7],
          'л' => [3, 8], 'б' => [3, 9]
        }.freeze

        # Initialize the Bulgarian BDS layout.
        def initialize
          super(
            name: 'Bulgarian-BDS',
            language_codes: %w[bg bg-BG],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
