# frozen_string_literal: true

module Kotoshu
  module Keyboard
    module Layouts
      # CRULP Urdu phonetic keyboard layout (v1.1), the dominant Urdu
      # typing layout.
      #
      # Phonetically arranged: Urdu letters sit on the Latin key whose
      # sound they carry (q=ق, s=س, k=ک ...). Only the positions that
      # are unambiguous across CRULP references are encoded here — the
      # base level of every letter plus the four Urdu-specific
      # retroflex/extra letters at their CRULP shift positions (ٹ on T,
      # ڈ on D, ڑ on R, ژ on Z) and hamza/alif-madda (ء on H, آ on A).
      # Keys whose CRULP assignments differ across chart sources
      # (the x/c/v row-3 letters) are deliberately omitted — a missing
      # key signals unknown distance rather than a wrong one; refine
      # against the official CRULP KLC before relying on those cells.
      #
      # Sync law (Persian precedent): when the models repo eval harness
      # gains an Urdu noise grid, mirror it here and extend
      # spec/kotoshu/keyboard/layouts/eval_grid_drift_spec.rb.
      #
      # Languages: ur, ur-PK
      class UrduPhonetic < Layout
        KEY_POSITIONS = {
          # Top row
          'ق' => [1, 0], 'و' => [1, 1], 'ع' => [1, 2], 'ر' => [1, 3],
          'ت' => [1, 4], 'ے' => [1, 5], 'ئ' => [1, 6], 'ی' => [1, 7],
          'ہ' => [1, 8], 'پ' => [1, 9],
          # Home row
          'ا' => [2, 0], 'س' => [2, 1], 'د' => [2, 2], 'ف' => [2, 3],
          'گ' => [2, 4], 'ھ' => [2, 5], 'ج' => [2, 6], 'ک' => [2, 7],
          'ل' => [2, 8],
          # Bottom row (attested subset)
          'ز' => [3, 0], 'ب' => [3, 5], 'ن' => [3, 6], 'م' => [3, 7],
          # CRULP shift level — same physical keys as their base
          'ٹ' => [1, 4],  # Shift+T
          'ڈ' => [2, 2],  # Shift+D
          'ڑ' => [1, 3],  # Shift+R
          'ژ' => [3, 0],  # Shift+Z
          'ء' => [2, 5],  # Shift+H
          'آ' => [2, 0]   # Shift+A
        }.freeze

        def initialize
          super(
            name: 'Urdu-Phonetic',
            language_codes: %w[ur ur-PK],
            key_positions: KEY_POSITIONS
          )
        end
      end
    end
  end
end
