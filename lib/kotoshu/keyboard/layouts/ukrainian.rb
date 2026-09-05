# frozen_string_literal: true

module Kotoshu
  module Keyboard
    module Layouts
      # Ukrainian JCUKEN keyboard layout (standard Ukrainian layout).
      #
      # Extends the Russian JCUKEN grid with the Ukrainian-only keys:
      # і replaces ы, ї replaces ъ, є replaces э, and ґ sits right of х.
      # The Russian-only ы ъ э ё keys do not exist on the Ukrainian grid.
      #
      # The key grid is mirrored from the models repo eval harness
      # (kotoshu/models-fasttext-onnx eval/noise.py _UK_JCUKEN, wave 1
      # of the model coverage expansion). The drift spec
      # spec/kotoshu/keyboard/layouts/eval_grid_drift_spec.rb enforces
      # the sync.
      #
      # Languages: uk, uk-UA
      class Ukrainian < Layout
        # Key positions for the Ukrainian JCUKEN layout.
        # Each key maps to [row, column] coordinates.
        KEY_POSITIONS = {
          # Number row
          "'" => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3], '4' => [0, 4],
          '5' => [0, 5], '6' => [0, 6], '7' => [0, 7], '8' => [0, 8], '9' => [0, 9],
          '0' => [0, 10], '-' => [0, 11], '=' => [0, 12],
          # Top row (ЙЦУКЕН + ї ґ)
          'й' => [1, 0], 'ц' => [1, 1], 'у' => [1, 2], 'к' => [1, 3], 'е' => [1, 4],
          'н' => [1, 5], 'г' => [1, 6], 'ш' => [1, 7], 'щ' => [1, 8], 'з' => [1, 9],
          'х' => [1, 10], 'ї' => [1, 11], 'ґ' => [1, 12],
          # Home row (ФІВАПР + є)
          'ф' => [2, 0], 'і' => [2, 1], 'в' => [2, 2], 'а' => [2, 3], 'п' => [2, 4],
          'р' => [2, 5], 'о' => [2, 6], 'л' => [2, 7], 'д' => [2, 8], 'ж' => [2, 9],
          'є' => [2, 10],
          # Bottom row (ЯЧСМИТ + ь б ю)
          'я' => [3, 0], 'ч' => [3, 1], 'с' => [3, 2], 'м' => [3, 3], 'и' => [3, 4],
          'т' => [3, 5], 'ь' => [3, 6], 'б' => [3, 7], 'ю' => [3, 8], '.' => [3, 9]
        }.freeze

        # Initialize the Ukrainian JCUKEN layout.
        def initialize
          super(
            name: 'Ukrainian-JCUKEN',
            language_codes: %w[uk uk-UA],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
