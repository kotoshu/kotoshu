# frozen_string_literal: true

require_relative 'file_reader'

module Kotoshu
  module Readers
    # Word entry from the dictionary file.
    #
    # @attr stem [String] The word stem
    # @attr flags [Set<String>] Morphological flags
    Word = Struct.new(:stem, :flags, keyword_init: true) do
      # Create a word from a dictionary line.
      #
      # @param line [String] The dictionary line
      # @param context [Hash] The reading context (for flag parsing)
      # @return [Word] The parsed word
      def self.from_line(line, context = {})
        # Format: stem[/flags][\t<morph_data>]
        # Split off morphological data first (tab or space separated),
        # then split stem from flags on the first "/".
        head = line.split(/[\t]/, 2).first || line
        head = head.strip
        slash_idx = head.index('/')
        if slash_idx
          stem = head[0...slash_idx]
          flags_str = head[(slash_idx + 1)..]
        else
          stem = head
          flags_str = nil
        end

        flags = if flags_str && !flags_str.empty? && context[:flag_format]
                  parse_flags(flags_str, context[:flag_format], context[:flag_synonyms])
                elsif flags_str && !flags_str.empty?
                  flags_str.chars.to_set
                else
                  Set.new
                end

        new(stem:, flags:)
      end

      # Parse flags from string.
      #
      # @param string [String] Flag string
      # @param flag_format [String] Flag format ('short', 'long', 'num', 'UTF-8')
      # @param flag_synonyms [Hash] Flag synonyms map
      # @return [Set<String>] Parsed flags
      def self.parse_flags(string, flag_format, flag_synonyms = {})
        return Set.new if string.nil? || string.empty?

        # Check flag synonyms
        if flag_synonyms && string =~ /^\d+$/
          return flag_synonyms[string] || Set.new
        end

        case flag_format
        when 'short'
          string.chars.to_set
        when 'long'
          string.scan(/../).to_set
        when 'num'
          string.scan(/\d+/).to_set
        when 'UTF-8'
          string.chars.to_set
        else
          string.chars.to_set
        end
      end
    end

    # DIC file reader for Hunspell dictionary files.
    #
    # This class reads .dic files and creates a list of Word entries.
    #
    # @example Reading a dic file
    #   reader = DicReader.new('en_US.dic', flag_format: 'short')
    #   words = reader.read
    class DicReader
      attr_reader :path, :encoding, :flag_format, :flag_synonyms

      # Create a new DIC reader.
      #
      # @param path [String] Path to the .dic file
      # @param encoding [String] File encoding (default: 'UTF-8')
      # @param flag_format [String] Flag format ('short', 'long', 'num', 'UTF-8')
      # @param flag_synonyms [Hash] Flag synonyms map
      def initialize(path, encoding: 'UTF-8', flag_format: 'short', flag_synonyms: {})
        @path = path
        @encoding = encoding
        @flag_format = flag_format
        @flag_synonyms = flag_synonyms
      end

      # Read the dic file and return a list of Word entries.
      #
      # @return [Array<Word>] List of word entries
      def read
        reader = FileReader.new(@path, @encoding)

        words = []
        first_line = true
        expected_count = 0

        reader.each do |_line_no, line|
          if first_line
            # First line is word count
            expected_count = line.to_i
            first_line = false
            next
          end

          # Skip empty lines
          next if line.empty?

          # Parse word
          word = Word.from_line(line, flag_format: @flag_format, flag_synonyms: @flag_synonyms)
          words << word
        end

        # Verify word count
        # Note: We don't raise an error if count doesn't match, as some dictionaries have different formats

        words
      end
    end
  end
end
