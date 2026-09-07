# frozen_string_literal: true

module Kotoshu
  module Keyboard
    module Layouts
      # Croatian and Slovenian QWERTZ keyboard layouts (KBDCRO /
      # KBDYCL driver tables — the two national standards share one
      # physical grid).
      #
      # The five South-Slavic Latin letters are real keys: š đ take
      # the top-row bracket faces, č ć ž the home-row umlaut faces
      # and the key right of them. Everything else is the QWERTZ
      # physical arrangement (z/y swapped), so diacritic slips are not
      # possible for these five — they are key slips.
      #
      # The shared key grid is mirrored from the models repo eval
      # harness (kotoshu/models-fasttext-onnx eval/noise.py _HRSL,
      # plan 83 batch 2 of the model coverage expansion, verified
      # there against the kbdlayout.info driver tables) so
      # typo-adjacency used for suggestion ranking matches the
      # adjacency used to evaluate the models.
      # spec/kotoshu/keyboard/layouts/eval_grid_drift_spec.rb enforces
      # the sync.
      module HrSlQwertz
        # Key positions for the Croatian/Slovenian QWERTZ grid.
        # Each key maps to [row, column] coordinates.
        KEY_POSITIONS = {
          # Number row
          '‚' => [0, 0], '1' => [0, 1], '2' => [0, 2], '3' => [0, 3],
          '4' => [0, 4], '5' => [0, 5], '6' => [0, 6], '7' => [0, 7],
          '8' => [0, 8], '9' => [0, 9], '0' => [0, 10],
          "'" => [0, 11], '+' => [0, 12],
          # Top row (QWERTZ + š đ)
          'q' => [1, 0], 'w' => [1, 1], 'e' => [1, 2], 'r' => [1, 3],
          't' => [1, 4], 'z' => [1, 5], 'u' => [1, 6], 'i' => [1, 7],
          'o' => [1, 8], 'p' => [1, 9], 'š' => [1, 10], 'đ' => [1, 11],
          # Home row (ASDFG + č ć ž)
          'a' => [2, 0], 's' => [2, 1], 'd' => [2, 2], 'f' => [2, 3],
          'g' => [2, 4], 'h' => [2, 5], 'j' => [2, 6], 'k' => [2, 7],
          'l' => [2, 8], 'č' => [2, 9], 'ć' => [2, 10], 'ž' => [2, 11],
          # Bottom row (YXCVB)
          'y' => [3, 0], 'x' => [3, 1], 'c' => [3, 2], 'v' => [3, 3],
          'b' => [3, 4], 'n' => [3, 5], 'm' => [3, 6],
          ',' => [3, 7], '.' => [3, 8], '-' => [3, 9]
        }.freeze
      end

      # Croatian QWERTZ (KBDCRO / Croatian standard grid).
      #
      # Languages: hr, hr-HR
      class Croatian < Layout
        # Initialize the Croatian layout.
        def initialize
          super(
            name: 'Croatian-QWERTZ',
            language_codes: %w[hr hr-HR],
            key_positions: HrSlQwertz::KEY_POSITIONS
          )
        end
      end

      # Slovenian QWERTZ (KBDYCL / Slovenian standard grid — the same
      # physical arrangement as Croatian).
      #
      # Languages: sl, sl-SI
      class Slovenian < Layout
        # Initialize the Slovenian layout.
        def initialize
          super(
            name: 'Slovenian-QWERTZ',
            language_codes: %w[sl sl-SI],
            key_positions: HrSlQwertz::KEY_POSITIONS
          )
        end
      end
    end
  end
end
