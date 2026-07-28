# frozen_string_literal: true

module Kotoshu
  module Algorithms
    module Lookup
      # The reasons a compound that parses correctly still has to be refused.
      #
      # Splitting a word into dictionary members is only half the job. Every
      # directive below describes a compound that decomposes cleanly and is
      # still wrong: a seam that runs two capitals together, a spelling that
      # is really one mistyped word, a pair of words someone forgot to space.
      # Hunspell keeps these together in compound_check, and the order they
      # run in is part of the port.
      #
      # Mixed into Lookuper, which supplies @aff, @dic and
      # #affix_forms_internal.
      module CompoundChecks
        private

        # Check if compound form has any issues.
        #
        # @param compound [CompoundForm] Compound to check
        # @param captype [Symbol] Capitalization type
        # @return [Boolean] Whether compound is bad
        def is_bad_compound(compound, captype)
          aff = @aff

          # FORCEUCASE check
          if aff[:FORCEUCASE] && ![Capitalization::Type::ALL,
                                   Capitalization::Type::INIT].include?(captype) && @dic[:has_flag]&.call(
                                     compound.parts.last.text, aff[:FORCEUCASE]
                                   )
            return true
          end

          # Check all adjacent pairs
          compound.parts.each_cons(2).with_index do |(left_paradigm, right_paradigm), idx|
            left = left_paradigm.text
            right = right_paradigm.text
            junction_pattern = compound.junction_pattern(idx)

            # COMPOUNDFORBIDFLAG check
            if aff[:COMPOUNDFORBIDFLAG] && @dic[:has_flag]&.call(left, aff[:COMPOUNDFORBIDFLAG])
              return true
            end

            # CHECKCOMPOUNDTRIPLE check. Hunspell guards this with
            # `scpd == 0`: a replacement rewrote the seam, so the letters
            # meeting here are ones the reader never typed.
            if aff[:CHECKCOMPOUNDTRIPLE] && !junction_pattern && tripled_at_seam?(left, right)
              return true
            end

            # CHECKCOMPOUNDCASE check, guarded the same way and for the same
            # reason as CHECKCOMPOUNDTRIPLE above.
            if aff[:CHECKCOMPOUNDCASE] && !junction_pattern
              right_c = right[0]
              left_c = left[-1]
              if (right_c == right_c.upcase || left_c == left_c.upcase) && right_c != '-' && left_c != '-'
                return true
              end
            end

            # CHECKCOMPOUNDPATTERN check. A rebuilt junction is exempt from
            # every pattern, not just the one that rebuilt it. Hunspell
            # guards the whole check with `scpd == 0` (affixmgr.cxx:2015).
            if !junction_pattern &&
                (aff[:CHECKCOMPOUNDPATTERN] || []).any? { |p| p.match?(left_paradigm, right_paradigm) }
              return true
            end

            # CHECKCOMPOUNDDUP check
            if aff[:CHECKCOMPOUNDDUP] && left == right && idx == compound.parts.length - 2
              return true
            end
          end

          misreads_as_other_words?(compound, captype)
        end

        # Do three of the same letter meet at this seam?
        #
        # Hunspell tests the two characters either side and one more beyond,
        # guarding each reach with a bounds check (affixmgr.cxx:1866). A
        # single-character member has nothing beyond it, which is why the
        # lengths are checked rather than sliced blindly.
        #
        # @param left [String] Left member, as written
        # @param right [String] Right member, as written
        # @return [Boolean]
        def tripled_at_seam?(left, right)
          return false unless left[-1] == right[0]

          (left.length > 1 && left[-2] == left[-1]) ||
            (right.length > 1 && right[0] == right[1])
        end

        # Does some run of adjacent members read as other words entirely?
        #
        # Two ways that happens. The run is one word someone mistyped
        # (CHECKCOMPOUNDREP), or it is two words someone forgot to space.
        #
        # Both are checked over every contiguous run, not just the whole
        # compound. Hunspell reaches the runs from two directions:
        # compound_check recurses on what is left of the word, so each level
        # sees a suffix (affixmgr.cxx:1979, :2135), and it also passes a
        # prefix length, `i + rv->blen`, at :2147.
        #
        # Each direction catches what the other misses. ph2's
        # "rootforbiddenroot" is caught by the suffix "forbiddenroot", which
        # reads as the entry "forbidden root". checkcompoundrep's
        # "szervízkocsi" is caught by the prefix "szervíz", which REP
        # rewrites to "szerviz". A suffix like "bcc" reading as "b cc" is
        # missed entirely if only the whole compound is checked, since
        # splitting that in two can never drop the first member.
        #
        # @param compound [CompoundForm] Compound to check
        # @param captype [Symbol] Capitalization type
        # @return [Boolean]
        def misreads_as_other_words?(compound, captype)
          faults = @aff[:CHECKCOMPOUNDREP] && @aff[:REP]
          pairs = dictionary_has_word_pairs?
          return false unless faults || pairs

          runs_of_members(compound).any? do |run|
            (faults && typical_fault?(run, captype)) ||
              (pairs && written_as_word_pair?(run, captype))
          end
        end

        # Every contiguous run of two or more members, as written.
        #
        # @param compound [CompoundForm] Compound being checked
        # @return [Array<String>] Each run's surface spelling
        def runs_of_members(compound)
          parts = compound.parts

          (0...(parts.length - 1)).flat_map do |first|
            text = parts[first].text
            ((first + 1)...parts.length).map { |last| text = join_at_seam(compound, text, last) }
          end
        end

        # Add one more member to a run, honouring the seam it arrives over.
        #
        # @param compound [CompoundForm] Compound being checked
        # @param text [String] The run so far, as written
        # @param index [Integer] Index of the member being added
        # @return [String] The run with that member appended
        def join_at_seam(compound, text, index)
          right = compound.parts[index].text
          pattern = compound.junction_pattern(index - 1)
          pattern ? pattern.surface(text, right) : text + right
        end

        # Is this run a single word someone mistyped?
        #
        # Ported from cpdrep_check (affixmgr.cxx:1286): every REP pattern is
        # tried at every occurrence. The caller owns the CHECKCOMPOUNDREP and
        # REP guard, so this runs only when both are set.
        #
        # @param word [String] The run as written
        # @param captype [Symbol] Capitalization type
        # @return [Boolean]
        def typical_fault?(word, captype)
          Kotoshu::Algorithms::Permutations.replchars(word, @aff[:REP]) do |candidate|
            if candidate.is_a?(String) &&
                affix_forms_internal(candidate, captype: captype, allow_nosuggest: true).any?
              return true
            end
          end
          false
        end

        # Does any dictionary entry contain a space?
        #
        # If none does, no space-separated candidate can ever be found, so
        # the scan below cannot succeed and is skipped outright. Nearly every
        # dictionary takes this path.
        #
        # @return [Boolean]
        def dictionary_has_word_pairs?
          return @dictionary_has_word_pairs unless @dictionary_has_word_pairs.nil?

          @dictionary_has_word_pairs =
            (@dic[:words] || []).any? { |entry| entry[:stem].include?(' ') }
        end

        # Is the compound just two words run together?
        #
        # Ported from cpdwordpair_check (affixmgr.cxx:2196): a space is tried
        # at every position, not only where two members happen to meet. The
        # caller owns the dictionary_has_word_pairs? guard.
        #
        # @param word [String] The compound as written
        # @param captype [Symbol] Capitalization type
        # @return [Boolean]
        def written_as_word_pair?(word, captype)
          return false if word.length <= 2

          (1...word.length).any? do |i|
            affix_forms_internal("#{word[0, i]} #{word[i..]}", captype: captype,
                                                               allow_nosuggest: true).any?
          end
        end
      end
    end
  end
end
