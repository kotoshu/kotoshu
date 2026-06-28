# frozen_string_literal: true

require_relative '../algorithms/lookup'
require_relative '../algorithms/capitalization'
require_relative 'aff_reader'
require_relative 'dic_reader'
require_relative 'condition_checker'

module Kotoshu
  module Readers
    # Builder for creating Lookup::Lookuper instances from Hunspell data.
    #
    # This class can either read from files or accept pre-read aff/dic data.
    #
    # @example Building a lookuper from files
    #   builder = LookupBuilder.new('en_US.aff', 'en_US.dic')
    #   lookuper = builder.build
    #
    # @example Building a lookuper from pre-read data
    #   aff_reader = AffReader.new('en_US.aff')
    #   aff_data = aff_reader.read
    #   dic_reader = DicReader.new('en_US.dic')
    #   words = dic_reader.read
    #   builder = LookupBuilder.from_data(aff_data, words)
    #   lookuper = builder.build
    class LookupBuilder
      # Hunspell upstream defaults for suggester directives. These apply
      # when the .aff file is silent on the directive. See the Hunspell
      # documentation at https://hunspell.github.io/ and the spylls
      # `Aff` defaults for reference.
      DEFAULT_MAX_NGRAM_SUGS = 4
      DEFAULT_MAX_CPD_SUGS = 3
      DEFAULT_MAX_DIFF = 5

      attr_reader :aff_path, :dic_path, :encoding, :aff_data, :words, :script

      # Create a new LookupBuilder from file paths.
      #
      # @param aff_path [String] Path to the .aff file
      # @param dic_path [String] Path to the .dic file
      # @param encoding [String] File encoding (default: 'UTF-8')
      # @param script [Symbol] The script type for condition checking (default: :latin)
      def initialize(aff_path, dic_path, encoding: 'UTF-8', script: :latin)
        @aff_path = aff_path
        @dic_path = dic_path
        @encoding = encoding
        @script = script
        @aff_data = nil
        @words = nil
      end

      # Create a new LookupBuilder from pre-read data.
      #
      # @param aff_data [Hash] Raw aff data from AffReader
      # @param words [Array<Word>] Word entries from DicReader
      # @return [LookupBuilder] A new builder instance
      def self.from_data(aff_data, words)
        builder = new(nil, nil)
        builder.instance_variable_set(:@aff_data, aff_data)
        builder.instance_variable_set(:@words, words)
        builder
      end

      # Build the Lookuper instance.
      #
      # @return [Algorithms::Lookup::Lookuper] The lookuper instance
      def build
        # Read files if data not already provided
        aff_data_to_use = @aff_data || read_aff_data
        words_to_use = @words || read_dic_data(aff_data_to_use)

        # Build the aff structure for Lookuper
        aff = build_aff_structure(aff_data_to_use)

        # Build the dic structure for Lookuper
        dic = build_dic_structure(words_to_use)

        # Create and return the Lookuper
        Algorithms::Lookup::Lookuper.new(aff, dic)
      end

      private

      # Read aff data from file.
      #
      # @return [Hash] Raw aff data
      def read_aff_data
        aff_reader = AffReader.new(@aff_path, encoding: @encoding)
        aff_reader.read
      end

      # Read dic data from file.
      #
      # @param aff_data [Hash] Aff data for flag format info
      # @return [Array<Word>] Word entries
      def read_dic_data(aff_data)
        dic_reader = DicReader.new(@dic_path,
                                   encoding: @encoding,
                                   flag_format: aff_data['FLAG'] || 'short',
                                   flag_synonyms: aff_data['AF'] || {})
        dic_reader.read
      end

      private

      # Build the aff data structure for Lookuper.
      #
      # @param aff_data [Hash] Raw aff data from AffReader
      # @return [Hash] Aff structure for Lookuper
      def build_aff_structure(aff_data)
        aff = {}

        # Capitalization handler - default to standard Casing
        # Could be extended to use TurkicCasing or GermanCasing based on LANG
        aff[:casing] = Algorithms::Capitalization::Casing.new

        # Build suffixes index (indexed by first character of reversed suffix)
        suffixes_index = {}
        aff_data['SFX'].each do |_flag, affix_list|
          affix_list.each do |affix|
            # For suffixes, we need to index by the first char of the REVERSED suffix
            # because the lookup code reverses the word to check suffixes
            reversed_suffix = affix.add.reverse
            first_char = reversed_suffix[0] || ''
            suffixes_index[first_char] ||= []
            suffixes_index[first_char] << build_affix_hash(affix, script: @script || :latin)
          end
        end
        aff[:suffixes_index] = suffixes_index

        # Build prefixes index (indexed by first character of prefix)
        prefixes_index = {}
        aff_data['PFX'].each do |_flag, affix_list|
          affix_list.each do |affix|
            first_char = affix.add[0] || ''
            prefixes_index[first_char] ||= []
            prefixes_index[first_char] << build_affix_hash(affix, script: @script || :latin)
          end
        end
        aff[:prefixes_index] = prefixes_index

        # Single-value flags
        aff[:COMPOUNDMIN] = aff_data['COMPOUNDMIN']
        aff[:COMPOUNDWORDMAX] = aff_data['COMPOUNDWORDMAX']
        aff[:COMPOUNDBEGIN] = aff_data['COMPOUNDBEGIN']
        aff[:COMPOUNDMIDDLE] = aff_data['COMPOUNDMIDDLE']
        aff[:COMPOUNDEND] = aff_data['COMPOUNDEND']
        aff[:COMPOUNDFLAG] = aff_data['COMPOUNDFLAG']
        aff[:COMPOUNDPERMITFLAG] = aff_data['COMPOUNDPERMITFLAG']
        aff[:COMPOUNDFORBIDFLAG] = aff_data['COMPOUNDFORBIDFLAG']
        aff[:COMPOUNDRULE] = build_compound_rules(aff_data['COMPOUNDRULE'])
        aff[:ONLYINCOMPOUND] = aff_data['ONLYINCOMPOUND']
        aff[:COMPLEXPREFIXES] = aff_data['COMPLEXPREFIXES']
        aff[:FORCEUCASE] = aff_data['FORCEUCASE']

        # Special flags
        aff[:FORBIDDENWORD] = aff_data['FORBIDDENWORD']
        aff[:NOSUGGEST] = aff_data['NOSUGGEST']
        aff[:KEEPCASE] = aff_data['KEEPCASE']
        aff[:NEEDAFFIX] = aff_data['NEEDAFFIX']
        aff[:CIRCUMFIX] = aff_data['CIRCUMFIX']
        aff[:WARN] = aff_data['WARN']

        # Compound checking flags
        aff[:CHECKCOMPOUNDCASE] = aff_data['CHECKCOMPOUNDCASE']
        aff[:CHECKCOMPOUNDDUP] = aff_data['CHECKCOMPOUNDDUP']
        aff[:CHECKCOMPOUNDREP] = aff_data['CHECKCOMPOUNDREP']
        aff[:CHECKCOMPOUNDTRIPLE] = aff_data['CHECKCOMPOUNDTRIPLE']
        aff[:CHECKCOMPOUNDPATTERN] = build_compound_patterns(aff_data['CHECKCOMPOUNDPATTERN'])
        aff[:SIMPLIFIEDTRIPLE] = aff_data['SIMPLIFIEDTRIPLE']

        # Other directives
        aff[:IGNORE] = aff_data['IGNORE']&.chars || []
        aff[:BREAK] = build_break_patterns(aff_data['BREAK'])
        aff[:ICONV] = aff_data['ICONV']
        aff[:OCONV] = aff_data['OCONV']
        aff[:REP] = build_rep_table(aff_data['REP'])
        aff[:MAP] = aff_data['MAP'] || []
        aff[:CHECKSHARPS] = aff_data['CHECKSHARPS']

        # Suggester directives (Hunspell defaults applied where the .aff
        # is silent — these defaults come from the upstream Hunspell
        # manual and match spylls' Aff.objects defaults).
        aff[:TRY] = aff_data['TRY']
        aff[:KEY] = aff_data['KEY']
        aff[:WORDCHARS] = aff_data['WORDCHARS']
        aff[:PHONE] = aff_data['PHONE']
        aff[:NOSPLITSUGS] = aff_data['NOSPLITSUGS']
        aff[:SUGSWITHDOTS] = aff_data['SUGSWITHDOTS']
        aff[:FULLSTRIP] = aff_data['FULLSTRIP']
        aff[:MAXNGRAMSUGS] = aff_data['MAXNGRAMSUGS'] || DEFAULT_MAX_NGRAM_SUGS
        aff[:MAXCPDSUGS] = aff_data['MAXCPDSUGS'] || DEFAULT_MAX_CPD_SUGS
        aff[:MAXDIFF] = aff_data['MAXDIFF'] || DEFAULT_MAX_DIFF
        aff[:ONLYMAXDIFF] = aff_data['ONLYMAXDIFF']

        aff
      end

      # Build the dic data structure for Lookuper.
      #
      # @param words [Array<Word>] List of word entries
      # @return [Hash] Dic structure for Lookuper
      def build_dic_structure(words)
        # Build a hash indexed by word for fast lookup
        word_index = Hash.new { |h, k| h[k] = [] }
        # Plain list of all word entries (used by Suggester for ngram).
        word_list = []

        words.each do |word|
          entry = {
            stem: word.stem,
            flags: word.flags.to_a
          }
          word_index[word.stem] << entry
          word_list << entry
        end

        # Build the dic structure with homonyms callable
        {
          words: word_list,
          homonyms: ->(word) { word_index[word] || [] },
          has_flag: ->(word, flag, for_all: false) {
            entries = word_index[word] || []
            flags_present = entries.map { |e| e[:flags] }.flatten
            if for_all
              flags_present.all? { |flags| flags.include?(flag) }
            else
              flags_present.any? { |flags| flags.include?(flag) }
            end
          }
        }
      end

      # Build an affix hash for Lookuper.
      #
      # @param affix [Affix] The affix object
      # @param script [Symbol] The script type for condition checking
      # @return [Hash] Affix hash for Lookuper
      def build_affix_hash(affix, script: :latin)
        {
          flag: affix.flag,
          crossproduct: affix.crossproduct,
          strip: affix.strip,
          affix: affix.add,
          condition_checker: compile_condition_matcher(affix.condition, script: script),
          affix_data: build_affix_transform(affix.strip, affix.add, type: affix.type),
          flags: affix.flags.to_a
        }
      end

      # Compile a condition checker.
      #
      # @param condition [String] Condition string from .aff file
      # @param script [Symbol] The script type (:latin, :arabic, etc.)
      # @return [ConditionChecker, nil] Compiled checker or nil
      def compile_condition_matcher(condition, script: :latin)
        return nil if condition.nil? || condition.empty?

        ConditionChecker.compile(condition, script: script)
      end

      # Build affix stripping data.
      #
      # Build affix transformation data.
      #
      # @param strip [String] Characters to strip
      # @param add [String] Characters to add
      # @param type [Symbol] :prefix or :suffix
      # @return [Hash] Hash with affix data for transformation
      def build_affix_transform(strip, add, type:)
        return nil if strip.empty? && add.empty?

        {
          add: add,
          strip: strip || '',
          type: type
        }
      end

      # Build compound rules array.
      #
      # @param rules [Array<CompoundRule>] List of compound rules
      # @return [Array<Hash>] Array of compound rule hashes
      def build_compound_rules(rules)
        return [] if rules.nil? || rules.empty?

        rules.map do |rule|
          {
            text: rule.text,
            flags: rule.flags,
            full_match: ->(flag_sets) { rule.fullmatch(flag_sets) },
            partial_match: ->(flag_sets) { rule.flags.intersect?(flag_sets.flatten.to_set) }
          }
        end
      end

      # Build compound patterns array.
      #
      # @param patterns [Array<CompoundPattern>] List of compound patterns
      # @return [Array<Hash>] Array of compound pattern hashes
      def build_compound_patterns(patterns)
        return [] if patterns.nil? || patterns.empty?

        patterns.map do |pattern|
          {
            match: ->(left, right) { pattern.match?(left, right) }
          }
        end
      end

      # Build break patterns array.
      #
      # @param break_patterns [Array<BreakPattern>] List of break patterns
      # @return [Array<Hash>] Array of break pattern hashes
      def build_break_patterns(break_patterns)
        return [] if break_patterns.nil? || break_patterns.empty?

        break_patterns.map do |bp|
          {
            pattern: bp.pattern,
            matcher: bp.matcher
          }
        end
      end

      # Build REP table for the Suggester.
      #
      # The Suggester's `replchars` permutation expects each entry as a
      # Hash with `:regexp` (a Regexp) and `:replacement` (a String).
      # AffReader returns `Readers::RepPattern` value objects; this
      # method adapts that representation without poking at the
      # RepPattern's internals — it uses the public accessors.
      #
      # @param rep_patterns [Array<RepPattern>, nil] REP entries
      # @return [Array<Hash{Symbol=>Object}>] REP table for Suggester
      def build_rep_table(rep_patterns)
        return [] if rep_patterns.nil? || rep_patterns.empty?

        rep_patterns.map do |rp|
          {
            regexp: rp.matcher,
            pattern: rp.pattern,
            replacement: rp.replacement
          }
        end
      end
    end
  end
end
