# frozen_string_literal: true

require_relative 'keyboard/registry'

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
