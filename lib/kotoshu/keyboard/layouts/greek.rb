# frozen_string_literal: true

module Kotoshu
  module Keyboard
    module Layouts
      # Greek phonetic keyboard layout.
      #
      # The mnemonic/phonetic mapping used by Greek typists: each Greek
      # letter sits on the Latin letter it transliterates to (; is the
      # semicolon key doubling as the Greek question mark). Accented
      # vowels are dead-key sequences, not physical keys, so they do not
      # appear in the grid — matching the models repo eval model, where
      # accents are diacritic slips handled outside the layout.
      #
      # The key grid is mirrored from the models repo eval harness
      # (kotoshu/models-fasttext-onnx eval/noise.py _EL_PHONETIC,
      # wave 1 of the model coverage expansion). The drift spec
      # spec/kotoshu/keyboard/layouts/eval_grid_drift_spec.rb enforces
      # the sync.
      #
      # Languages: el, el-GR
      class GreekPhonetic < Layout
        # Key positions for the Greek phonetic layout.
        # Each key maps to [row, column] coordinates.
        KEY_POSITIONS = {
          # Number row
          '`' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3], '4' => [0, 4],
          '5' => [0, 5], '6' => [0, 6], '7' => [0, 7], '8' => [0, 8], '9' => [0, 9],
          '0' => [0, 10], '-' => [0, 11], '=' => [0, 12],
          # Top row (;ΣΕΡΤΥΘΙΟΠ)
          ';' => [1, 0], 'σ' => [1, 1], 'ε' => [1, 2], 'ρ' => [1, 3], 'τ' => [1, 4],
          'υ' => [1, 5], 'θ' => [1, 6], 'ι' => [1, 7], 'ο' => [1, 8], 'π' => [1, 9],
          # Home row (ΑΔΦΓΗΞΚΛ)
          'α' => [2, 0], 'δ' => [2, 1], 'φ' => [2, 2], 'γ' => [2, 3], 'η' => [2, 4],
          'ξ' => [2, 5], 'κ' => [2, 6], 'λ' => [2, 7],
          # Bottom row (ΖΧΨΩΒΝΜ)
          'ζ' => [3, 0], 'χ' => [3, 1], 'ψ' => [3, 2], 'ω' => [3, 3], 'β' => [3, 4],
          'ν' => [3, 5], 'μ' => [3, 6]
        }.freeze

        # Initialize the Greek phonetic layout.
        def initialize
          super(
            name: 'Greek-Phonetic',
            language_codes: %w[el el-GR],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
