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
      NUMBER_REGEXP = /^\d+(\.\d+)?$/.freeze

      # Position of word part in compound word.
      #
      # Used when checking whether a word could be part of a compound
      # (specifically its begin/middle/end).
      module CompoundPos
        BEGIN_POS = :begin
        MIDDLE = :middle
        END_POS = :end
      end

      # AffixForm is a hypothesis of how some word might be split into
      # stem, suffixes and prefixes.
      #
      # It always has full text and stem, and may have up to two suffixes
      # and up to two prefixes.
      #
      # The following is always true (considering absent affixes as empty):
      #   prefix + prefix2 + stem + suffix2 + suffix = text
      #
      # prefix2/suffix2 are "secondary", so if the word has only one suffix,
      # it is stored in suffix and suffix2 is nil.
      class AffixForm
        # @return [String] Full word text
        attr_reader :text

        # @return [String] Stem (word without affixes)
        attr_reader :stem

        # @return [Hash, nil] Prefix affix data
        attr_reader :prefix

        # @return [Hash, nil] Suffix affix data
        attr_reader :suffix

        # @return [Hash, nil] Secondary prefix affix data
        attr_reader :prefix2

        # @return [Hash, nil] Secondary suffix affix data
        attr_reader :suffix2

        # @return [Hash, nil] Dictionary entry for stem
        attr_reader :in_dictionary

        def initialize(text, stem,
                       prefix: nil, suffix: nil,
                       prefix2: nil, suffix2: nil,
                       in_dictionary: nil)
          @text = text
          @stem = stem
          @prefix = prefix
          @suffix = suffix
          @prefix2 = prefix2
          @suffix2 = suffix2
          @in_dictionary = in_dictionary
        end

        # Create a copy with changes.
        #
        # @param changes [Hash] Changes to apply
        # @return [AffixForm] New affix form with changes applied
        def replace(**changes)
          self.class.new(
            changes.fetch(:text, @text),
            changes.fetch(:stem, @stem),
            prefix: changes.fetch(:prefix, @prefix),
            suffix: changes.fetch(:suffix, @suffix),
            prefix2: changes.fetch(:prefix2, @prefix2),
            suffix2: changes.fetch(:suffix2, @suffix2),
            in_dictionary: changes.fetch(:in_dictionary, @in_dictionary)
          )
        end

        # Check if this form has any affixes.
        #
        # @return [Boolean]
        def has_affixes?
          !@suffix.nil? || !@prefix.nil?
        end

        # Check if this is a base form (no affixes).
        #
        # @return [Boolean]
        def is_base?
          !has_affixes?
        end

        # Get all flags from stem and affixes.
        #
        # @return [Set<String>] Combined flags
        def flags
          flags = @in_dictionary ? Set.new(@in_dictionary[:flags] || []) : Set.new
          flags.merge(@prefix[:flags] || []) if @prefix
          flags.merge(@suffix[:flags] || []) if @suffix
          flags
        end

        # Get all affixes (excluding nils).
        #
        # @return [Array<Hash>] List of affix data
        def all_affixes
          [@prefix2, @prefix, @suffix, @suffix2].compact
        end

        # String representation.
        #
        # @return [String]
        def to_s
          return @text if is_base?

          parts = []
          parts << @prefix.inspect if @prefix
          parts << @prefix2.inspect if @prefix2
          parts << @stem
          parts << @suffix2.inspect if @suffix2
          parts << @suffix.inspect if @suffix

          "AffixForm(#{@text} = #{parts.join(' + ')})"
        end

        alias inspect to_s
      end

      # CompoundForm is a hypothesis of how some word could be split into
      # several AffixForms (word parts with their own stems and possible affixes).
      #
      # Typically, only first part is allowed to have prefix, and only last
      # part is allowed to have suffix, but there are languages where middle
      # parts can have affixes too, specified by special flags.
      class CompoundForm
        # @return [Array<AffixForm>] Parts of the compound word
        attr_reader :parts

        def initialize(parts)
          @parts = parts
        end

        # String representation.
        #
        # @return [String]
        def to_s
          "CompoundForm(#{@parts.map(&:to_s).join(' + ')})"
        end

        alias inspect to_s
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
                       compound_forms: true)
          return enum_for(:good_forms, word,
                          capitalization: capitalization,
                          allow_nosuggest: allow_nosuggest,
                          affix_forms: affix_forms,
                          compound_forms: compound_forms) unless block_given?

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
              compound_forms_internal(variant, captype: captype, allow_nosuggest: allow_nosuggest) do |form|
                yield form
              end
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
          return enum_for(:affix_forms_internal, word,
                          captype: captype,
                          allow_nosuggest: allow_nosuggest,
                          with_forbidden: with_forbidden,
                          compoundpos: compoundpos,
                          prefix_flags: prefix_flags,
                          suffix_flags: suffix_flags,
                          forbidden_flags: forbidden_flags) unless block_given?

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
          return enum_for(:compound_forms_internal, word, captype: captype, allow_nosuggest: allow_nosuggest) unless block_given?

          # Check if any affix form has FORBIDDENWORD
          if @aff[:FORBIDDENWORD]
            forbidden_found = false
            affix_forms_internal(word, captype: captype, allow_nosuggest: allow_nosuggest, with_forbidden: true) do |form|
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
                                 forbidden_flags: [])
          return enum_for(:produce_affix_forms, word,
                          compoundpos: compoundpos,
                          prefix_flags: prefix_flags,
                          suffix_flags: suffix_flags,
                          forbidden_flags: forbidden_flags) unless block_given?

          # "Whole word" is always an option
          yield AffixForm.new(word, word)

          # Check if suffixes/prefixes are allowed
          suffix_allowed = compoundpos.nil? || compoundpos == CompoundPos::END_POS || !suffix_flags.empty?
          prefix_allowed = compoundpos.nil? || compoundpos == CompoundPos::BEGIN_POS || !prefix_flags.empty?

          # Generate suffix forms
          if suffix_allowed
            desuffix(word, required_flags: suffix_flags, forbidden_flags: forbidden_flags) do |form|
              yield form
            end
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
          return enum_for(:desuffix, word,
                          required_flags: required_flags,
                          forbidden_flags: forbidden_flags,
                          nested: nested,
                          crossproduct: crossproduct) unless block_given?

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
          return enum_for(:deprefix, word,
                          required_flags: required_flags,
                          forbidden_flags: forbidden_flags,
                          nested: nested) unless block_given?

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

        # Generate compound forms by flags.
        #
        # @param word_rest [String] Remaining word to process
        # @param captype [Symbol] Capitalization type
        # @param depth [Integer] Current recursion depth
        # @param allow_nosuggest [Boolean] Include NOSUGGEST words
        # @yield [CompoundForm] Each valid compound form
        def compounds_by_flags(word_rest, captype:, depth: 0, allow_nosuggest: true)
          return enum_for(:compounds_by_flags, word_rest,
                          captype: captype,
                          depth: depth,
                          allow_nosuggest: allow_nosuggest) unless block_given?

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

          # Try all possible split positions
          (compound_min...(word_rest.length - compound_min + 1)).each do |pos|
            beg = word_rest[0...pos]
            rest = word_rest[pos..]

            # Check if beg is a valid word at this position
            affix_forms_internal(beg, captype: captype, allow_nosuggest: allow_nosuggest,
                                 compoundpos: compoundpos,
                                 prefix_flags: prefix_flags,
                                 suffix_flags: permit_flags,
                                 forbidden_flags: forbidden_flags) do |form|
              # Recursively check rest
              compounds_by_flags(rest, captype: captype, depth: depth + 1, allow_nosuggest: allow_nosuggest) do |partial|
                yield CompoundForm.new([form, *partial.parts])
              end
            end

            # SIMPLIFIEDTRIPLE handling
            if aff[:SIMPLIFIEDTRIPLE] && !beg.empty? && !rest.empty? && beg[-1] == rest[0]
              affix_forms_internal(beg + beg[-1], captype: captype, allow_nosuggest: allow_nosuggest,
                                   compoundpos: compoundpos,
                                   prefix_flags: prefix_flags,
                                   suffix_flags: permit_flags,
                                   forbidden_flags: forbidden_flags) do |form|
                compounds_by_flags(rest, captype: captype, depth: depth + 1, allow_nosuggest: allow_nosuggest) do |partial|
                  yield CompoundForm.new([form.replace(text: beg), *partial.parts])
                end
              end
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
          return enum_for(:compounds_by_rules, word_rest,
                          prev_parts: prev_parts,
                          rules: rules,
                          allow_nosuggest: allow_nosuggest) unless block_given?

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

              compounds_by_rules(word_rest[pos..], prev_parts: parts, rules: matching_rules, allow_nosuggest: allow_nosuggest) do |partial|
                yield CompoundForm.new([AffixForm.new(beg, beg), *partial.parts])
              end
            end
          end
        end

        # Check if compound form has any issues.
        #
        # @param compound [CompoundForm] Compound to check
        # @param captype [Symbol] Capitalization type
        # @return [Boolean] Whether compound is bad
        def is_bad_compound(compound, captype)
          aff = @aff

          # FORCEUCASE check
          if aff[:FORCEUCASE] && ![Capitalization::Type::ALL, Capitalization::Type::INIT].include?(captype)
            if @dic[:has_flag]&.call(compound.parts.last.text, aff[:FORCEUCASE])
              return true
            end
          end

          # Check all adjacent pairs
          compound.parts.each_with_index do |left_paradigm, idx|
            break if idx >= compound.parts.length - 1

            left = left_paradigm.text
            right_paradigm = compound.parts[idx + 1]
            right = right_paradigm.text

            # COMPOUNDFORBIDFLAG check
            if aff[:COMPOUNDFORBIDFLAG] && @dic[:has_flag]&.call(left, aff[:COMPOUNDFORBIDFLAG])
              return true
            end

            # Check if "left right" exists as single dictionary entry
            joined = left + ' ' + right
            if affix_forms_internal(joined, captype: captype, allow_nosuggest: true).any?
              return true
            end

            # CHECKCOMPOUNDREP check
            if aff[:CHECKCOMPOUNDREP] && aff[:REP]
              Kotoshu::Algorithms::Permutations.replchars(left + right, aff[:REP]) do |candidate|
                if candidate.is_a?(String) &&
                   affix_forms_internal(candidate, captype: captype, allow_nosuggest: true).any?
                  return true
                end
              end
            end

            # CHECKCOMPOUNDTRIPLE check
            if aff[:CHECKCOMPOUNDTRIPLE]
              if (left[-2..] + right[0]).chars.uniq.length == 1 ||
                 (left[-1] + right[0..1]).chars.uniq.length == 1
                return true
              end
            end

            # CHECKCOMPOUNDCASE check
            if aff[:CHECKCOMPOUNDCASE]
              right_c = right[0]
              left_c = left[-1]
              if (right_c == right_c.upcase || left_c == left_c.upcase) && right_c != '-' && left_c != '-'
                return true
              end
            end

            # CHECKCOMPOUNDPATTERN check
            if aff[:CHECKCOMPOUNDPATTERN]
              if aff[:CHECKCOMPOUNDPATTERN].any? { |pattern| pattern[:match]&.call(left_paradigm, right_paradigm) }
                return true
              end
            end

            # CHECKCOMPOUNDDUP check
            if aff[:CHECKCOMPOUNDDUP] && left == right && idx == compound.parts.length - 2
              return true
            end
          end

          false
        end
      end
    end
  end
end
