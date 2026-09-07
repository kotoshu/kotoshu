# frozen_string: true

module Kotoshu
  module Keyboard
    module Layouts
      # Devanagari InScript — the Indian national standard layout,
      # which Nepali types on (plan 108).
      #
      # Grid mirrored from the models repo eval harness
      # (kotoshu/models-fasttext-onnx eval/noise.py _NE_INSCRIPT,
      # staged by its plan 83 batch-2 eval expansion) and
      # drift-checked against it — the same rule as the other curated
      # national grids. The Nepali Traditional Romanized layout is
      # more common in Nepal, but InScript is the documented
      # standard, so it is the defensible choice (the eval harness
      # made the same call).
      class DevanagariInScript < Layout
        # Key positions for the InScript grid, [row, col] coordinates:
        # row 0 digits, rows 1-3 the Devanagari keys in InScript
        # order (matras left, consonants center/right).
        KEY_POSITIONS = {
          # Number row
          '`' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3],
          '4' => [0, 4], '5' => [0, 5], '6' => [0, 6], '7' => [0, 7],
          '8' => [0, 8], '9' => [0, 9], '0' => [0, 10], '-' => [0, 11],
          'ृ' => [0, 12],
          # Top row
          'ौ' => [1, 0], 'ै' => [1, 1], 'ा' => [1, 2], 'ी' => [1, 3],
          'ू' => [1, 4], 'ब' => [1, 5], 'ह' => [1, 6], 'ग' => [1, 7],
          'द' => [1, 8], 'ज' => [1, 9], 'ड' => [1, 10], '़' => [1, 11],
          # Home row
          'ो' => [2, 0], 'े' => [2, 1], '्' => [2, 2], 'ि' => [2, 3],
          'ु' => [2, 4], 'प' => [2, 5], 'र' => [2, 6], 'क' => [2, 7],
          'त' => [2, 8], 'च' => [2, 9], 'ट' => [2, 10],
          # Bottom row
          'ॉ' => [3, 0], 'ं' => [3, 1], 'म' => [3, 2], 'न' => [3, 3],
          'व' => [3, 4], 'ल' => [3, 5], 'स' => [3, 6], ',' => [3, 7],
          '.' => [3, 8], 'य' => [3, 9]
        }.freeze

        # Initialize DevanagariInScript layout
        def initialize
          super(
            name: 'DevanagariInScript',
            language_codes: %w[ne ne-NP],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
