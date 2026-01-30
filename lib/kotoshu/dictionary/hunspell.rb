# frozen_string_literal: true

require_relative "base"
require_relative "../core/exceptions"
require_relative "../core/models/affix_rule"
require "open-uri"

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

        @aff_config = load_aff_file(@aff_path)
        @word_index = load_dic_file(@dic_path)
        @affix_rules = parse_affix_rules(@aff_config)

        # Register this dictionary type
        self.class.register_type(:hunspell) unless Dictionary.registry.key?(:hunspell)
      end

      private

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
      # @param word [String] The word to look up
      # @return [Boolean] True if the word exists
      def lookup(word)
        return false if word.nil? || word.empty?

        # Direct lookup
        return true if direct_lookup?(word)

        # Check affix variants
        word_variants(word).any? { |variant| direct_lookup?(variant) }
      end

      # Generate spelling suggestions.
      #
      # @param word [String] The misspelled word
      # @param max_suggestions [Integer] Maximum suggestions
      # @return [Array<String>] List of suggested words
      def suggest(word, max_suggestions: 10)
        return [] if word.nil? || word.empty?

        all_words = @word_index.keys + generate_affix_variants
        lookup_word = word.downcase

        # Find words with same prefix
        prefix_len = [lookup_word.length - 1, 2].max
        prefix = lookup_word[0...prefix_len]
        candidates = all_words.select { |w| w.downcase.start_with?(prefix) }

        # Calculate edit distances
        results = candidates.map do |dict_word|
          dist = edit_distance(lookup_word, dict_word.downcase)
          [dict_word, dist]
        end.select { |_, dist| dist > 0 && dist <= 2 }
         .sort_by { |_, dist| dist }
         .first(max_suggestions)
         .map(&:first)

        results
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
        @word_index.delete(word_key) != nil
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
          flag: "char",  # or "long" or "num"
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

      # Parse affix rules from configuration.
      #
      # @param config [Hash] Affix configuration
      # @return [Hash] Affix rules by type
      def parse_affix_rules(config)
        rules = {
          prefix: Hash.new { |h, k| h[k] = [] },
          suffix: Hash.new { |h, k| h[k] = [] }
        }

        rule_buffer = {}

        config[:affix_rules].each do |rule_line|
          parts = rule_line.split
          next if parts.length < 3

          type = parts[0]
          flag = parts[1]
          cross_product = parts[2] == "Y"
          rule_count = parts[3].to_i

          if rule_count.zero?
            # Header line - clear buffer for this flag
            type_sym = type == "PFX" ? :prefix : :suffix
            rule_buffer[flag] = { type: type_sym, cross_product: cross_product, rules: [] }
          else
            # Rule line
            next unless rule_buffer[flag]

            affix_rule = Models::AffixRule.from_hunspell(rule_line, rule_buffer[flag][:type])
            rule_buffer[flag][:rules] << affix_rule
          end
        end

        # Organize rules by type and flag
        rule_buffer.each do |flag, data|
          rules[data[:type]][flag] = data[:rules]
        end

        rules
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
        if str1.length > str2.length
          str1, str2 = str2, str1
        end

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
