# frozen_string_literal: true

require "open-uri"
require_relative "base"
require_relative "../readers/lookup_builder"
require_relative "../readers/aff_reader"
require_relative "../readers/dic_reader"

module Kotoshu
  module Dictionary
    # Hunspell dictionary backend.
    #
    # This dictionary reads Hunspell-formatted dictionary files (.dic and .aff).
    # Hunspell is the spell checker used by LibreOffice, Firefox, Chrome, and many
    # other applications.
    #
    # File format:
    # - .dic: Dictionary file with word count on first line, words with optional flags
    # - .aff: Affix file with prefix/suffix rules and configuration
    #
    # @example Creating a Hunspell dictionary
    #   dict = Hunspell.new(
    #     dic_path: "en_US.dic",
    #     aff_path: "en_US.aff",
    #     language_code: "en-US"
    #   )
    #   dict.lookup?("hello")  # => true
    #
    # @example Creating from GitHub cache
    #   dict = Hunspell.from_github("de")
    #   dict.lookup?("über")  # => true
    #
    # @see https://hunspell.github.io/ Hunspell documentation
    class Hunspell < Base
      # @return [String] Path to the .dic file
      attr_reader :dic_path

      # @return [String] Path to the .aff file
      attr_reader :aff_path

      # @return [Hash] Affix rules (flag => array of rules)
      attr_reader :affix_rules

      # @return [Hash] Configuration options from affix file
      attr_reader :aff_config

      # @return [Hash] Raw aff data from AffReader (cached for Lookuper)
      attr_reader :aff_data

      # @return [Array] Raw words from DicReader (cached for Lookuper)
      attr_reader :dic_words

      # @return [Algorithms::Lookup::Lookuper] The lookup algorithm instance
      def lookuper
        @lookuper ||= Readers::LookupBuilder.from_data(@aff_data, @dic_words).build
      end

      # @return [Algorithms::Suggest::Suggester] The suggestion algorithm instance
      def suggester
        @suggester ||= Algorithms::Suggest::Suggester.new(
          lookuper.aff, lookuper.dic, lookuper
        )
      end

      class << self
        # Load Hunspell dictionary from GitHub cache, downloading if necessary.
        #
        # This class method provides automatic dictionary management by:
        # 1. Checking the local cache for existing dictionaries
        # 2. Downloading from GitHub if not cached or expired
        # 3. Managing cache metadata and TTL
        #
        # @example Load English dictionary
        #   dict = Hunspell.from_github("en")
        #   dict.lookup?("hello")  # => true
        #
        # @example Load German dictionary
        #   dict = Hunspell.from_github("de")
        #   dict.lookup?("über")  # => true
        #
        # @example Force re-download
        #   dict = Hunspell.from_github("fr", force_download: true)
        #
        # @param language_code [String] ISO 639-1 language code (e.g., 'en', 'de', 'fr')
        # @param cache [Cache::LanguageCache, nil] Custom cache instance (optional)
        # @param force_download [Boolean] Force re-download even if cached
        # @return [Hunspell] Configured Hunspell dictionary instance
        # @raise [ArgumentError] If language_code is not supported
        def from_github(language_code, cache: nil, force_download: false)
          require_relative '../cache/language_cache'

          cache ||= Cache::LanguageCache.new
          cached = cache.get_dictionary(language_code, force_download: force_download)

          new(
            dic_path: cached[:dic_path],
            aff_path: cached[:aff_path],
            language_code: language_code,
            metadata: {
              source: 'github',
              github_url: cached[:metadata]['url'],
              checksum: cached[:metadata]['checksum'],
              downloaded_at: cached[:metadata]['downloaded_at']
            }
          )
        end

        # Check if a language is available on GitHub.
        #
        # @param language_code [String] ISO 639-1 language code
        # @param cache [Cache::LanguageCache, nil] Custom cache instance (optional)
        # @return [Boolean] True if language is supported
        def available_on_github?(language_code, cache: nil)
          require_relative '../cache/language_cache'

          cache ||= Cache::LanguageCache.new
          cache.available_languages.include?(language_code)
        end

        # Get list of available languages on GitHub.
        #
        # @param cache [Cache::LanguageCache, nil] Custom cache instance (optional)
        # @return [Array<String>] List of supported language codes
        def available_github_languages(cache: nil)
          require_relative '../cache/language_cache'

          cache ||= Cache::LanguageCache.new
          cache.available_languages
        end

        # Get information about a language from GitHub.
        #
        # @param language_code [String] ISO 639-1 language code
        # @param cache [Cache::LanguageCache, nil] Custom cache instance (optional)
        # @return [Hash] Language information
        def language_info(language_code, cache: nil)
          require_relative '../cache/language_cache'

          cache ||= Cache::LanguageCache.new
          cache.get_language_info(language_code)
        end
      end

      # Create a new Hunspell dictionary.
      #
      # @param dic_path [String] Path or URL to the .dic file
      # @param aff_path [String] Path or URL to the .aff file
      # @param language_code [String] The language code
      # @param locale [String, nil] The locale (optional)
      # @param metadata [Hash] Additional metadata (optional)
      def initialize(dic_path:, aff_path:, language_code:, locale: nil, metadata: {})
        super(language_code, locale: locale, metadata: metadata)

        @dic_path = resolve_path(dic_path)
        @aff_path = resolve_path(aff_path)

        raise DictionaryNotFoundError, @aff_path unless File.exist?(@aff_path)
        raise DictionaryNotFoundError, @dic_path unless File.exist?(@dic_path)

        # Read aff file using AffReader and cache the data
        aff_reader = Readers::AffReader.new(@aff_path)
        @aff_data = aff_reader.read
        @aff_config = @aff_data  # For backward compatibility

        # Read dic file using DicReader with the same encoding as the aff file
        dic_reader = Readers::DicReader.new(@dic_path,
                                             encoding: aff_reader.encoding,
                                             flag_format: @aff_data['FLAG'] || 'short',
                                             flag_synonyms: @aff_data['AF'] || {})
        @dic_words = dic_reader.read

        # Build legacy structures for backward compatibility
        @word_index = build_word_index(@dic_words)
        @affix_rules = parse_affix_rules(@aff_config)

        # Lazy initialization of Lookuper (only created when needed)
        @lookuper = nil

        # Register this dictionary type
        self.class.register_type(:hunspell) unless Dictionary.registry.key?(:hunspell)
      end

      private

      # Build word index from DicReader words.
      #
      # @param words [Array<Readers::Word>] Words from DicReader
      # @return [Hash] Word index (word => flags)
      def build_word_index(words)
        index = {}
        words.each do |word|
          index[word.stem.downcase] = word.flags.to_a
        end
        index
      end

      # Parse affix rules from AffReader data.
      #
      # @param aff_data [Hash] Aff data from AffReader
      # @return [Hash] Affix rules by type
      def parse_affix_rules(aff_data)
        rules = {
          prefix: Hash.new { |h, k| h[k] = [] },
          suffix: Hash.new { |h, k| h[k] = [] }
        }

        # Convert AffReader's SFX/PFX data to legacy format
        # AffReader returns: 'SFX' => { flag => [Affix, ...] }
        # We need to convert each Affix to Models::AffixRule

        aff_data['SFX']&.each do |flag, affix_list|
          rules[:suffix][flag] = affix_list.map do |affix|
            convert_to_affix_rule(affix, :suffix)
          end
        end

        aff_data['PFX']&.each do |flag, affix_list|
          rules[:prefix][flag] = affix_list.map do |affix|
            convert_to_affix_rule(affix, :prefix)
          end
        end

        rules
      end

      # Convert AffReader Affix to Models::AffixRule.
      #
      # @param affix [Readers::Affix] The affix to convert
      # @param type [Symbol] :prefix or :suffix
      # @return [Models::AffixRule] The converted rule
      def convert_to_affix_rule(affix, type)
        # Create a simple string representation for from_hunspell
        # Format: PFX/SFX FLAG crossproduct strip add condition
        cross_str = affix.crossproduct ? 'Y' : 'N'
        strip_str = affix.strip.empty? ? '0' : affix.strip
        add_str = affix.add.empty? ? '0' : affix.add
        condition_str = affix.condition || '.'

        type_str = type == :prefix ? 'PFX' : 'SFX'
        rule_line = "#{type_str} #{affix.flag} #{cross_str} #{strip_str} #{add_str} #{condition_str}"

        Models::AffixRule.from_hunspell(rule_line, type)
      end

      # Check if path is a URL
      # @param path [String] Path to check
      # @return [Boolean] True if path is a URL
      def url?(path)
        path.start_with?("http://", "https://")
      end

      # Resolve path to local file path (downloading if URL)
      # @param path [String] Path or URL
      # @return [String] Local file path
      def resolve_path(path)
        return File.expand_path(path) unless url?(path)

        download_to_temp(path)
      end

      # Download URL to temporary file
      # @param url [String] URL to download
      # @return [String] Temporary file path
      def download_to_temp(url)
        require "tempfile"

        uri = URI.parse(url)
        filename = File.basename(uri.path)

        temp = Tempfile.new([filename, ""], encoding: "UTF-8")
        temp.binmode

        URI.open(uri, "rb") do |remote_file|
          IO.copy_stream(remote_file, temp)
        end

        temp.close
        temp.path
      end

      public

      # Check if a word exists in the dictionary.
      #
      # Uses the Lookup::Lookuper algorithm for full affix and compound support.
      #
      # @param word [String] The word to look up
      # @return [Boolean] True if the word exists
      def lookup(word)
        return false if word.nil? || word.empty?

        # Use the Lookuper for full Hunspell algorithm support
        lookuper.call(word)
      end

      # Generate spelling suggestions.
      #
      # Uses Algorithms::Suggest::Suggester for full Hunspell-compatible
      # suggestion generation (edits, REP, MAP, KEY, TRY, ngram, phonetic).
      #
      # @param word [String] The misspelled word
      # @param max_suggestions [Integer] Maximum suggestions
      # @return [Array<String>] List of suggested words
      def suggest(word, max_suggestions: 10)
        return [] if word.nil? || word.empty?

        suggester.call(word).first(max_suggestions)
      end

      # Add a word to the dictionary.
      #
      # @param word [String] The word to add
      # @param flags [Array<String>] Morphological flags
      # @return [Boolean] True if added
      def add_word(word, flags: [])
        return false if word.nil? || word.empty?

        word_key = word.downcase
        @word_index[word_key] = flags

        true
      end

      # Remove a word from the dictionary.
      #
      # @param word [String] The word to remove
      # @return [Boolean] True if removed
      def remove_word(word)
        return false if word.nil? || word.empty?

        word_key = word.downcase
        !@word_index.delete(word_key).nil?
      end

      # Get all words in the dictionary.
      #
      # @return [Array<String>] All words
      def words
        @word_index.keys.dup
      end

      # Get word variants using affix rules.
      #
      # @param word [String] The word
      # @return [Array<String>] Word variants
      def word_variants(word)
        return [] if word.nil? || word.empty?

        variants = []

        # Get flags for this word (if any)
        word_key = word.downcase
        flags = @word_index[word_key] || []

        # Generate prefix variants
        @affix_rules[:prefix].each do |flag, rules|
          next unless flags.include?(flag)

          rules.each do |rule|
            variant = rule.apply(word)
            variants << variant if variant
          end
        end

        # Generate suffix variants
        @affix_rules[:suffix].each do |flag, rules|
          next unless flags.include?(flag)

          rules.each do |rule|
            variant = rule.apply(word)
            variants << variant if variant
          end
        end

        variants
      end

      private

      # Load the dictionary file.
      #
      # @param path [String] Path to .dic file
      # @return [Hash] Word index (word => flags)
      def load_dic_file(path)
        index = {}
        lines = File.readlines(path, chomp: true)

        # First line is word count
        return index if lines.empty?

        # Parse remaining lines
        lines[1..].each do |line|
          next if line.empty? || line.start_with?("#") || line.strip.empty?

          parts = line.split("/")
          word = parts[0]

          # Skip if word is nil or empty after stripping
          next if word.nil? || word.strip.empty?

          word = word.strip
          flags = parts[1] ? parts[1].split("") : []

          index[word.downcase] = flags
        end

        index
      end

      # Load the affix file.
      #
      # @param path [String] Path to .aff file
      # @return [Hash] Configuration options
      def load_aff_file(path)
        config = {
          set: "UTF-8",
          try: "",
          flag: "char", # or "long" or "num"
          affix_rules: []
        }

        File.foreach(path, chomp: true) do |line|
          next if line.empty? || line.start_with?("#")

          parts = line.split
          next if parts.empty?

          keyword = parts[0].upcase

          case keyword
          when "SET"
            config[:set] = parts[1]
          when "TRY"
            config[:try] = parts[1]
          when "FLAG"
            config[:flag] = parts[1]
          when "PFX", "SFX"
            config[:affix_rules] << line
          when "REP", "MAP", "COMPOUNDRULE", "COMPOUNDWORDMIN", "COMPOUNDFLAG"
            # Store for future use
            config[keyword.downcase.to_sym] ||= []
            config[keyword.downcase.to_sym] << line
          end
        end

        config
      end

      # Direct lookup without affix processing.
      #
      # @param word [String] The word
      # @return [Boolean] True if word exists
      def direct_lookup?(word)
        word_key = word.downcase
        @word_index.key?(word_key)
      end

      # Generate all possible affix variants.
      #
      # @return [Array<String>] All variants
      def generate_affix_variants
        variants = []

        @affix_rules[:prefix].each do |flag, rules|
          rules.each do |rule|
            @word_index.each do |word, flags|
              next unless flags.include?(flag)

              variant = rule.apply(word)
              variants << variant if variant
            end
          end
        end

        @affix_rules[:suffix].each do |flag, rules|
          rules.each do |rule|
            @word_index.each do |word, flags|
              next unless flags.include?(flag)

              variant = rule.apply(word)
              variants << variant if variant
            end
          end
        end

        variants.uniq
      end

      # Calculate Levenshtein edit distance.
      #
      # @param str1 [String] First string
      # @param str2 [String] Second string
      # @return [Integer] Edit distance
      def edit_distance(str1, str2)
        return str2.length if str1.empty?
        return str1.length if str2.empty?

        # Use smaller string for inner loop
        str1, str2 = str2, str1 if str1.length > str2.length

        previous = (0..str1.length).to_a

        str2.each_char.with_index do |char2, j|
          current = [j + 1]

          str1.each_char.with_index do |char1, i|
            insert_cost = current[i] + 1
            delete_cost = previous[i + 1] + 1
            substitute_cost = previous[i] + (char1 == char2 ? 0 : 1)

            current << [insert_cost, delete_cost, substitute_cost].min
          end

          previous = current
        end

        previous.last
      end
    end
  end
end
