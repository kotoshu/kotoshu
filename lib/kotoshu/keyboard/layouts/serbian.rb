# frozen_string_literal: true

module Kotoshu
  module Keyboard
    module Layouts
      # Serbian Cyrillic keyboard layout (ЉЊЕРТЗУИОПШ /
      # АСДФГХЈКЛЧЋ / ЏЦВБНМ, KBDSR driver table).
      #
      # The Serbian-specific letters љ њ ђ ћ џ ј are real keys: љ њ
      # take the q/w faces, ђ sits where QWERTY carries the right
      # bracket, and џ ц в б н м fill the bottom row. Serbian Latin
      # (sr-Latn) types on the South-Slavic QWERTZ grid and is
      # claimed by its own layout (Layouts::SerbianLatin, plan 110),
      # not this one.
      #
      # The key grid is mirrored from the models repo eval harness
      # (kotoshu/models-fasttext-onnx eval/noise.py _SR_CYR, plan 83
      # batch 2 of the model coverage expansion) so typo-adjacency
      # used for suggestion ranking matches the adjacency used to
      # evaluate the models.
      # spec/kotoshu/keyboard/layouts/eval_grid_drift_spec.rb enforces
      # the sync.
      #
      # Languages: sr, sr-RS
      class SerbianCyrillic < Layout
        # Key positions for the Serbian Cyrillic layout.
        # Each key maps to [row, column] coordinates.
        KEY_POSITIONS = {
          # Number row
          '`' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3],
          '4' => [0, 4], '5' => [0, 5], '6' => [0, 6], '7' => [0, 7],
          '8' => [0, 8], '9' => [0, 9], '0' => [0, 10],
          "'" => [0, 11], '+' => [0, 12],
          # Top row (љ њ е р т з у и о п ш ђ)
          'љ' => [1, 0], 'њ' => [1, 1], 'е' => [1, 2], 'р' => [1, 3],
          'т' => [1, 4], 'з' => [1, 5], 'у' => [1, 6], 'и' => [1, 7],
          'о' => [1, 8], 'п' => [1, 9], 'ш' => [1, 10], 'ђ' => [1, 11],
          # Home row (а с д ф г х ј к л ч ћ ж)
          'а' => [2, 0], 'с' => [2, 1], 'д' => [2, 2], 'ф' => [2, 3],
          'г' => [2, 4], 'х' => [2, 5], 'ј' => [2, 6], 'к' => [2, 7],
          'л' => [2, 8], 'ч' => [2, 9], 'ћ' => [2, 10], 'ж' => [2, 11],
          # Bottom row (џ ц в б н м , . -)
          'џ' => [3, 0], 'ц' => [3, 1], 'в' => [3, 2], 'б' => [3, 3],
          'н' => [3, 4], 'м' => [3, 5], ',' => [3, 6], '.' => [3, 7],
          '-' => [3, 8]
        }.freeze

        # Initialize the Serbian Cyrillic layout.
        def initialize
          super(
            name: 'Serbian-Cyrillic',
            language_codes: %w[sr sr-RS],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
