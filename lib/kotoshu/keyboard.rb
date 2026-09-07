# frozen_string_literal: true

module Kotoshu
  # Keyboard layout system for Kotoshu
  #
  # This module provides access to keyboard layouts for typo detection
  # and suggestion ranking in multi-language spell checking.
  #
  # @example Getting a keyboard layout for a language
  #   layout = Kotoshu::Keyboard.layout_for('de')
  #   layout.distance('z', 'y')  # => 1 (adjacent on QWERTZ)
  #
  # @example Getting a layout by name
  #   dvorak = Kotoshu::Keyboard.layout_by_name('Dvorak')
  #   dvorak.distance('a', 'e')  # => 2 (home row on Dvorak)
  #
  module Keyboard
    autoload :Layout, "kotoshu/keyboard/layout"
    autoload :Registry, "kotoshu/keyboard/registry"

    module Layouts
      autoload :QWERTY, "kotoshu/keyboard/layouts/qwerty"
      autoload :QWERTZ, "kotoshu/keyboard/layouts/qwertz"
      autoload :AZERTY, "kotoshu/keyboard/layouts/azerty"
      autoload :JCUKEN, "kotoshu/keyboard/layouts/jcuken"
      autoload :Dvorak, "kotoshu/keyboard/layouts/dvorak"
      # Wave-1 national layouts (plan 84): grids mirrored from the
      # models repo eval harness.
      autoload :TurkishQ, "kotoshu/keyboard/layouts/turkish_q"
      autoload :Ukrainian, "kotoshu/keyboard/layouts/ukrainian"
      autoload :GreekPhonetic, "kotoshu/keyboard/layouts/greek"
      # Parameterized Latin family (plan 84): one file, per-language
      # declarations over the qwerty/qwertz base grids.
      autoload :Latin, "kotoshu/keyboard/layouts/latin"
      # Batch-3 national layouts (plan 100): grids mirrored from the
      # models repo eval harness (plan 83 batch-2 grids).
      autoload :Arabic101, "kotoshu/keyboard/layouts/arabic"
      autoload :PersianStandard, "kotoshu/keyboard/layouts/persian"
      autoload :HebrewSI1452, "kotoshu/keyboard/layouts/hebrew"
      autoload :BulgarianBds, "kotoshu/keyboard/layouts/bulgarian"
      autoload :SerbianCyrillic, "kotoshu/keyboard/layouts/serbian"
      autoload :Croatian, "kotoshu/keyboard/layouts/hrsl"
      autoload :Slovenian, "kotoshu/keyboard/layouts/hrsl"
    end

    class << self
      # Get keyboard layout for a language code
      #
      # @param language_code [String] the language code (e.g., 'en', 'de', 'fr', 'ru')
      # @return [Layout] the keyboard layout for the language
      def layout_for(language_code)
        Registry.layout_for(language_code)
      end

      # Get keyboard layout by name
      #
      # @param name [String, Symbol] the layout name (e.g., 'QWERTY', 'Dvorak')
      # @return [Layout, nil] the layout, or nil if not found
      def layout_by_name(name)
        Registry.layout_by_name(name)
      end

      # Get all available layouts
      #
      # @return [Array<Layout>] list of all registered layouts
      def available_layouts
        Registry.available_layouts
      end

      # Get all supported language codes
      #
      # @return [Array<String>] list of all language codes across all layouts
      def supported_languages
        Registry.supported_languages
      end

      # Check if a language is supported
      #
      # @param language_code [String] the language code to check
      # @return [Boolean] true if the language is supported by any layout
      def supports_language?(language_code)
        Registry.supports_language?(language_code)
      end
    end
  end
end
