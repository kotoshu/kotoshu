# frozen_string_literal: true

require_relative 'layout'
require_relative 'layouts/qwerty'
require_relative 'layouts/qwertz'
require_relative 'layouts/azerty'
require_relative 'layouts/jcuken'
require_relative 'layouts/dvorak'

module Kotoshu
  module Keyboard
    # Registry for keyboard layouts
    #
    # The registry provides a centralized way to access keyboard layouts
    # and automatically selects the appropriate layout for a given language.
    #
    # @example Getting layout for a language
    #   layout = Keyboard::Registry.layout_for('de')
    #   layout.name  # => "QWERTZ"
    #
    # @example Getting layout by name
    #   layout = Keyboard::Registry.layout_by_name('Dvorak')
    #   layout.name  # => "Dvorak"
    #
    # @example Listing all available layouts
    #   Keyboard::Registry.available_layouts.each do |layout|
    #     puts "#{layout.name}: #{layout.language_codes.join(', ')}"
    #   end
    #
    class Registry
      class << self
        # Register a keyboard layout
        #
        # @param layout_class [Class<Layout>] the layout class to register
        # @return [Layout] the instantiated layout
        def register(layout_class)
          layouts[layout_class.name] = layout_class.new
        end

        # Get layout for a specific language code
        #
        # Searches for a layout that supports the given language code.
        # Returns QWERTY as fallback if no matching layout is found.
        #
        # @param language_code [String] the language code (e.g., 'en', 'de', 'fr', 'ru')
        # @return [Layout] the keyboard layout for the language
        def layout_for(language_code)
          # Try exact match first
          layout = layouts.values.find { |l| l.supports_language?(language_code) }

          # Try base language if variant (e.g., 'en-GB' -> 'en')
          unless layout
            base_lang = language_code.to_s.split('-').first
            layout = layouts.values.find { |l| l.supports_language?(base_lang) }
          end

          layout || default_layout
        end

        # Get layout by name
        #
        # @param name [String, Symbol] the layout name (e.g., 'QWERTY', 'Dvorak')
        # @return [Layout] the layout, or QWERTY as fallback if not found
        def layout_by_name(name)
          name_str = name.to_s
          result = layouts.values.find do |layout|
            layout.name == name_str ||
              layout.class.name.end_with?("::#{name_str}")
          end

          # Return QWERTY as fallback (not default_layout to avoid recursion)
          result || layouts['Kotoshu::Keyboard::Layouts::QWERTY']
        end

        # Get all available layouts
        #
        # @return [Array<Layout>] list of all registered layouts
        def available_layouts
          layouts.values
        end

        # Get all supported language codes
        #
        # @return [Array<String>] list of all language codes across all layouts
        def supported_languages
          layouts.values.flat_map(&:language_codes).uniq.sort
        end

        # Set the default layout
        #
        # @param layout_name [String, Symbol] the name of the layout to use as default
        def register_default(layout_name)
          @default_layout_name = layout_name
        end

        # Check if a language is supported
        #
        # @param language_code [String] the language code to check
        # @return [Boolean] true if the language is supported by any layout
        def supports_language?(language_code)
          layouts.values.any? { |l| l.supports_language?(language_code) }
        end

        # Clear all registered layouts (mainly for testing)
        #
        # @return [void]
        def clear!
          @layouts = nil
          @default_layout_name = nil
        end

        private

        # Get or initialize the layouts hash
        #
        # @return [Hash] hash of layout class names to instances
        def layouts
          @layouts ||= {}
        end

        # Get the default layout
        #
        # @return [Layout] the default layout (QWERTY if none specified)
        def default_layout
          if @default_layout_name
            name_str = @default_layout_name.to_s
            layout = layouts.values.find do |l|
              l.name == name_str || l.class.name.end_with?("::#{name_str}")
            end
            return layout if layout
          end

          # Return QWERTY as the ultimate fallback
          layouts['Kotoshu::Keyboard::Layouts::QWERTY'] || layouts.values.first
        end
      end

      # Auto-register all layout classes on load
      register(Layouts::QWERTY)
      register(Layouts::QWERTZ)
      register(Layouts::AZERTY)
      register(Layouts::JCUKEN)
      register(Layouts::Dvorak)
    end
  end
end
