# frozen_string_literal: true

require 'zip'

module Kotoshu
  # Unified Dictionary interface matching Spylls API.
  #
  # This class provides the main interface to Hunspell dictionaries,
  # supporting loading from files, zip archives, and system paths.
  #
  # @example Loading from files
  #   dictionary = Dictionary.from_files('/path/to/dictionary/en_US')
  #   dictionary.lookup('spells')  # => true
  #
  # @example Loading from zip archive
  #   dictionary = Dictionary.from_zip('/path/to/dictionary/en_US.odt')
  #
  # @example Loading from system
  #   dictionary = Dictionary.from_system('en_US')
  #
  # @example Getting suggestions
  #   dictionary.suggest('spylls')  # => ["spells", "spills", ...]
  #
  # @example Accessing algorithms for experimentation
  #   dictionary.lookuper.good_forms('building') do |form|
  #     puts form
  #   end
  class Dictionary
    # System paths to search for Hunspell dictionaries
    PATHES = [
      '/usr/share/hunspell',
      '/usr/share/myspell',
      '/usr/share/myspell/dicts',
      '/Library/Spelling',
      '/opt/openoffice.org/basis3.0/share/dict/ooo',
      '/usr/lib/openoffice.org/basis3.0/share/dict/ooo',
      '/opt/openoffice.org2.4/share/dict/ooo',
      '/usr/lib/openoffice.org2.4/share/dict/ooo',
      '/opt/openoffice.org2.3/share/dict/ooo',
      '/usr/lib/openoffice.org2.3/share/dict/ooo',
      '/opt/openoffice.org2.2/share/dict/ooo',
      '/usr/lib/openoffice.org2.2/share/dict/ooo',
      '/opt/openoffice.org2.1/share/dict/ooo',
      '/usr/lib/openoffice.org2.1/share/dict/ooo',
      '/opt/openoffice.org2.0/share/dict/ooo',
      '/usr/lib/openoffice.org2.0/share/dict/ooo'
    ].freeze

    # Distributed dictionaries for testing
    DISTRIBUTED = {
      'en_US' => 'en',
      'ru' => 'ru',
      'sv_SE' => 'sv'
    }.freeze

    # @return [Hash] Aff data structure
    attr_reader :aff

    # @return [Array<Readers::Word>] Dic data structure
    attr_reader :dic_words

    # @return [Algorithms::Lookup::Lookuper] Lookuper instance for experimentation
    attr_reader :lookuper

    # @return [Algorithms::Suggest::Suggester] Suggester instance for experimentation
    attr_reader :suggester

    # Create a Dictionary from aff and dic data.
    #
    # @param aff [Hash] Aff data structure
    # @param dic_words [Array<Readers::Word>] Dictionary word entries
    def initialize(aff, dic_words)
      @aff = aff
      @dic_words = dic_words

      # Create lookuper and suggester
      @lookuper = Readers::LookupBuilder.from_data(aff, dic_words).build
      @suggester = Algorithms::Suggest::Suggester.new(
        aff: aff,
        dic: build_dic_structure(dic_words),
        lookuper: @lookuper
      )
    end

    # Load dictionary from file path.
    #
    # The path should be the base name without extension, e.g., 'en_US'
    # for files 'en_US.aff' and 'en_US.dic'.
    #
    # @param path [String] Base path to dictionary files (without extension)
    # @return [Dictionary] The loaded dictionary
    #
    # @example
    #   Dictionary.from_files('en_US')
    def self.from_files(path)
      # Check if it's a distributed dictionary
      if DISTRIBUTED.key?(path) && !File.exist?("#{path}.aff")
        distributed_path = File.join(File.dirname(__FILE__), '../../data', DISTRIBUTED[path], path)
        if File.exist?("#{distributed_path}.aff")
          path = distributed_path
        end
      end

      aff_path = "#{path}.aff"
      dic_path = "#{path}.dic"

      raise ArgumentError, "Dictionary file not found: #{aff_path}" unless File.exist?(aff_path)
      raise ArgumentError, "Dictionary file not found: #{dic_path}" unless File.exist?(dic_path)

      # Read aff file
      aff_reader = Readers::AffReader.new(aff_path)
      aff_data = aff_reader.read

      # Read dic file
      dic_reader = Readers::DicReader.new(dic_path,
                                          flag_format: aff_data['FLAG'] || 'short',
                                          flag_synonyms: aff_data['AF'] || {})
      dic_words = dic_reader.read

      new(aff_data, dic_words)
    end

    # Load dictionary from zip archive.
    #
    # Supports OpenOffice/LibreOffice dictionary extensions (.odt, .oxt)
    # and Firefox/Thunderbird dictionary extensions (.xpi).
    #
    # @param zip_path [String] Path to zip archive
    # @return [Dictionary] The loaded dictionary
    #
    # @example
    #   Dictionary.from_zip('en_US.odt')
    def self.from_zip(zip_path)
      Zip::File.open(zip_path) do |zipfile|
        # Find .aff and .dic files
        aff_entry = nil
        dic_entry = nil

        zipfile.each do |entry|
          if entry.name.end_with?('.aff')
            raise ArgumentError, "Multiple .aff files found in zip" if aff_entry

            aff_entry = entry
          elsif entry.name.end_with?('.dic')
            raise ArgumentError, "Multiple .dic files found in zip" if dic_entry

            dic_entry = entry
          end
        end

        raise ArgumentError, "No .aff file found in zip" unless aff_entry
        raise ArgumentError, "No .dic file found in zip" unless dic_entry

        # Read aff file
        aff_reader = Readers::ZipReader.new(zipfile, aff_entry.name)
        aff_reader.to_a
        # Parse the raw data into proper aff structure
        Readers::AffReader.new(zip_path) # Temporary for context
        aff_data = Readers::AffReader.new(aff_entry.name).read

        # Read dic file
        dic_reader = Readers::DicReader.new(dic_entry.name,
                                            flag_format: aff_data['FLAG'] || 'short',
                                            flag_synonyms: aff_data['AF'] || {})
        dic_words = dic_reader.read

        new(aff_data, dic_words)
      end
    end

    # Load dictionary from system paths.
    #
    # Searches standard system locations for Hunspell dictionaries.
    #
    # @param name [String] Dictionary name (e.g., 'en_US', 'ru_RU')
    # @return [Dictionary] The loaded dictionary
    # @raise [ArgumentError] If dictionary not found in system paths
    #
    # @example
    #   Dictionary.from_system('en_US')
    def self.from_system(name)
      PATHES.each do |folder|
        aff_path = File.join(folder, "#{name}.aff")
        if File.exist?(aff_path)
          base_path = aff_path.sub(/\.aff$/, '')
          return from_files(base_path)
        end
      end

      raise ArgumentError, "#{name}.aff not found in system paths: #{PATHES.inspect}"
    end

    # Check if a word is correct.
    #
    # @param word [String] Word to check
    # @return [Boolean] True if the word exists in the dictionary
    #
    # @example
    #   dictionary.lookup('spells')  # => true
    #   dictionary.lookup('spylls')  # => false
    def lookup(word)
      @lookuper.call(word)
    end

    # Generate suggestions for a misspelled word.
    #
    # Returns suggestions in order of probability/similarity,
    # with best suggestions first.
    #
    # @param word [String] The misspelled word
    # @yield [String] Each suggestion
    # @return [Enumerator] If no block given
    #
    # @example
    #   dictionary.suggest('spylls')  # => ["spells", "spills", ...]
    def suggest(word, &)
      return enum_for(:suggest, word) unless block_given?

      @suggester.suggestions(word, &)
    end

    private

    # Build dic structure for suggester.
    #
    # @param dic_words [Array<Readers::Word>] Dictionary word entries
    # @return [Hash] Dic structure
    def build_dic_structure(dic_words)
      # Build a hash indexed by word for fast lookup
      word_index = Hash.new { |h, k| h[k] = [] }

      dic_words.each do |word|
        word_index[word.stem] << {
          stem: word.stem,
          flags: word.flags.to_a
        }
      end

      # Build the dic structure with homonyms callable
      {
        homonyms: ->(w) { word_index[w] || [] },
        has_flag: ->(w, flag, for_all: false) {
          entries = word_index[w] || []
          flags_present = entries.map { |e| e[:flags] }.flatten
          if for_all
            flags_present.all? { |flags| flags.include?(flag) }
          else
            flags_present.any? { |flags| flags.include?(flag) }
          end
        }
      }
    end
  end
end
