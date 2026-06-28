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

        # Build the dic structure for Lookuper. Dictionary `ph:` morph data
        # is a source of REP entries (Hunspell 1.7+), so build_dic_structure
        # also enriches aff[:REP] — see PhRepExtractor.
        dic = build_dic_structure(words_to_use, aff: aff)

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

      # Select the appropriate Casing class based on the aff file's directives.
      #
      # Hunspell associates a casing strategy with the language declared via
      # LANG or with specific directives like CHECKSHARPS (German ß↔SS) and
      # Turkic languages (i↔İ / ı↔I). We mirror that here.
      def select_casing(aff_data)
        lang = aff_data['LANG'].to_s.downcase

        if aff_data['CHECKSHARPS']
          Algorithms::Capitalization::GermanCasing.new
        elsif lang.start_with?('tr', 'az', 'crh', 'tt', 'krc', 'kaa')
          Algorithms::Capitalization::TurkicCasing.new
        elsif lang.start_with?('de')
          Algorithms::Capitalization::GermanCasing.new
        else
          Algorithms::Capitalization::Casing.new
        end
      end

      # Build the aff data structure for Lookuper.
      #
      # @param aff_data [Hash] Raw aff data from AffReader
      # @return [Hash] Aff structure for Lookuper
      def build_aff_structure(aff_data)
        aff = {}

        # Capitalization handler — German when CHECKSHARPS is set (the
        # German ß↔SS rule needs special handling: lower("STRASSE") yields
        # both "straße" and "strasse"), Turkic when LANG starts with az/tr,
        # otherwise the standard Casing.
        aff[:casing] = select_casing(aff_data)

        # IGNORE chars (as Array<String>) — applied to dictionary stems
        # and affix `add` strings at read time so input lookups (which
        # strip IGNORE from the query) match. Without this, prefix "re" +
        # stem "expression" could never match input "reexpression" once
        # the input is reduced to "rxprssn".
        ignore_chars = aff_data['IGNORE']&.chars&.chars || []

        # Build suffixes index (indexed by first character of reversed suffix)
        suffixes_index = {}
        suffixes_by_flag = Hash.new { |h, k| h[k] = [] }
        aff_data['SFX'].each do |_flag, affix_list|
          affix_list.each do |affix|
            stripped_add = strip_ignore(affix.add, ignore_chars)
            # For suffixes, we need to index by the first char of the REVERSED suffix
            # because the lookup code reverses the word to check suffixes
            reversed_suffix = stripped_add.reverse
            first_char = reversed_suffix[0] || ''
            suffixes_index[first_char] ||= []
            affix_hash = build_affix_hash(affix, script: @script || :latin,
                                                add: stripped_add)
            suffixes_index[first_char] << affix_hash
            suffixes_by_flag[affix.flag] << affix_hash
          end
        end
        aff[:suffixes_index] = suffixes_index
        aff[:suffixes_by_flag] = suffixes_by_flag

        # Build prefixes index (indexed by first character of prefix)
        prefixes_index = {}
        prefixes_by_flag = Hash.new { |h, k| h[k] = [] }
        aff_data['PFX'].each do |_flag, affix_list|
          affix_list.each do |affix|
            stripped_add = strip_ignore(affix.add, ignore_chars)
            first_char = stripped_add[0] || ''
            prefixes_index[first_char] ||= []
            affix_hash = build_affix_hash(affix, script: @script || :latin,
                                                add: stripped_add)
            prefixes_index[first_char] << affix_hash
            prefixes_by_flag[affix.flag] << affix_hash
          end
        end
        aff[:prefixes_index] = prefixes_index
        aff[:prefixes_by_flag] = prefixes_by_flag

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
        aff[:IGNORE] = aff_data['IGNORE']&.chars&.chars || []
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
      # Two stem indexes are maintained, mirroring Spylls's `Dic.index` and
      # `Dic.lowercase_index`:
      #
      # * `word_index` — keyed by the exact stem as it appears in the .dic file.
      # * `lowercase_word_index` — keyed by the lowercased stem. Hunspell's
      #   ALLCAPS lookup path uses this to find dictionary entries whose stem
      #   casing doesn't match (e.g. querying "unicef" against a "UNICEF" entry).
      #
      # As a side effect, dictionary `ph:` morph data is folded into the
      # aff[:REP] table — Hunspell 1.7+ exposes `ph:` as additional REP
      # patterns so the existing replchars permutation surfaces them. See
      # {PhRepExtractor} for the three supported forms.
      #
      # @param words [Array<Word>] List of word entries
      # @param aff [Hash] Aff structure being built (mutated to add REP)
      # @return [Hash] Dic structure for Lookuper
      def build_dic_structure(words, aff:)
        word_index = Hash.new { |h, k| h[k] = [] }
        lowercase_index = Hash.new { |h, k| h[k] = [] }
        word_list = []
        casing = aff[:casing]
        ignore_chars = aff[:IGNORE] || []

        words.each do |word|
          ph_tokens = ph_tokens_from(word.morph_data)
          # Hunspell applies IGNORE at read time: any char listed in IGNORE
          # is stripped from dictionary stems so that input words with the
          # same char removed (done in Lookuper#call) match. Without this,
          # the `ignore` fixture's "expression" would never match a dict
          # entry of "expression" — both need to be reduced to "exprssn".
          stem = ignore_chars.any? ? strip_ignore(word.stem, ignore_chars) : word.stem
          entry = {
            stem: stem,
            flags: word.flags.to_a,
            alt_spellings: PhRepExtractor.simple_alt_spellings(stem, ph_tokens)
          }
          word_index[stem] << entry
          word_list << entry

          # The lowercase index mirrors Spylls's `Dic.lowercase_index`:
          # only words whose casing is not NO (i.e. INIT/ALL/HUH/HUHINIT)
          # contribute a lowercased key, because a NO-cased word's stem is
          # already its own lowercase form and would just duplicate the
          # exact-stem index entry.
          captype = casing.guess(stem)
          if captype != Algorithms::Capitalization::Type::NO
            casing.lower(stem).each do |lowered|
              lowercase_index[lowered] << entry
            end
          end

          PhRepExtractor.append_to_aff(aff, stem, ph_tokens)
        end

        {
          words: word_list,
          homonyms: ->(w, ignorecase: false) {
            if ignorecase
              lowercase_index[w] || []
            else
              word_index[w] || []
            end
          },
          has_flag: ->(w, flag, for_all: false) {
            entries = word_index[w] || []
            # Spylls's `Dic.has_flag` returns False when there are no homonyms
            # at all — a vacuous `for_all: true` would otherwise block the
            # caller (e.g. the FORBIDDENWORD guard in Lookuper#call) on
            # words whose case doesn't match the dictionary entry.
            return false if entries.empty?

            if for_all
              entries.all? { |e| (e[:flags] || []).include?(flag) }
            else
              entries.any? { |e| (e[:flags] || []).include?(flag) }
            end
          }
        }
      end

      # Select only the `ph:` morphological tokens.
      #
      # @param morph_data [Array<String>, nil] Morphological tokens
      # @return [Array<String>] Raw `ph:` payloads (with the `ph:` prefix stripped)
      def ph_tokens_from(morph_data)
        return [] if morph_data.nil? || morph_data.empty?

        morph_data.filter_map { |token| token[3..] if token.start_with?('ph:') }
      end

      # Remove IGNORE chars from a string. Mirrors Spylls's
      # `word.translate(ignore.tr)` — used at read time for both stems and
      # affix `add` strings so that lookups (which strip IGNORE from the
      # input) match.
      #
      # @param str [String] Input string
      # @param ignore_chars [Array<String>] Chars to remove
      # @return [String] String with ignored chars removed
      def strip_ignore(str, ignore_chars)
        return str if ignore_chars.empty?

        str.chars.reject { |c| ignore_chars.include?(c) }.join
      end

      # Build an affix hash for Lookuper.
      #
      # @param affix [Affix] The affix object
      # @param script [Symbol] The script type for condition checking
      # @param add [String, nil] Pre-stripped `add` string (IGNORE chars
      #   removed). When nil, the affix's raw `add` is used.
      # @return [Hash] Affix hash for Lookuper
      def build_affix_hash(affix, script: :latin, add: nil)
        add ||= affix.add
        {
          flag: affix.flag,
          crossproduct: affix.crossproduct,
          strip: affix.strip,
          affix: add,
          condition_checker: compile_condition_matcher(affix.condition,
                                                       script: script,
                                                       type: affix.type),
          affix_data: build_affix_transform(affix.strip, add, type: affix.type),
          flags: affix.flags.to_a
        }
      end

      # Compile a condition checker.
      #
      # Hunspell conditions are anchored: for suffixes the matcher checks
      # the END of the stem (e.g. `[^y]$`), for prefixes the START
      # (e.g. `^ij`). Without this distinction, prefix conditions silently
      # never match — Dutch "ijs" with PFX condition `ij` would never get
      # its prefix applied, so "IJs" wouldn't surface.
      #
      # @param condition [String] Condition string from .aff file
      # @param script [Symbol] The script type (:latin, :arabic, etc.)
      # @param type [Symbol] :prefix or :suffix (anchor direction)
      # @return [ConditionChecker, nil] Compiled checker or nil
      def compile_condition_matcher(condition, script: :latin, type: :suffix)
        return nil if condition.nil? || condition.empty?

        ConditionChecker.compile(condition, script: script, type: type)
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
            partial_match: ->(flag_sets) { rule.partial_match(flag_sets) }
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
      # Spylls's default BREAK is `['-', '^-', '-$']` (applied when the
      # directive is absent). If the .aff file says `BREAK 0` explicitly,
      # the result must be EMPTY — `BREAK 0` is the documented way to
      # disable hyphen breaking. The reader signals "absent" with nil and
      # "explicit zero" with [], so we branch on nil here.
      #
      # @param break_patterns [Array<BreakPattern>, nil] List of break patterns
      # @return [Array<Hash>] Array of break pattern hashes
      def build_break_patterns(break_patterns)
        if break_patterns.nil?
          return [
            { pattern: '-', matcher: BreakPattern.new('-').matcher },
            { pattern: '^-', matcher: BreakPattern.new('^-').matcher },
            { pattern: '-$', matcher: BreakPattern.new('-$').matcher }
          ]
        end

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

    # Extracts REP entries from dictionary `ph:` morphological data.
    #
    # Hunspell 1.7+ treats `ph:` as a phonetic misspelling hint and reuses
    # the existing replchars permutation to surface corrections. To make
    # that work, `ph:` payloads are converted to REP entries at dic-read
    # time. Three payload forms are recognised (mirroring Spylls/Hunspell):
    #
    # * simple — `ph:wich` against stem "which" yields REP(`wich`,
    #   `which`) and registers `wich` as an alt_spelling for ngram
    #   scoring.
    # * star — `ph:prity*` against stem "pretty" yields REP(`prit`,
    #   `prett`): the trailing char of the pattern (and the `*`) is
    #   stripped, and the trailing char of the stem is stripped, so the
    #   REP entry can attach suffixes on either side (matches "prity" →
    #   "pretty" and "pritiest" → "prettiest").
    # * arrow — `ph:hepi->happi` is an explicit pair: REP(`hepi`,
    #   `happi`). The stem is irrelevant for arrow form.
    #
    # The class is a pure transformer; side effects on the aff hash are
    # performed by the caller via {append_to_aff}.
    module PhRepExtractor
      module_function

      # Return only the *simple* payloads — the ones that double as
      # alt_spellings for ngram scoring. Star and arrow forms are excluded
      # because their REP entries don't map 1:1 to the stem and would
      # mislead ngram.
      #
      # @param stem [String] Dictionary stem (unused, present for symmetry)
      # @param ph_tokens [Array<String>] Raw `ph:` payloads
      # @return [Array<String>] Simple alt spellings
      def simple_alt_spellings(_stem, ph_tokens)
        ph_tokens.reject { |token| token.end_with?('*') || token.include?('->') }
      end

      # Convert each `ph:` payload into a {RepPattern} and append it to
      # `aff[:REP]`. Mutates the aff hash.
      #
      # @param aff [Hash] Aff structure (mutated)
      # @param stem [String] Dictionary stem
      # @param ph_tokens [Array<String>] Raw `ph:` payloads
      # @return [void]
      def append_to_aff(aff, stem, ph_tokens)
        return if ph_tokens.nil? || ph_tokens.empty?

        aff[:REP] ||= []
        ph_tokens.each do |token|
          rep = build_rep(stem, token)
          aff[:REP] << rep_hash(rep) if rep
        end
      end

      # Build a RepPattern from a single `ph:` payload.
      #
      # @param stem [String] Dictionary stem
      # @param token [String] Raw `ph:` payload
      # @return [RepPattern, nil]
      def build_rep(stem, token)
        if token.end_with?('*')
          star_rep(stem, token)
        elsif token.include?('->')
          arrow_rep(token)
        else
          simple_rep(stem, token)
        end
      end

      # Convert a RepPattern to the Hash shape used by Permutations.replchars.
      #
      # @param rep [RepPattern]
      # @return [Hash{Symbol=>Object}]
      def rep_hash(rep)
        {
          regexp: rep.matcher,
          pattern: rep.pattern,
          replacement: rep.replacement
        }
      end

      # `ph:prity*` (against stem "pretty") → REP(`prit`, `prett`).
      #
      # Strip the last two chars of the pattern (`y*`) and the last char
      # of the stem (`y`), so affixed forms on either side can match.
      #
      # @param stem [String] Dictionary stem
      # @param token [String] Star-form payload (e.g. `prity*`)
      # @return [RepPattern, nil] `nil` if pattern or stem too short
      def star_rep(stem, token)
        pattern = token[0...-2]
        replacement = stem[0...-1]
        return nil if pattern.empty? || replacement.empty?

        RepPattern.new(pattern, replacement)
      end

      # `ph:hepi->happi` → REP(`hepi`, `happi`).
      #
      # @param token [String] Arrow-form payload
      # @return [RepPattern, nil] `nil` if either side is empty
      def arrow_rep(token)
        from, to = token.split('->', 2)
        return nil if from.nil? || to.nil? || from.empty? || to.empty?

        RepPattern.new(from, to)
      end

      # `ph:wich` (against stem "which") → REP(`wich`, `which`).
      #
      # @param stem [String] Dictionary stem
      # @param token [String] Simple payload
      # @return [RepPattern, nil] `nil` if pattern is empty
      def simple_rep(stem, token)
        return nil if token.empty?

        RepPattern.new(token, stem)
      end
    end
  end
end
