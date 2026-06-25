# frozen_string_literal: true

require_relative 'aff_data'
require_relative 'file_reader'

module Kotoshu
  module Readers
    # AFF file reader for Hunspell affix files.
    #
    # This class reads .aff files and creates an Aff data structure.
    #
    # @example Reading an aff file
    #   reader = AffReader.new('en_US.aff')
    #   aff = reader.read
    class AffReader
      # Directives that are single boolean flags
      BOOLEAN_DIRECTIVES = %w[
        COMPLEXPREFIXES FULLSTRIP NOSPLITSUGS CHECKSHARPS
        CHECKCOMPOUNDCASE CHECKCOMPOUNDDUP CHECKCOMPOUNDREP CHECKCOMPOUNDTRIPLE
        SIMPLIFIEDTRIPLE ONLYMAXDIFF COMPOUNDMORESUFFIXES
      ].freeze

      # Directives that are single string values
      STRING_DIRECTIVES = %w[SET FLAG KEY TRY WORDCHARS LANG].freeze

      # Directives that are single integer values
      INTEGER_DIRECTIVES = %w[MAXDIFF MAXNGRAMSUGS MAXCPDSUGS COMPOUNDMIN COMPOUNDWORDMAX].freeze

      # Directives that are single flag values
      FLAG_DIRECTIVES = %w[
        NOSUGGEST KEEPCASE CIRCUMFIX NEEDAFFIX FORBIDDENWORD WARN
        COMPOUNDFLAG COMPOUNDBEGIN COMPOUNDMIDDLE COMPOUNDEND
        ONLYINCOMPOUND COMPOUNDPERMITFLAG COMPOUNDFORBIDFLAG FORCEUCASE
        SUBSTANDARD SYLLABLENUM COMPOUNDROOT
      ].freeze

      # Outdated directive names and their synonyms
      SYNONYMS = {
        'PSEUDOROOT' => 'NEEDAFFIX',
        'COMPOUNDLAST' => 'COMPOUNDEND'
      }.freeze

      attr_reader :path, :encoding, :flag_format

      # Create a new AFF reader.
      #
      # @param path [String] Path to the .aff file
      # @param encoding [String] File encoding (default: 'UTF-8');
      #   overridden by the file's SET directive when present
      def initialize(path, encoding: 'UTF-8')
        @path = path
        @encoding = detect_encoding(path) || encoding
        @flag_format = 'short'
        @flag_synonyms = {}
      end

      # Read the aff file and return the aff data structure.
      #
      # @param source [FileReader, nil] Optional file reader to use instead of creating a new one
      # @return [Hash] The aff data structure
      def read(source = nil)
        reader = source || FileReader.new(@path, @encoding)

        data = {
          'SFX' => {},
          'PFX' => {},
          'FLAG' => 'short'
        }

        reader.each do |_line_no, line|
          dir_value = read_directive(reader, line)
          next unless dir_value

          directive, value = dir_value

          # Update flag format when FLAG directive is encountered (BEFORE using it)
          if directive == 'FLAG'
            @flag_format = value
          end

          # Re-parse FLAG directive value now that @flag_format is updated
          if directive == 'FLAG' && value.is_a?(String)
            # No re-parsing needed for FLAG, just update the format
          end

          # SFX/PFX have multiple entries
          if %w[SFX PFX].include?(directive)
            data[directive][value.first.flag] = value
          else
            data[directive] = value
          end

          # Update flag synonyms when AF directive is encountered (AFTER storing it)
          if directive == 'AF'
            @flag_synonyms = value
          end

          # Note: We don't reset_encoding during iteration because it closes
          # the file and breaks the iteration. The FileReader is initialized
          # with UTF-8 encoding which handles most cases.
        end

        data
      end

      private

      # Read a directive from a line.
      #
      # @param reader [FileReader] The file reader
      # @param line [String] The line to parse
      # @return [Array, nil] [directive, value] or nil
      def read_directive(reader, line)
        parts = line.split(/\s+/)
        return nil if parts.empty?

        name = parts[0]

        # Check if it looks like a directive (all caps)
        return nil unless name =~ /^[A-Z]+$/

        # Handle synonyms
        name = SYNONYMS[name] || name

        value = read_value(reader, name, parts[1..])

        return nil if value.nil?

        [name, value]
      end

      # Read the value for a directive.
      #
      # @param reader [FileReader] The file reader
      # @param directive [String] The directive name
      # @param values [Array<String>] Values from the line
      # @return [Object] The parsed value
      def read_value(reader, directive, values)
        value = values.first

        # String directives
        if STRING_DIRECTIVES.include?(directive)
          return value
        end

        # Integer directives
        if INTEGER_DIRECTIVES.include?(directive)
          return value&.to_i
        end

        # Flag directives
        if FLAG_DIRECTIVES.include?(directive)
          return parse_flag(value)
        end

        # Boolean directives
        if BOOLEAN_DIRECTIVES.include?(directive)
          return true
        end

        # IGNORE directive
        if directive == 'IGNORE'
          return Ignore.new(value || '')
        end

        # BREAK directive
        if directive == 'BREAK'
          count = value&.to_i || 0
          return read_array(reader, count).map { |parts| BreakPattern.new(parts.first) }
        end

        # COMPOUNDRULE directive
        if directive == 'COMPOUNDRULE'
          count = value&.to_i || 0
          return read_array(reader, count).map { |parts| CompoundRule.new(parts.first) }
        end

        # ICONV/OCONV directives
        if %w[ICONV OCONV].include?(directive)
          count = value&.to_i || 0
          pairs = read_array(reader, count).map { |parts| [parts[0], parts[1] || ''] }
          return ConvTable.new(pairs)
        end

        # REP directive
        if directive == 'REP'
          count = value&.to_i || 0
          return read_array(reader, count).map { |parts| RepPattern.new(parts[0], parts[1] || '') }
        end

        # MAP directive
        if directive == 'MAP'
          count = value&.to_i || 0
          return read_array(reader, count).map do |parts|
            chars = parts.first || ''
            # Parse MAP format: "aàâä" or "ß(ss)" - split by parentheses or individual chars
            # Parenthesized groups like "(ss)" should be kept as a single string "ss"
            chars.scan(/(\([^()]+\)|[^()])/).flatten.map do |group|
              # Remove parentheses from parenthesized groups, keep as single string
              # For single characters, keep as is
              if group.start_with?('(') && group.end_with?(')')
                group[1..-2]  # Remove parentheses, keep content as single string
              else
                group  # Keep single character as is
              end
            end
          end
        end

        # SFX/PFX directives
        if %w[SFX PFX].include?(directive)
          flag, crossproduct, count = values[0], values[1], values[2]&.to_i || 0
          type = directive == 'PFX' ? :prefix : :suffix

          affixes = read_array(reader, count).map do |parts|
            # Format: FLAG strip add condition [morph_data]
            # After read_array (which skips directive), parts[0] is FLAG again
            # So we skip parts[0] and use: parts[1]=strip, parts[2]=add, parts[3]=condition
            strip = parts[1] == '0' ? '' : (parts[1] || '')
            add = parts[2] || ''
            condition = parts[3] || '.'

            # Handle flags in add field: "able/CD" -> add="able", flags=["C", "D"]
            if add.include?('/')
              add_str, _, flags_str = add.rpartition('/')
            else
              add_str = add
              flags_str = ''
            end
            flags = flags_str.empty? ? Set.new : parse_flags(flags_str).to_set

            Affix.new(
              type:,
              flag:,
              crossproduct: crossproduct == 'Y',
              strip:,
              add: add_str == '0' ? '' : add_str,
              condition:,
              flags:
            )
          end

          return affixes
        end

        # CHECKCOMPOUNDPATTERN directive
        if directive == 'CHECKCOMPOUNDPATTERN'
          count = value&.to_i || 0
          return read_array(reader, count).map do |parts|
            CompoundPattern.new(parts[0], parts[1] || '', parts[2])
          end
        end

        # AF directive (flag synonyms)
        if directive == 'AF'
          count = value&.to_i || 0
          result = {}
          read_array(reader, count).each_with_index do |parts, i|
            # AF directives always use single-character flags (short format)
            # regardless of the main FLAG format
            flags = parts.first.chars
            result[(i + 1).to_s] = flags.to_set
          end
          return result
        end

        # AM directive
        if directive == 'AM'
          count = value&.to_i || 0
          result = {}
          read_array(reader, count).each_with_index do |parts, i|
            result[(i + 1).to_s] = parts.to_set
          end
          return result
        end

        # COMPOUNDSYLLABLE directive
        if directive == 'COMPOUNDSYLLABLE'
          return [value&.to_i, values[1]]
        end

        # PHONE directive
        if directive == 'PHONE'
          count = value&.to_i || 0
          table = read_array(reader, count).map { |parts| [parts[0], parts[1] || '_'] }
          return PhonetTable.new(table)
        end

        # Unknown directive - return nil
        nil
      end

      # Read an array of values from the reader.
      #
      # @param reader [FileReader] The file reader
      # @param count [Integer] Number of lines to read
      # @return [Array<Array<String>>] Array of parsed lines
      def read_array(reader, count)
        result = []
        count.times do
          line_no, line = reader.next
          parts = line.split(/\s+/)
          # Skip the directive name at the beginning
          result << parts[1..] if parts.length > 1
        end
        result
      end

      # Parse a single flag.
      #
      # @param string [String] Flag string
      # @return [String] Parsed flag
      def parse_flag(string)
        parse_flags(string).first
      end

      # Parse multiple flags.
      #
      # @param string [String] Flag string
      # @return [Array<String>] Parsed flags
      def parse_flags(string)
        return [] if string.nil? || string.empty?

        # Check flag synonyms (only if the key exists in @flag_synonyms)
        if @flag_synonyms&.key?(string)
          return @flag_synonyms[string].to_a
        end

        case @flag_format
        when 'short'
          string.chars
        when 'long'
          string.scan(/../)
        when 'num'
          string.scan(/\d+/)
        when 'UTF-8'
          string.chars
        else
          raise ArgumentError, "Unknown flag format: #{@flag_format}"
        end
      end

      # Detect the file's encoding from its SET directive.
      # Pre-scans the first ~4KB of the file in binary mode so we can
      # reopen with the correct encoding before the FileReader consumes it.
      #
      # @param path [String] Path to the .aff file
      # @return [String, nil] Encoding name (e.g., "ISO8859-1", "UTF-8") or nil
      def detect_encoding(path)
        return nil unless File.file?(path)

        snippet = File.open(path, "rb") { |f| f.read(4096) }
        match = snippet.match(/^SET\s+(\S+)/)
        return nil unless match

        normalize_encoding_name(match[1])
      end

      # Normalize Hunspell encoding names to Ruby encoding names.
      #
      # @param name [String] Hunspell encoding identifier
      # @return [String] Ruby encoding name
      def normalize_encoding_name(name)
        return name if name.upcase == "UTF-8"

        normalized = name.upcase.delete("-")
        if normalized.start_with?("ISO8859")
          "ISO-8859-#{normalized.sub("ISO8859", "")}"
        else
          name
        end
      end
    end
  end
end
