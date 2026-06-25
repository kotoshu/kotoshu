# frozen_string_literal: true

require 'rubygems'
require 'zip'

module Kotoshu
  module Readers
    # Base reader class for reading files line by line.
    #
    # This class provides:
    # - Line-by-line reading with line numbers
    # - BOM (byte-order mark) handling
    # - Comment stripping
    # - Empty line filtering
    #
    # @example Basic usage
    #   reader = FileReader.new('file.aff', 'UTF-8')
    #   reader.each do |line_no, line|
    #     puts "#{line_no}: #{line}"
    #   end
    class FileReader
      # @return [String] The file path
      attr_reader :path

      # @return [String] The encoding
      attr_reader :encoding

      # @return [Integer] Current line number
      attr_reader :line_no

      # BOM (byte-order mark) for UTF-8
      UTF8_BOM = "\xEF\xBB\xBF".freeze

      # Create a new file reader.
      #
      # @param path [String] Path to the file
      # @param encoding [String] File encoding (default: 'UTF-8')
      def initialize(path, encoding = 'UTF-8')
        @path = path
        @encoding = encoding
        @line_no = 0
        @file = nil
        @iterator = nil
        reset_io
      end

      # Reset encoding and reopen file.
      #
      # @param new_encoding [String] New encoding
      def reset_encoding(new_encoding)
        @encoding = new_encoding
        @line_no = 0
        @file&.close
        reset_io
      end

      # Iterate over lines.
      #
      # @yield [Integer, String] Line number and line content
      # @return [Enumerator] If no block given
      def each
        return enum_for(:each) unless block_given?

        @iterator.each { |line_no, line| yield(line_no, line) }
      end

      # Get all lines as an array.
      #
      # @return [Array<Array<Integer, String>>] Array of [line_no, line] pairs
      def to_a
        @iterator.to_a
      end

      # Check if there are more lines.
      #
      # @return [Boolean] True if there are more lines
      def has_next?
        peek
        true
      rescue StopIteration
      false
      end

      # Peek at next line without consuming it.
      #
      # @return [Array<Integer, String>] Next line number and content
      def peek
        @iterator.peek
      end

      # Get next line.
      #
      # @return [Array<Integer, String>] Line number and content
      def next
        @iterator.next
      end

      # Reset the reader to the beginning.
      def reset
        @line_no = 0
        reset_io
      end

      # Close the file.
      def close
        @file&.close
        @file = nil
      end

      private

      # Reset the IO object.
      def reset_io
        @file = File.open(@path, "r:#{@encoding}:utf-8")
        @iterator = read_lines.lazy
      end

      # Read lines from the file.
      #
      # @return [Enumerator] Enumerator of [line_no, line] pairs
      def read_lines
        return enum_for(:read_lines) unless block_given?

        @file.each_line do |line|
          @line_no += 1
          line = line.strip

          # Skip empty lines
          next if line.empty?

          # Handle UTF-8 BOM on first line
          if @line_no == 1 && line.start_with?(UTF8_BOM)
            line = line[UTF8_BOM.length..]
            line = line.strip if line
          end

          # Skip if line is now empty after processing
          next if line.nil? || line.empty?

          yield [@line_no, line]
        end
      end
    end

    # String reader for reading from a string.
    #
    # Useful for testing or when content is already in memory.
    class StringReader < FileReader
      # Create a new string reader.
      #
      # @param content [String] The content to read
      # @param encoding [String] Encoding (default: 'UTF-8')
      def initialize(content, encoding = 'UTF-8')
        @content = content
        @lines = content.split("\n", -1)
        @index = 0
        super(nil, encoding)
      end

      private

      def reset_io
        @line_no = 0
        @index = 0
        @iterator = read_lines_iterator
      end

      def read_lines_iterator
        Enumerator.new do |yielder|
          while @index < @lines.length
            @line_no += 1
            line = @lines[@index].strip
            @index += 1

            # Skip empty lines
            next if line.empty?

            # Handle UTF-8 BOM on first line
            if @line_no == 1 && line.start_with?(UTF8_BOM)
              line = line[UTF8_BOM.length..]
              line = line.strip if line
            end

            # Skip if line is now empty after processing
            next if line.nil? || line.empty?

            yielder << [@line_no, line]
          end
        end
      end
    end

    # Zip reader for reading files from zip archives.
    #
    # This class reads files from within zip archives, such as
    # OpenOffice/LibreOffice extensions (.odt, .oxt).
    #
    # @example Reading from a zip archive
    #   zip = Zip::File.open('dictionary.oxt')
    #   reader = ZipReader.new(zip, 'en_US.aff', 'UTF-8')
    #   reader.each do |line_no, line|
    #     puts "#{line_no}: #{line}"
    #   end
    class ZipReader
      # @return [Zip::File] The zip file object
      attr_reader :zipfile

      # @return [String] The entry path within the zip
      attr_reader :entry_path

      # @return [String] The encoding
      attr_reader :encoding

      # @return [Integer] Current line number
      attr_reader :line_no

      # BOM (byte-order mark) for UTF-8
      UTF8_BOM = "\xEF\xBB\xBF".freeze

      # Create a new zip reader.
      #
      # @param zipfile [Zip::File] The zip file object
      # @param entry_path [String] Path to the entry within the zip
      # @param encoding [String] File encoding (default: 'UTF-8')
      def initialize(zipfile, entry_path, encoding = 'UTF-8')
        @zipfile = zipfile
        @entry_path = entry_path
        @encoding = encoding
        @line_no = 0
        @entry = nil
        @iterator = nil
        reset_io
      end

      # Reset encoding and reopen zip entry.
      #
      # @param new_encoding [String] New encoding
      def reset_encoding(new_encoding)
        @encoding = new_encoding
        @line_no = 0
        @entry&.close
        reset_io
      end

      # Iterate over lines.
      #
      # @yield [Integer, String] Line number and line content
      # @return [Enumerator] If no block given
      def each
        return enum_for(:each) unless block_given?

        @iterator.each { |line_no, line| yield(line_no, line) }
      end

      # Get all lines as an array.
      #
      # @return [Array<Array<Integer, String>>] Array of [line_no, line] pairs
      def to_a
        @iterator.to_a
      end

      # Check if there are more lines.
      #
      # @return [Boolean] True if there are more lines
      def has_next?
        peek
        true
      rescue StopIteration
        false
      end

      # Peek at next line without consuming it.
      #
      # @return [Array<Integer, String>] Next line number and content
      def peek
        @iterator.peek
      end

      # Get next line.
      #
      # @return [Array<Integer, String>] Line number and content
      def next
        @iterator.next
      end

      # Reset the reader to the beginning.
      def reset
        @line_no = 0
        reset_io
      end

      # Close the zip entry.
      def close
        @entry&.close
        @entry = nil
      end

      private

      # Reset the IO object.
      def reset_io
        @entry = @zipfile.find_entry(@entry_path)
        raise IOError, "Entry not found in zip: #{@entry_path}" unless @entry

        # Read the entire entry content and decode it
        content = @entry.get_input_stream.read
        content = content.encode(@encoding, invalid: :replace, undef: :replace)

        @lines = content.split("\n", -1)
        @line_no = 0
        @iterator = read_lines_from_zip.lazy
      end

      # Read lines from the zip entry.
      #
      # @return [Enumerator] Enumerator of [line_no, line] pairs
      def read_lines_from_zip
        return enum_for(:read_lines_from_zip) unless block_given?

        @lines.each do |line|
          @line_no += 1
          line = line.strip

          # Skip empty lines
          next if line.empty?

          # Handle UTF-8 BOM on first line
          if @line_no == 1 && line.start_with?(UTF8_BOM)
            line = line[UTF8_BOM.length..]
            line = line.strip if line
          end

          # Skip if line is now empty after processing
          next if line.nil? || line.empty?

          yield [@line_no, line]
        end
      end
    end
  end
end
