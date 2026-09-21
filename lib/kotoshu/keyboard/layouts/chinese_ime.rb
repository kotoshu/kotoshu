# frozen_string_literal: true

module Kotoshu
  module Keyboard
    module Layouts
      # Shared QWERTY physical grid for Chinese IME composition.
      #
      # Pinyin, Jyutping, Cangjie, and Sucheng are all typed on a
      # QWERTY (or QWERTY-labelled) physical keyboard. The typo space
      # during composition is Latin-letter + digit proximity, not CJK
      # glyph adjacency. Distinct layout classes exist so:
      #   1. language_code → IME default is explicit (zh-Hans → Pinyin,
      #      zh-Hant-HK → Jyutping, zh-Hant-TW → Cangjie)
      #   2. user config can pin an IME (keyboard_layout: "Cangjie")
      #   3. dual-layout scoring still pairs the IME with plain QWERTY
      #      (plan C7 — the user may be on either)
      #
      # Future work can attach IME-specific confusion pairs (tone digits,
      # cangjie radical swaps) without changing the physical grid.
      module ChineseIme
        KEY_POSITIONS = Layouts::QWERTY::KEY_POSITIONS
      end

      # Hanyu Pinyin — default IME for Simplified Chinese.
      class Pinyin < Layout
        def initialize
          super(
            name: "Pinyin",
            language_codes: %w[zh zh-Hans zh-Hans-CN zh-CN cmn],
            key_positions: ChineseIme::KEY_POSITIONS
          )
        end
      end

      # Jyutping / Cantonese romanization — default for Hong Kong.
      class Jyutping < Layout
        def initialize
          super(
            name: "Jyutping",
            language_codes: %w[zh-Hant-HK zh-HK yue],
            key_positions: ChineseIme::KEY_POSITIONS
          )
        end
      end

      # Cangjie — shape-based IME, default for Traditional Taiwan.
      class Cangjie < Layout
        def initialize
          super(
            name: "Cangjie",
            language_codes: %w[zh-Hant zh-Hant-TW zh-TW],
            key_positions: ChineseIme::KEY_POSITIONS
          )
        end
      end

      # Sucheng (Simplified Cangjie) — faster cangjie variant.
      class Sucheng < Layout
        def initialize
          super(
            name: "Sucheng",
            language_codes: %w[], # opt-in via keyboard_layout config only
            key_positions: ChineseIme::KEY_POSITIONS
          )
        end
      end
    end
  end
end
