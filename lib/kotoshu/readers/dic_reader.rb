# frozen_string_literal: true

module Kotoshu
  module Readers
    # Word entry from the dictionary file.
    #
    # @attr stem [String] The word stem
    # @attr flags [Set<String>] Morphological flags
    # @attr morph_data [Array<String>] Morphological data fields (e.g. "ph:wich")
    Word = Struct.new(:stem, :flags, :morph_data, keyword_init: true) do
      # Create a word from a dictionary line.
      #
      # @param line [String] The dictionary line
      # @param context [Hash] The reading context (for flag parsing)
      # @return [Word] The parsed word
      def self.from_line(line, context = {})
        # Format: stem[/flags][<SEP><morph_data>]
        # SEP is a tab per spec, but real-world fixtures (including the
        # Hunspell ph.* tests) sometimes use spaces. We split on the first
        # morphological token (key:value) regardless of separator.
        head, morph = split_stem_and_morph(line)
        head = head.strip

        # Find the first UNESCAPED slash to split stem from flags.
        # Hunspell allows `\/` to represent a literal `/` inside a word —
        # so we can't just use String#index('/'). Mirrors Spylls's
        # SLASH_REGEXP (a slash not preceded by a backslash).
        #
        # Special case: a word that STARTS with `/` is not an empty stem +
        # flags — it's a word whose first character is `/`. Without this,
        # dic entry `/` would be parsed as stem="" + flags="".
        if head.start_with?('/')
          stem = head
          flags_str = nil
        else
          slash_idx = unescaped_slash_index(head)
          if slash_idx
            stem = head[0...slash_idx]
            flags_str = head[(slash_idx + 1)..]
          else
            stem = head
            flags_str = nil
          end

          # Replace escaped slashes in the stem: `\/` → `/`
          stem = stem.gsub('\/', '/') if stem.include?('\/')
        end

        flags = if flags_str && !flags_str.empty? && context[:flag_format]
                  parse_flags(flags_str, context[:flag_format], context[:flag_synonyms])
                elsif flags_str && !flags_str.empty?
                  flags_str.chars.to_set
                else
                  Set.new
                end

        morph_data = parse_morph_data(morph)
        new(stem:, flags:, morph_data:)
      end

      # Split a dictionary line into stem and morphological-data portions.
      #
      # Hunspell specifies tab-separated morph data, but the ph.* test
      # fixtures use spaces. We honor both: if there's a tab, split there;
      # otherwise split before the first `key:value` token (which is the
      # universal signature of morphological data).
      #
      # @param line [String] The raw dictionary line
      # @return [Array(String, String)] [stem portion, morph portion]
      def self.split_stem_and_morph(line)
        tab_idx = line.index("\t")
        return line.split("\t", 2) if tab_idx

        match = line.match(/(.*?)(\s+[a-zA-Z]+:[^\s].*)$/)
        return [line, ''] unless match

        [match[1], match[2]]
      end

      # Parse morphological data from the post-tab portion of a dic line.
      #
      # Hunspell morphological data is whitespace-separated key:value tokens
      # such as `ph:wich` (phonetic), `st:foo` (stem), `po:noun` (part of
      # speech). We preserve them as a list of raw strings — downstream
      # consumers (e.g. PhonetSuggest via alt_spellings) extract what they
      # need.
      #
      # @param morph [String, nil] The morphological portion
      # @return [Array<String>] List of morphological tokens
      def self.parse_morph_data(morph)
        return [] if morph.nil?

        morph.split(/\s+/).reject(&:empty?)
      end

      # Parse flags from string.
      #
      # @param string [String] Flag string
      # @param flag_format [String] Flag format ('short', 'long', 'num', 'UTF-8')
      # @param flag_synonyms [Hash] Flag synonyms map
      # @return [Set<String>] Parsed flags
      def self.parse_flags(string, flag_format, flag_synonyms = {})
        return Set.new if string.nil? || string.empty?

        # AF (flag aliases) only applies when aliases are actually defined
        # and the string is a positional alias index (pure digits). Without
        # the !empty? guard, a `FLAG num` dictionary with no AF would have
        # every numeric flag collapsed to the empty set.
        if flag_synonyms.is_a?(Hash) && !flag_synonyms.empty? && string =~ /^\d+$/
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

      # Find the index of the first unescaped slash in the string.
      #
      # @param str [String] Input string
      # @return [Integer, nil] Index of first unescaped `/`, or nil
      def self.unescaped_slash_index(str)
        i = 0
        while i < str.length
          c = str[i]
          return i if c == '/' && (i.zero? || str[i - 1] != '\\')

          i += 1
        end
        nil
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
      # @param source [FileReader, nil] Optional file reader to use instead of creating a new one
      # @return [Array<Word>] List of word entries
      def read(source = nil)
        owned = source.nil?
        reader = source || FileReader.new(@path, @encoding)

        begin
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
        ensure
          # Close the reader only when we created it. If the caller passed
          # one in, they own its lifecycle. Without this, the underlying
          # File handle leaks (on Windows it also blocks tempfile cleanup).
          reader.close if owned
        end
      end
    end
  end
end
