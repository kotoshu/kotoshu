# frozen_string_literal: true

module Kotoshu
  module Algorithms
    # Main "is this word correct?" algorithm implementation.
    #
    # Ported from Spylls (Python) lookup.py
    #
    # On a bird's-eye view level:
    # * Word correctness check is an attempt to analyze word form
    #   (maybe it has this suffix? maybe it has this prefix? maybe it
    #    consists of several words?)
    # * The word is considered correct if at least one form is found that
    #   has valid suffixes/prefixes from .aff file and valid stem from
    #   .dic file, and they are all compatible with each other.
    #
    # To follow algorithm details, start reading from Lookup.call method.
    module Lookup
      autoload :CompoundChecks, "kotoshu/algorithms/lookup/compound_checks"
      autoload :AffixForm, "kotoshu/algorithms/lookup/affix_form"
      autoload :CompoundForm, "kotoshu/algorithms/lookup/compound_form"

      NUMBER_REGEXP = /^\d+(\.\d+)?$/

      # Position of word part in compound word.
      #
      # Used when checking whether a word could be part of a compound
      # (specifically its begin/middle/end).
      module CompoundPos
        BEGIN_POS = :begin
        MIDDLE = :middle
        END_POS = :end
      end

      # Main word correctness lookup class.
      #
      # Typically, you would not use this directly.
      #
      # Example:
      #   dictionary = Kotoshu::Dictionary.load('en_US')
      #   lookuper = dictionary.lookuper
      #
      #   lookuper.call('spylls')  # => false
      #   lookuper.call('spells')  # => true
      #
      #   lookuper.good_forms('spells') do |form|
      #     puts form
      #   end
      #   # AffixForm(spells = spells)
      #   # AffixForm(spells = spell + Suffix(s: S×, on [[^sxzhy]]$))
      class Lookuper
        include CompoundChecks

        # @return [Hash] Aff data structure (from aff file)
        attr_reader :aff

        # @return [Hash] Dic data structure (from dic file)
        attr_reader :dic

        def initialize(aff, dic)
          @aff = aff
          @dic = dic
        end

        # The outermost word correctness check.
        #
        # Basically, prepares word for check (converting/removing chars), and
        # then checks whether any good word form can be produced with good_forms.
        # If there is none, also tries to break word by break-points.
        #
        # @param word [String] Word to check
        # @param capitalization [Boolean] If false, check only exact capitalization
        # @param allow_nosuggest [Boolean] If false, don't consider NOSUGGEST words as correct
        # @return [Boolean] Whether word is correct
        def call(word, capitalization: true, allow_nosuggest: true)
          # Check if word is correct
          is_correct = ->(w) do
            good_forms(w, capitalization: capitalization, allow_nosuggest: allow_nosuggest).any?
          end

          # If all entries matching the word have FORBIDDENWORD flag, word can't be correct
          if @aff[:FORBIDDENWORD] && @dic[:has_flag]&.call(word, @aff[:FORBIDDENWORD], for_all: true)
            return false
          end

          # Convert word with ICONV table
          word_to_check = @aff[:ICONV] ? @aff[:ICONV].call(word) : word

          # Remove ignored characters
          if @aff[:IGNORE]
            ignore_chars = @aff[:IGNORE]
            word_to_check = word_to_check.chars.reject { |c| ignore_chars.include?(c) }.join
          end

          # Numbers are always good
          return true if NUMBER_REGEXP.match?(word_to_check)

          # Try breaking word by break patterns
          break_word(word_to_check).each do |parts|
            if parts.all? { |part| part.empty? || is_correct.call(part) }
              return true
            end
          end

          false
        end

        # Recursively produce all possible lists of word breaking by break
        # patterns (like dashes).
        #
        # Example: "pre-processed-meat" would produce:
        #   ["pre-processed-meat"]
        #   ["pre", "processed-meat"]
        #   ["pre", "processed", "meat"]
        #   ["pre-processed", "meat"]
        #
        # This is necessary because dictionary might contain "pre-processed"
        # as a separate entry.
        #
        # @param text [String] Text to break
        # @param depth [Integer] Current recursion depth
        # @yield [Array<String>] Each possible breaking
        # @return [Enumerator] If no block given
        def break_word(text, depth = 0)
          return enum_for(:break_word, text, depth) unless block_given?
          return if depth > 10

          # Return whole text as first option
          yield [text]

          break_patterns = @aff[:BREAK] || []
          break_patterns.each do |pattern|
            str = text.to_s
            pos = 0

            while (match_data = pattern[:matcher].match(str, pos))
              start = str[0...match_data.begin(1)]
              rest = str[match_data.end(1)..]

              break_word(rest, depth + 1) do |breaking|
                yield [start, *breaking]
              end

              pos = match_data.end(0)
              break if pos >= str.length
            end
          end
        end

        # The main producer of correct word forms.
        #
        # Produces all ways the proposed string might correspond to dictionary/
        # affixes. If there is at least one, the word is correctly spelled.
        #
        # Example:
        #   lookuper.good_forms('building') do |form|
        #     puts form
        #   end
        #   # AffixForm(building = building)                              # noun
        #   # AffixForm(building = build + Suffix(ing: G×, on [[^e]]$))   # verb
        #
        # @param word [String] Word to check
        # @param capitalization [Boolean] If false, use only exact capitalization
        # @param allow_nosuggest [Boolean] If false, exclude NOSUGGEST words
        # @param affix_forms [Boolean] If false, only return compound forms
        # @param compound_forms [Boolean] If false, only return affix forms
        # @yield [AffixForm, CompoundForm] Each valid word form
        def good_forms(word,
                       capitalization: true,
                       allow_nosuggest: true,
                       affix_forms: true,
                       compound_forms: true, &block)
          unless block
            return enum_for(:good_forms, word,
                            capitalization: capitalization,
                            allow_nosuggest: allow_nosuggest,
                            affix_forms: affix_forms,
                            compound_forms: compound_forms)
          end

          # Get capitalization variants
          if capitalization
            captype, variants = @aff[:casing].variants(word)
          else
            captype = @aff[:casing].guess(word)
            variants = [word]
          end

          # Check each variant
          variants.each do |variant|
            if affix_forms
              affix_forms_internal(variant, captype: captype, allow_nosuggest: allow_nosuggest) do |form|
                # Special German ß handling
                if @aff[:CHECKSHARPS] && @aff[:KEEPCASE]
                  stem = form.in_dictionary ? form.in_dictionary[:stem] : form.stem
                  if stem.include?('ß') &&
                      captype == Capitalization::Type::ALL &&
                      word.include?('ß') &&
                      form.flags.include?(@aff[:KEEPCASE])
                    next
                  end
                end

                yield form
              end
            end

            if compound_forms
              compound_forms_internal(variant, captype: captype, allow_nosuggest: allow_nosuggest, &block)
            end
          end
        end

        # Check if the word is correct without yielding forms.
        #
        # Convenience method for simple correctness checks.
        #
        # @param word [String] Word to check
        # @param capitalization [Boolean] Check capitalization variants
        # @param allow_nosuggest [Boolean] Include NOSUGGEST words
        # @param affix_forms [Boolean] Check affix forms
        # @param compound_forms [Boolean] Check compound forms
        # @return [Boolean] Whether word is correct
        def correct?(word,
                     capitalization: true,
                     allow_nosuggest: true,
                     affix_forms: true,
                     compound_forms: true)
          good_forms(word,
                     capitalization: capitalization,
                     allow_nosuggest: allow_nosuggest,
                     affix_forms: affix_forms,
                     compound_forms: compound_forms).any?
        end

        # Alias for better readability
        alias is_correct? correct?

        private

        # Internal affix forms generator.
        #
        # @param word [String] Word to process
        # @param captype [Symbol] Capitalization type
        # @param allow_nosuggest [Boolean] Include NOSUGGEST words
        # @param with_forbidden [Boolean] When true, also yield forms whose
        #   homonym carries FORBIDDENWORD (used by compound_forms_internal to
        #   detect forbidden base words). When false (default), forbidden
        #   homonyms are skipped per-homonym — not by aborting the whole
        #   search, so a non-forbidden homonym of the same stem can still
        #   match.
        # @param compoundpos [Symbol, nil] When called from compounds_by_flags,
        #   the position in compound (BEGIN_POS / MIDDLE / END_POS). Drives
        #   suffix/prefix allowance in produce_affix_forms and compound
        #   position flag checks in is_good_form.
        # @param prefix_flags [Array<String>] Flags a prefix must carry to be
        #   valid inside a compound (COMPOUNDPERMITFLAG).
        # @param suffix_flags [Array<String>] Flags a suffix must carry to be
        #   valid inside a compound (COMPOUNDPERMITFLAG).
        # @param forbidden_flags [Array<String>] Flags that disqualify an
        #   affix inside a compound (COMPOUNDFORBIDFLAG).
        # @yield [AffixForm] Each valid affix form
        def affix_forms_internal(word, captype:, allow_nosuggest:, with_forbidden: false,
                                 compoundpos: nil, prefix_flags: [], suffix_flags: [],
                                 forbidden_flags: [])
          unless block_given?
            return enum_for(:affix_forms_internal, word,
                            captype: captype,
                            allow_nosuggest: allow_nosuggest,
                            with_forbidden: with_forbidden,
                            compoundpos: compoundpos,
                            prefix_flags: prefix_flags,
                            suffix_flags: suffix_flags,
                            forbidden_flags: forbidden_flags)
          end

          produce_affix_forms(word, compoundpos: compoundpos,
                                    prefix_flags: prefix_flags,
                                    suffix_flags: suffix_flags,
                                    forbidden_flags: forbidden_flags).each do |form|
            found = false
            homonyms = @dic[:homonyms]&.call(form.stem) || []

            # FORBIDDENWORD: in compound context (compoundpos set) OR when the
            # form has affixes, if ANY homonym of the stem carries
            # FORBIDDENWORD, the entire form is rejected. This mirrors
            # Spylls lookup.py — a forbidden stem must not appear as a
            # compound part (even without affixes) nor as an affixed form.
            if !with_forbidden && @aff[:FORBIDDENWORD] &&
                (compoundpos || form.has_affixes?) &&
                homonyms.any? { |h| (h[:flags] || []).include?(@aff[:FORBIDDENWORD]) }
              next
            end

            homonyms.each do |homonym|
              candidate = form.replace(in_dictionary: homonym)
              if is_good_form(candidate, captype: captype, allow_nosuggest: allow_nosuggest,
                                         compoundpos: compoundpos)
                found = true
                yield candidate
              end
            end

            # FORCEUCASE: when checking the beginning of a compound and the
            # original word is capitalized, also try lowercased stem homonyms
            # so that compound parts that must be uppercased can still match.
            if compoundpos == CompoundPos::BEGIN_POS && @aff[:FORCEUCASE] &&
                captype == Capitalization::Type::INIT
              lower_homonyms = @dic[:homonyms]&.call(form.stem.downcase) || []
              lower_homonyms.each do |homonym|
                candidate = form.replace(in_dictionary: homonym)
                if is_good_form(candidate, captype: captype, allow_nosuggest: allow_nosuggest,
                                           compoundpos: compoundpos)
                  found = true
                  yield candidate
                end
              end
            end

            # Skip the case-insensitive fallback when any path already matched
            # for this form, when the form lives in a compound slot (compound
            # parts go through their own dispatch), or when the original
            # word's captype is not ALL — the lowercase index is only meant
            # for ALLCAPS queries whose dictionary stem differs in case.
            next if found
            next if compoundpos
            next if captype != Capitalization::Type::ALL
            next unless @aff[:casing].guess(word) == Capitalization::Type::NO

            # ALLCAPS case-insensitive fallback: when the original input was
            # ALL CAPS but the dictionary stem has a different case (e.g.
            # user typed "UNICEF'S" / captype=ALL but the variant being
            # checked is "unicef's" / captype=NO), look up homonyms in the
            # lowercase index. Mirrors Spylls lookup.py:423-436.
            ignorecase_homonyms = @dic[:homonyms]&.call(form.stem, ignorecase: true) || []
            ignorecase_homonyms.each do |homonym|
              forbidden = @aff[:FORBIDDENWORD] &&
                form.has_affixes? &&
                (homonym[:flags] || []).include?(@aff[:FORBIDDENWORD])
              next if forbidden && !with_forbidden

              candidate = form.replace(in_dictionary: homonym)
              if is_good_form(candidate, captype: captype, allow_nosuggest: allow_nosuggest,
                                         compoundpos: compoundpos)
                yield candidate
              end
            end
          end
        end

        # Internal compound forms generator.
        #
        # @param word [String] Word to process
        # @param captype [Symbol] Capitalization type
        # @param allow_nosuggest [Boolean] Include NOSUGGEST words
        # @yield [CompoundForm] Each valid compound form
        def compound_forms_internal(word, captype:, allow_nosuggest:)
          unless block_given?
            return enum_for(:compound_forms_internal, word, captype: captype,
                                                            allow_nosuggest: allow_nosuggest)
          end

          # Check if any affix form has FORBIDDENWORD
          if @aff[:FORBIDDENWORD]
            forbidden_found = false
            affix_forms_internal(word, captype: captype, allow_nosuggest: allow_nosuggest,
                                       with_forbidden: true) do |form|
              if form.flags.include?(@aff[:FORBIDDENWORD])
                forbidden_found = true
                break
              end
            end
            return if forbidden_found
          end

          # Try compounds by flags
          if @aff[:COMPOUNDBEGIN] || @aff[:COMPOUNDFLAG]
            compounds_by_flags(word, captype: captype, allow_nosuggest: allow_nosuggest) do |compound|
              yield compound unless is_bad_compound(compound, captype)
            end
          end

          # Try compounds by rules
          if @aff[:COMPOUNDRULE]
            compounds_by_rules(word, allow_nosuggest: allow_nosuggest) do |compound|
              yield compound unless is_bad_compound(compound, captype)
            end
          end
        end

        # Produce all possible affix forms for a word.
        #
        # @param word [String] Word to process
        # @param compoundpos [Symbol, nil] Position in compound
        # @param prefix_flags [Array<String>] Required prefix flags
        # @param suffix_flags [Array<String>] Required suffix flags
        # @param forbidden_flags [Array<String>] Forbidden affix flags
        # @yield [AffixForm] Each possible affix form
        def produce_affix_forms(word,
                                 compoundpos: nil,
                                 prefix_flags: [],
                                 suffix_flags: [],
                                 forbidden_flags: [], &block)
          unless block
            return enum_for(:produce_affix_forms, word,
                            compoundpos: compoundpos,
                            prefix_flags: prefix_flags,
                            suffix_flags: suffix_flags,
                            forbidden_flags: forbidden_flags)
          end

          # "Whole word" is always an option
          yield AffixForm.new(word, word)

          # Check if suffixes/prefixes are allowed
          suffix_allowed = compoundpos.nil? || compoundpos == CompoundPos::END_POS || !suffix_flags.empty?
          prefix_allowed = compoundpos.nil? || compoundpos == CompoundPos::BEGIN_POS || !prefix_flags.empty?

          # Generate suffix forms
          if suffix_allowed
            desuffix(word, required_flags: suffix_flags, forbidden_flags: forbidden_flags, &block)
          end

          # Generate prefix forms
          if prefix_allowed
            deprefix(word, required_flags: prefix_flags, forbidden_flags: forbidden_flags) do |form|
              yield form

              # Try prefix + suffix if allowed
              if suffix_allowed && form.prefix && form.prefix[:crossproduct]
                desuffix(form.stem,
                         required_flags: suffix_flags,
                         forbidden_flags: forbidden_flags,
                         crossproduct: true) do |form2|
                  yield form2.replace(text: form.text, prefix: form.prefix)
                end
              end
            end
          end
        end

        # Remove suffixes from word.
        #
        # @param word [String] Word to process
        # @param required_flags [Array<String>] Required suffix flags
        # @param forbidden_flags [Array<String>] Forbidden suffix flags
        # @param nested [Boolean] Whether this is a nested call
        # @param crossproduct [Boolean] Whether suffix must have crossproduct
        # @yield [AffixForm] Each form with suffix removed
        def desuffix(word, required_flags: [], forbidden_flags: [], nested: false, crossproduct: false)
          unless block_given?
            return enum_for(:desuffix, word,
                            required_flags: required_flags,
                            forbidden_flags: forbidden_flags,
                            nested: nested,
                            crossproduct: crossproduct)
          end

          suffixes_index = @aff[:suffixes_index] || {}
          word_reversed = word.reverse

          # Spylls's Trie.lookup yields root payloads (empty-add suffixes)
          # before walking the path, so suffixes with add="" are always
          # considered. The hash index drops them unless we explicitly
          # include the "" bucket.
          candidates = (suffixes_index[''] || []) + (suffixes_index[word_reversed[0]] || [])
          candidates.each do |suffix|
            # Check if suffix is valid
            next if crossproduct && !suffix[:crossproduct]
            next unless (required_flags - (suffix[:flags] || [])).empty?
            next unless (forbidden_flags & (suffix[:flags] || [])).empty?

            # Check if suffix matches
            if word.end_with?(suffix[:affix])
              # Remove suffix and add strip value. Note: when affix is "",
              # `word[0...-0]` would be `word[0...0]` = "" — so handle the
              # empty case explicitly to keep the whole word as the base.
              base = suffix[:affix].empty? ? word : word[0...-suffix[:affix].length]
              strip = suffix[:affix_data] ? suffix[:affix_data][:strip] : ''
              stem = base + strip

              # Check condition (only if condition_checker is present)
              next if suffix[:condition_checker] && !suffix[:condition_checker].matches?(stem)

              yield AffixForm.new(word, stem, suffix: suffix)

              # Try removing another suffix (one level only)
              unless nested
                desuffix(stem,
                         required_flags: [suffix[:flag], *required_flags],
                         forbidden_flags: forbidden_flags,
                         nested: true,
                         crossproduct: crossproduct) do |form2|
                  yield form2.replace(suffix2: suffix, text: word)
                end
              end
            end
          end
        end

        # Remove prefixes from word.
        #
        # @param word [String] Word to process
        # @param required_flags [Array<String>] Required prefix flags
        # @param forbidden_flags [Array<String>] Forbidden prefix flags
        # @param nested [Boolean] Whether this is a nested call
        # @yield [AffixForm] Each form with prefix removed
        def deprefix(word, required_flags: [], forbidden_flags: [], nested: false)
          unless block_given?
            return enum_for(:deprefix, word,
                            required_flags: required_flags,
                            forbidden_flags: forbidden_flags,
                            nested: nested)
          end

          prefixes_index = @aff[:prefixes_index] || {}

          # Mirror the suffix side: prefixes with add="" live under the ""
          # bucket and must always be considered.
          candidates = (prefixes_index[''] || []) + (prefixes_index[word[0]] || [])
          candidates.each do |prefix|
            # Check if prefix is valid
            next unless (required_flags - (prefix[:flags] || [])).empty?
            next unless (forbidden_flags & (prefix[:flags] || [])).empty?

            # Check if prefix matches
            if word.start_with?(prefix[:affix])
              # Remove prefix and re-add the strip value at the START.
              # (For suffixes the strip is appended; for prefixes it's
              # prepended — the strip/affix are mirrors of each other
              # and the strip lives on the same edge of the stem as the
              # affix does on the candidate.)
              strip = prefix[:affix_data] ? prefix[:affix_data][:strip] : ''
              stem = strip + word[prefix[:affix].length..]

              # Check condition (only if condition_checker is present)
              next if prefix[:condition_checker] && !prefix[:condition_checker].matches?(stem)

              yield AffixForm.new(word, stem, prefix: prefix)

              # Try removing another prefix if COMPLEXPREFIXES is set
              unless nested || !@aff[:COMPLEXPREFIXES]
                deprefix(stem,
                         required_flags: [prefix[:flag], *required_flags],
                         forbidden_flags: forbidden_flags,
                         nested: true) do |form2|
                  yield form2.replace(prefix2: prefix, text: word)
                end
              end
            end
          end
        end

        # Check if an affix form is valid.
        #
        # When compoundpos is nil (non-compound check), the form must not
        # carry ONLYINCOMPOUND. When compoundpos is set (compound part
        # check), ONLYINCOMPOUND is allowed and instead the form must carry
        # COMPOUNDFLAG or the position-specific flag (COMPOUNDBEGIN /
        # COMPOUNDMIDDLE / COMPOUNDEND). This mirrors Spylls lookup.py
        # is_good_form.
        #
        # @param form [AffixForm] Form to check
        # @param captype [Symbol] Original word's capitalization type
        # @param allow_nosuggest [Boolean] Include NOSUGGEST words
        # @param compoundpos [Symbol, nil] Position in compound, or nil
        # @return [Boolean] Whether form is valid
        def is_good_form(form, captype:, allow_nosuggest:, compoundpos: nil)
          return false unless form.in_dictionary

          root_flags = form.in_dictionary[:flags] || []
          all_flags = form.flags

          # Check NOSUGGEST
          if !allow_nosuggest && @aff[:NOSUGGEST] && root_flags.include?(@aff[:NOSUGGEST])
            return false
          end

          # Check KEEPCASE
          if @aff[:KEEPCASE] && root_flags.include?(@aff[:KEEPCASE])
            stem_captype = @aff[:casing].guess(form.in_dictionary[:stem])
            return false if captype != stem_captype && !(@aff[:CHECKSHARPS] && form.in_dictionary[:stem].include?('ß'))
          end

          # Check NEEDAFFIX
          if @aff[:NEEDAFFIX]
            if root_flags.include?(@aff[:NEEDAFFIX]) && !form.has_affixes?
              return false
            end
            if form.has_affixes? && form.all_affixes.all? { |a| (a[:flags] || []).include?(@aff[:NEEDAFFIX]) }
              return false
            end
          end

          # Check prefix flag compatibility
          if form.prefix && !all_flags.include?(form.prefix[:flag])
            return false
          end

          # Check suffix flag compatibility
          if form.suffix && !all_flags.include?(form.suffix[:flag])
            return false
          end

          # Check CIRCUMFIX
          if @aff[:CIRCUMFIX]
            suffix_has = form.suffix ? (form.suffix[:flags] || []).include?(@aff[:CIRCUMFIX]) : false
            prefix_has = form.prefix ? (form.prefix[:flags] || []).include?(@aff[:CIRCUMFIX]) : false
            return false if suffix_has != prefix_has
          end

          # Compound position checks
          if compoundpos.nil?
            # Non-compound: reject ONLYINCOMPOUND words
            return !all_flags.include?(@aff[:ONLYINCOMPOUND])
          end

          return false if compoundpos == CompoundPos::END_POS && barred_from_compound_end?(form)

          # Compound: must carry COMPOUNDFLAG or the position-specific flag.
          # ONLYINCOMPOUND is allowed here (it just means "not valid outside
          # compounds") — the compound position flag is what authorizes the
          # part to appear at this slot.
          return true if @aff[:COMPOUNDFLAG] && all_flags.include?(@aff[:COMPOUNDFLAG])
          return true if compoundpos == CompoundPos::BEGIN_POS && @aff[:COMPOUNDBEGIN] &&
            all_flags.include?(@aff[:COMPOUNDBEGIN])
          return true if compoundpos == CompoundPos::MIDDLE && @aff[:COMPOUNDMIDDLE] &&
            all_flags.include?(@aff[:COMPOUNDMIDDLE])
          return true if compoundpos == CompoundPos::END_POS && @aff[:COMPOUNDEND] &&
            all_flags.include?(@aff[:COMPOUNDEND])

          false
        end

        # Whether a suffix stops this form from closing a compound.
        #
        # Ported from Hunspell's suffix_check (affixmgr.cxx:2832): a suffix
        # is barred at the compound end only when it carries ONLYINCOMPOUND
        # and nothing else rescues it. Two things do. A zero-width suffix is
        # handled by a separate branch upstream that has no such guard, and
        # a prefix on the form is an explicit exemption (`ppfx` upstream).
        # That is how
        # German reaches "Arbeitscomputern", through its decapitalising
        # prefix rather than through any compound-position flag.
        #
        # @param form [AffixForm] Form being placed at the compound end
        # @return [Boolean] Whether a suffix bars it from ending the compound
        def barred_from_compound_end?(form)
          only_in_compound = @aff[:ONLYINCOMPOUND]
          return false unless only_in_compound
          return false if form.prefix

          form.suffixes.any? do |suffix|
            !suffix[:affix].to_s.empty? && (suffix[:flags] || []).include?(only_in_compound)
          end
        end

        # Generate compound forms by flags.
        #
        # @param word_rest [String] Remaining word to process
        # @param captype [Symbol] Capitalization type
        # @param depth [Integer] Current recursion depth
        # @param allow_nosuggest [Boolean] Include NOSUGGEST words
        # @yield [CompoundForm] Each valid compound form
        def compounds_by_flags(word_rest, captype:, depth: 0, allow_nosuggest: true)
          unless block_given?
            return enum_for(:compounds_by_flags, word_rest,
                            captype: captype,
                            depth: depth,
                            allow_nosuggest: allow_nosuggest)
          end

          aff = @aff
          compound_min = aff[:COMPOUNDMIN] || 3
          compound_word_max = aff[:COMPOUNDWORDMAX]
          compound_permit_flag = aff[:COMPOUNDPERMITFLAG]
          compound_forbid_flag = aff[:COMPOUNDFORBIDFLAG]

          forbidden_flags = compound_forbid_flag ? [compound_forbid_flag] : []
          permit_flags = compound_permit_flag ? [compound_permit_flag] : []

          # Check if rest can be compound end. At END position, suffixes are
          # always allowed (compoundpos=END_POS in produce_affix_forms), but
          # prefixes still need COMPOUNDPERMITFLAG.
          if depth.positive?
            affix_forms_internal(word_rest, captype: captype, allow_nosuggest: allow_nosuggest,
                                            compoundpos: CompoundPos::END_POS,
                                            prefix_flags: permit_flags,
                                            forbidden_flags: forbidden_flags) do |form|
              yield CompoundForm.new([form])
            end
          end

          # Check compounding limits
          return if word_rest.length < compound_min * 2
          return if compound_word_max && depth >= compound_word_max

          compoundpos = depth.zero? ? CompoundPos::BEGIN_POS : CompoundPos::MIDDLE
          # At BEGIN_POS, prefixes are allowed by default (no permit flag
          # needed); at MIDDLE, prefixes need the permit flag. Suffixes at
          # both BEGIN and MIDDLE need the permit flag — when there is no
          # COMPOUNDPERMITFLAG in the .aff, suffix_flags is empty and
          # produce_affix_forms blocks all suffixes inside compounds.
          prefix_flags = compoundpos == CompoundPos::BEGIN_POS ? [] : permit_flags

          each_compound_junction(word_rest, compound_min) do |left, right, left_text, pattern|
            affix_forms_internal(left, captype: captype, allow_nosuggest: allow_nosuggest,
                                       compoundpos: compoundpos,
                                       prefix_flags: prefix_flags,
                                       suffix_flags: permit_flags,
                                       forbidden_flags: forbidden_flags) do |form|
              compounds_by_flags(right, captype: captype, depth: depth + 1,
                                        allow_nosuggest: allow_nosuggest) do |partial|
                next if pattern && !pattern.match?(form, partial.parts.first)

                part = left_text ? form.replace(text: left_text) : form
                yield CompoundForm.new([part, *partial.parts],
                                       [pattern, *partial.junction_patterns])
              end
            end
          end
        end

        # CHECKCOMPOUNDPATTERN entries that spell a simplified compound form.
        #
        # @return [Array<Readers::CompoundPattern>] Patterns with a replacement
        def replacement_patterns
          @replacement_patterns ||= (@aff[:CHECKCOMPOUNDPATTERN] || []).select(&:replacement?)
        end

        # Every cut of the word worth trying as a compound boundary.
        #
        # Yields `(left, right, left_text, pattern)` rather than an object:
        # this is the innermost loop of the whole checker, and one allocation
        # per split position is measurable on deeply compounding languages.
        #
        # `left_text` is the text to record on the left member when it
        # differs from the text looked up, and `pattern` is set only for a
        # cut a CHECKCOMPOUNDPATTERN replacement rebuilt. Both are nil for
        # the ordinary case, which is nearly all of them.
        #
        # The window is COMPOUNDMIN either side of the cut, measured on the
        # word as written. Hunspell fixes it the same way, before it tries
        # any replacement (setcminmax at affixmgr.cxx:1644, the replacement
        # loop nested inside at :1660). A replacement can therefore stand for
        # members longer than the text it replaced, which is why hunspell.5
        # warns that COMPOUNDMIN "doesn't work correctly with the compound
        # word alternation, so it may need to set COMPOUNDMIN to lower
        # value". Matching that quirk beats being quietly more permissive
        # than the dictionaries were written against.
        #
        # @param word_rest [String] Remaining word being split
        # @param compound_min [Integer] COMPOUNDMIN
        # @yield [String, String, String, Readers::CompoundPattern] Left
        #   member, remaining text, surface text or nil, pattern or nil
        def each_compound_junction(word_rest, compound_min)
          simplified_triple = @aff[:SIMPLIFIEDTRIPLE]
          patterns = replacement_patterns

          (compound_min...(word_rest.length - compound_min + 1)).each do |pos|
            beg = word_rest[0...pos]
            rest = word_rest[pos..]
            yield beg, rest, nil, nil

            if simplified_triple && !beg.empty? && !rest.empty? && beg[-1] == rest[0]
              yield beg + beg[-1], rest, beg, nil
            end

            patterns.each do |pattern|
              replacement = pattern.replacement
              next unless word_rest[pos, replacement.length] == replacement

              yield beg + pattern.left_stem,
                    pattern.right_stem + word_rest[(pos + replacement.length)..],
                    nil, pattern
            end
          end
        end

        # Generate compound forms by rules.
        #
        # @param word_rest [String] Remaining word to process
        # @param prev_parts [Array<Hash>] Previously processed parts
        # @param rules [Array<Hash>] Valid compound rules
        # @param allow_nosuggest [Boolean] Include NOSUGGEST words
        # @yield [CompoundForm] Each valid compound form
        def compounds_by_rules(word_rest, prev_parts: [], rules: nil, allow_nosuggest: true)
          unless block_given?
            return enum_for(:compounds_by_rules, word_rest,
                            prev_parts: prev_parts,
                            rules: rules,
                            allow_nosuggest: allow_nosuggest)
          end

          aff = @aff
          compound_min = aff[:COMPOUNDMIN] || 3
          compound_word_max = aff[:COMPOUNDWORDMAX]
          compound_rules = aff[:COMPOUNDRULE] || []

          rules ||= compound_rules

          # Check if rest can be a complete compound
          if prev_parts.any?
            homonyms = @dic[:homonyms]&.call(word_rest) || []
            homonyms.each do |homonym|
              parts = [*prev_parts, homonym]
              flag_sets = parts.map { |p| p[:flags] || [] }

              if compound_rules.any? { |rule| rule[:full_match]&.call(flag_sets) }
                yield CompoundForm.new([AffixForm.new(word_rest, word_rest)])
              end
            end
          end

          # Check limits
          return if word_rest.length < compound_min * 2
          return if compound_word_max && prev_parts.length >= compound_word_max

          # Try all possible split positions
          (compound_min...(word_rest.length - compound_min + 1)).each do |pos|
            beg = word_rest[0...pos]
            homonyms = @dic[:homonyms]&.call(beg) || []

            homonyms.each do |homonym|
              parts = [*prev_parts, homonym]
              flag_sets = parts.map { |p| p[:flags] || [] }

              matching_rules = compound_rules.select { |rule| rule[:partial_match]&.call(flag_sets) }
              next if matching_rules.empty?

              compounds_by_rules(word_rest[pos..], prev_parts: parts, rules: matching_rules,
                                                   allow_nosuggest: allow_nosuggest) do |partial|
                yield CompoundForm.new([AffixForm.new(beg, beg), *partial.parts])
              end
            end
          end
        end
      end
    end
  end
end
