# frozen_string_literal: true

module Kotoshu
  module Models
    # Word model representing a dictionary word with metadata.
    #
    # This is a value object that represents a word in the dictionary
    # along with its morphological information (flags and data).
    #
    # @note This class is immutable and frozen on initialization.
    #
    # @example Creating a word
    #   word = Models::Word.new("hello", flags: ["noun"], morphological_data: { root: "hell" })
    #   word.text        # => "hello"
    #   word.valid?      # => true
    class Word
      # @return [String] The word text
      attr_reader :text

      # @return [Array<String>] Morphological flags (e.g., "noun", "verb")
      attr_reader :flags

      # @return [Hash] Additional morphological data
      attr_reader :morphological_data

      # Create a new Word.
      #
      # @param text [String] The word text
      # @param flags [Array<String>] Morphological flags (optional)
      # @param morphological_data [Hash] Additional morphological data (optional)
      def initialize(text, flags: [], morphological_data: {})
        raise ArgumentError, "Text cannot be empty" if text.nil? || text.empty?

        @text = text.dup.freeze
        @flags = flags.dup.freeze
        @morphological_data = morphological_data.dup.freeze

        freeze
      end

      # Check if the word is valid (has content).
      #
      # @return [Boolean] True if the word is valid
      def valid?
        !@text.nil? && !@text.empty?
      end

      # Check if the word has a specific flag.
      #
      # @param flag [String] The flag to check
      # @return [Boolean] True if the word has the flag
      def has_flag?(flag)
        @flags.include?(flag)
      end

      # Check if the word has any flags.
      #
      # @return [Boolean] True if the word has flags
      def has_flags?
        !@flags.empty?
      end

      # Get the length of the word.
      #
      # @return [Integer] Word length
      def length
        @text.length
      end

      # Check if the word is empty.
      #
      # @return [Boolean] True if the word is empty
      def empty?
        @text.empty?
      end

      # Convert to string.
      #
      # @return [String] The word text
      def to_s
        @text
      end

      # Convert to hash.
      #
      # @return [Hash] Hash representation
      def to_h
        {
          text: @text,
          flags: @flags,
          morphological_data: @morphological_data
        }
      end

      # Check equality based on text.
      #
      # @param other [Word, String] The other object
      # @return [Boolean] True if equal
      def ==(other)
        return false unless other.is_a?(Word)
        @text == other.text
      end
      alias eql? ==

      # Hash based on text.
      #
      # @return [Integer] Hash code
      def hash
        @text.hash
      end

      # Compare words by text.
      #
      # @param other [Word] The other word
      # @return [Integer] Comparison result
      def <=>(other)
        return nil unless other.is_a?(Word)
        @text <=> other.text
      end

      # Create a word from a Hunspell dictionary line.
      #
      # @param line [String] Dictionary line (e.g., "hello/flag" or "hello")
      # @return [Word] New word instance
      #
      # @example
      #   Word.from_dic_line("hello/N")  # => Word with text "hello" and flag "N"
      #   Word.from_dic_line("hello")    # => Word with text "hello" and no flags
      def self.from_dic_line(line)
        return nil if line.nil? || line.empty?

        parts = line.split("/", 2)
        text = parts[0]
        flags = parts[1] ? parts[1].split("") : []

        new(text, flags: flags)
      end
    end
  end
end
