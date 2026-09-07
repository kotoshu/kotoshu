# frozen_string_literal: true

module Kotoshu
  module Keyboard
    module Layouts
      # Parameterized Latin-script layout family.
      #
      # The wave-1 Latin languages type on one of two physical base
      # grids — QWERTY (it nl pl ro ca vi da nb sv) or QWERTZ (cs hu) —
      # optionally with per-language physical extras: the Nordic layouts
      # have real å/æ/ø and å/ä/ö keys where US QWERTY carries
      # [ ] ; '. Their remaining diacritics are dead-key or AltGr
      # sequences, not physical keys, so they do not appear in the key
      # grid. This mirrors the models repo eval model
      # (kotoshu/models-fasttext-onnx eval/noise.py: LANG_LAYOUT maps
      # the Latin newcomers onto the qwerty/qwertz grids and handles
      # diacritics as _LANG_ALTERNATES slips), keeping gem suggestion
      # adjacency and eval adjacency in sync. Batch 3 (plan 100) adds
      # id sk et lt lv on the same qwerty base grid.
      #
      # One family, per-language declarations — no near-duplicate
      # layout files. The five pre-existing layouts (qwerty qwertz
      # azerty jcuken dvorak) are untouched.
      #
      # @example Declaring a member of the family
      #   class Italian < Latin
      #     layout_name 'Italian-QWERTY'
      #     languages %w[it it-IT]
      #     base_grid :qwerty
      #   end
      class Latin < Layout
        # Sentinel distinguishing "reader call" from "writer call".
        NOT_SET = Object.new.freeze

        class << self
          # Get or set the layout display name.
          #
          # @param value [String, NOT_SET] name when declaring
          # @return [String, nil] the declared name
          def layout_name(value = NOT_SET)
            return @layout_name if value.equal?(NOT_SET)

            @layout_name = value
          end

          # Get or set the supported language codes.
          #
          # @param value [Array<String>, NOT_SET] codes when declaring
          # @return [Array<String>, nil] the declared codes
          def languages(value = NOT_SET)
            return @languages if value.equal?(NOT_SET)

            @languages = Array(value).freeze
          end

          # Get or set the base physical grid.
          #
          # @param value [Symbol, NOT_SET] :qwerty or :qwertz
          # @return [Symbol, nil] the declared base grid
          def base_grid(value = NOT_SET)
            return @base_grid if value.equal?(NOT_SET)

            @base_grid = value
          end

          # Get or set keys removed from the base grid.
          #
          # Used by the Nordic members, whose å/æ/ø keys replace the
          # US bracket and semicolon keys.
          #
          # @param value [Array<String>, NOT_SET] keys to remove
          # @return [Array<String>, nil] the removed keys
          def removed_keys(value = NOT_SET)
            return @removed_keys if value.equal?(NOT_SET)

            @removed_keys = Array(value).freeze
          end

          # Get or set extra physical keys merged over the base grid.
          #
          # @param value [Hash{String => Array<Integer>}, NOT_SET]
          #   key => [row, col] pairs
          # @return [Hash{String => Array<Integer>}, nil] the extras
          def extra_positions(value = NOT_SET)
            return @extra_positions if value.equal?(NOT_SET)

            @extra_positions = value.freeze
          end
        end

        # Build the layout from the class declarations: the base grid,
        # minus removed keys, plus extra physical keys.
        def initialize
          super(
            name: self.class.layout_name,
            language_codes: self.class.languages,
            key_positions: build_positions
          )
        end

        private

        # Compose the final key-position grid.
        #
        # @return [Hash{String => Array<Integer>}] the composed grid
        def build_positions
          positions = base_grid_positions
          removed = self.class.removed_keys
          positions = positions.except(*removed) if removed
          extras = self.class.extra_positions
          extras ? positions.merge(extras) : positions
        end

        # Resolve the base grid constant.
        #
        # @return [Hash{String => Array<Integer>}] the base key positions
        # @raise [ArgumentError] when no known base grid was declared
        def base_grid_positions
          case self.class.base_grid
          when :qwerty then Layouts::QWERTY::KEY_POSITIONS
          when :qwertz then Layouts::QWERTZ::KEY_POSITIONS
          else
            raise ArgumentError,
                  "#{self.class} must declare base_grid :qwerty or :qwertz"
          end
        end

        # Italian: US QWERTY physical layout; accents are dead keys.
        class Italian < Latin
          layout_name 'Italian-QWERTY'
          languages %w[it it-IT]
          base_grid :qwerty
        end

        # Dutch: US QWERTY physical layout; accents are dead keys.
        class Dutch < Latin
          layout_name 'Dutch-QWERTY'
          languages %w[nl nl-NL]
          base_grid :qwerty
        end

        # Polish: programmers' (US-equivalent) QWERTY layout, the
        # layout Polish fastText corpora are typed on; ą ć ę ł ń ó ś
        # ź ż are AltGr sequences.
        class Polish < Latin
          layout_name 'Polish-QWERTY'
          languages %w[pl pl-PL]
          base_grid :qwerty
        end

        # Czech: QWERTZ physical layout (z/y swapped, ü ö ä keys);
        # háčky and čárky are dead keys.
        class Czech < Latin
          layout_name 'Czech-QWERTZ'
          languages %w[cs cs-CZ]
          base_grid :qwertz
        end

        # Hungarian: QWERTZ physical layout; ő ű are dead keys.
        class Hungarian < Latin
          layout_name 'Hungarian-QWERTZ'
          languages %w[hu hu-HU]
          base_grid :qwertz
        end

        # Romanian: US QWERTY physical layout; ă â î ș ț are AltGr
        # sequences.
        class Romanian < Latin
          layout_name 'Romanian-QWERTY'
          languages %w[ro ro-RO]
          base_grid :qwerty
        end

        # Catalan: Spanish (US-equivalent) QWERTY physical layout; the
        # gem keys Catalan to the qwerty grid like the eval model does.
        class Catalan < Latin
          layout_name 'Catalan-QWERTY'
          languages %w[ca ca-ES]
          base_grid :qwerty
        end

        # Vietnamese: US QWERTY physical layout; all tone and vowel
        # marks are typed with dead keys over the ASCII letters.
        class Vietnamese < Latin
          layout_name 'Vietnamese-QWERTY'
          languages %w[vi vi-VN]
          base_grid :qwerty
        end

        # Danish: Nordic QWERTY with real å æ ø keys replacing the
        # US bracket/semicolon keys.
        class Danish < Latin
          layout_name 'Danish-QWERTY'
          languages %w[da da-DK]
          base_grid :qwerty
          removed_keys %w([ ] ; ')
          extra_positions({ 'å' => [1, 10], 'æ' => [2, 9], 'ø' => [2, 10] })
        end

        # Norwegian Bokmal: same Nordic physical grid as Danish (å æ ø).
        class Norwegian < Latin
          layout_name 'Norwegian-QWERTY'
          languages %w[nb nb-NO]
          base_grid :qwerty
          removed_keys %w([ ] ; ')
          extra_positions({ 'å' => [1, 10], 'æ' => [2, 9], 'ø' => [2, 10] })
        end

        # Swedish: Nordic QWERTY with real å ä ö keys (ä ö where
        # Danish/Norwegian carry æ ø).
        class Swedish < Latin
          layout_name 'Swedish-QWERTY'
          languages %w[sv sv-SE]
          base_grid :qwerty
          removed_keys %w([ ] ; ')
          extra_positions({ 'å' => [1, 10], 'ä' => [2, 9], 'ö' => [2, 10] })
        end

        # Indonesian: US QWERTY physical layout — the Indonesian
        # national standard types on the unmodified US grid, and the
        # eval harness maps id the same way (plan 83 batch 2).
        class Indonesian < Latin
          layout_name 'Indonesian-QWERTY'
          languages %w[id id-ID]
          base_grid :qwerty
        end

        # Slovak: US QWERTY physical layout; the eval harness maps sk
        # to the qwerty grid (plan 83 batch 2) with the háčik
        # diacritics as dead-key slips, exactly the Polish
        # programmers' pattern. The Slovak QWERTZ national variant
        # exists, but Slovak QWERTY is the widely-typed form.
        class Slovak < Latin
          layout_name 'Slovak-QWERTY'
          languages %w[sk sk-SK]
          base_grid :qwerty
        end

        # Estonian: US QWERTY physical layout; ä ö õ ü š ž are dead-key
        # or AltGr sequences on the eval model grid (plan 83 batch 2).
        class Estonian < Latin
          layout_name 'Estonian-QWERTY'
          languages %w[et et-EE]
          base_grid :qwerty
        end

        # Lithuanian: US QWERTY physical layout; ą č ę ė į š ų ū ž are
        # dead-key or AltGr sequences (plan 83 batch 2 eval mapping).
        class Lithuanian < Latin
          layout_name 'Lithuanian-QWERTY'
          languages %w[lt lt-LT]
          base_grid :qwerty
        end

        # Latvian: US QWERTY physical layout; ā č ē ģ ī ķ ļ ņ š ū ž
        # are dead-key or AltGr sequences (plan 83 batch 2 eval
        # mapping).
        class Latvian < Latin
          layout_name 'Latvian-QWERTY'
          languages %w[lv lv-LV]
          base_grid :qwerty
        end
      end
    end
  end
end
