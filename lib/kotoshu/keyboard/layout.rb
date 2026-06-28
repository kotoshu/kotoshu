# frozen_string_literal: true

module Kotoshu
  module Keyboard
    # Base class for keyboard layouts
    #
    # Each layout defines key positions and provides distance calculations
    # for typo detection and suggestion ranking in spell checking.
    #
    # @example Using a keyboard layout
    #   layout = Keyboard::Layouts::QWERTY.new
    #   layout.distance('q', 'w')  # => 1 (adjacent keys)
    #   layout.distance('q', 'p')  # => 8 (far apart)
    #   layout.adjacent_keys('q')  # => ['w', 'a', 's']
    #
    # @example Checking language support
    #   qwerty = Keyboard::Layouts::QWERTY.new
    #   qwerty.supports_language?('en')  # => true
    #   qwerty.supports_language?('de')  # => false
    #
    class Layout
      # @return [String] the name of this keyboard layout
      attr_reader :name

      # @return [Array<String>] list of language codes this layout supports
      attr_reader :language_codes

      # @return [Hash] mapping of key characters to [row, col] positions
      attr_reader :key_positions

      # Initialize a keyboard layout
      #
      # @param name [String] the name of the layout
      # @param language_codes [Array<String>] list of language codes this layout supports
      # @param key_positions [Hash] mapping of key characters to [row, col] positions
      def initialize(name:, language_codes:, key_positions:)
        @name = name
        @language_codes = Array(language_codes).freeze
        @key_positions = key_positions.freeze
      end

      # Get position [row, col] for a key
      #
      # @param key [String] the key character to look up
      # @return [Array<Integer>, nil] the [row, col] position, or nil if key not found
      def position(key)
        @key_positions[key.downcase]
      end

      # Calculate Manhattan distance between two keys
      #
      # Manhattan distance is the sum of absolute differences of row and column:
      # distance = abs(row1 - row2) + abs(col1 - col2)
      #
      # @param key1 [String] first key character
      # @param key2 [String] second key character
      # @return [Integer] Manhattan distance (0 if same key, Float::INFINITY if either key not found)
      def distance(key1, key2)
        pos1 = position(key1)
        pos2 = position(key2)

        return Float::INFINITY unless pos1 && pos2

        (pos1[0] - pos2[0]).abs + (pos1[1] - pos2[1]).abs
      end

      # Check if layout supports a language
      #
      # Supports both exact matching and language variant matching.
      # For example, if 'en' is supported, then 'en-US', 'en-GB', etc. are also supported.
      #
      # @param language_code [String] the language code to check (e.g., 'en', 'en-US', 'de')
      # @return [Boolean] true if this layout supports the language
      def supports_language?(language_code)
        # Try exact match first
        return true if @language_codes.include?(language_code)

        # Try base language match (e.g., 'en' for 'en-US')
        base_lang = language_code.to_s.split('-').first
        @language_codes.include?(base_lang)
      end

      # Get adjacent keys for a given key (within 1 unit distance)
      #
      # Adjacent keys are those that are directly next to the given key
      # horizontally or vertically (not diagonal).
      #
      # @param key [String] the key character to find adjacent keys for
      # @return [Array<String>] list of adjacent key characters
      def adjacent_keys(key)
        pos = position(key)
        return [] unless pos

        @key_positions.select do |k, p|
          next if k == key

          ((p[0] - pos[0]).abs + (p[1] - pos[1]).abs) == 1
        end.keys
      end

      # String representation of the layout
      #
      # @return [String] layout name
      def to_s
        "Keyboard::#{@name}"
      end

      # Inspect method for debugging
      #
      # @return [String] detailed inspection string
      def inspect
        "#<#{self.class} name=#{@name} languages=#{@language_codes.join(',')}>"
      end
    end
  end
end
