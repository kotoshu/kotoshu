# frozen_string_literal: true

module Kotoshu
  module Algorithms
    # Main suggestion orchestration for spell checking.
    #
    # Ported from Spylls (Python) suggest.py
    #
    # On a bird's-eye view level, suggest does:
    # 1. Tries small word "edits" (remove letters, insert letters, swap letters)
    #    and checks (with the help of Lookup) if there are any valid ones
    # 2. If no good suggestions found, tries "ngram-based" suggestions
    #    (calculating ngram-based distance to all dictionary words)
    # 3. If possible, tries metaphone-based suggestions (phonetic)
    #
    # Note: Spylls's implementation takes one liberty vs Hunspell:
    # In Hunspell, ngram suggestions and phonetic suggestions are done in the
    # same cycle. Spylls does them in two separate cycles for clarity.
    #
    # To follow algorithm details, see Suggest.suggestions method.
    module Suggest
      MAXPHONSUGS = 2
      MAXSUGGESTIONS = 15
      GOOD_EDITS = %w[spaceword uppercase replchars].freeze

      # Represents a single word suggestion.
      #
      # Suggestions are produced internally to store enough information to
      # make sure it is a good one.
      class Suggestion
        # @return [String] Actual suggestion text
        attr_reader :text

        # @return [String] How suggestion was produced (same as method name)
        attr_reader :kind

        def initialize(text, kind)
          @text = text
          @kind = kind
        end

        # Create a copy with changes.
        #
        # @param changes [Hash] Changes to apply
        # @return [Suggestion] New suggestion with changes applied
        def replace(**changes)
          self.class.new(
            changes.fetch(:text, @text),
            changes.fetch(:kind, @kind)
          )
        end

        # String representation.
        #
        # @return [String]
        def to_s
          @text
        end

        # Inspect string.
        #
        # @return [String]
        def inspect
          "Suggestion[#{@kind}](#{@text.inspect})"
        end
      end

      # Represents suggestion to split words into several.
      #
      # Used when the algorithm suggests that a misspelled word should be
      # split into multiple dictionary words.
      class MultiWordSuggestion
        # @return [Array<String>] List of words
        attr_reader :words

        # @return [String] Same as Suggestion.kind
        attr_reader :source

        # @return [Boolean] Whether words can be joined by dash
        attr_reader :allow_dash

        def initialize(words, source, allow_dash: true)
          @words = words
          @source = source
          @allow_dash = allow_dash
        end

        # Convert to string suggestion.
        #
        # @param separator [String] Separator to join words with
        # @return [Suggestion] String suggestion with joined words
        def stringify(separator = ' ')
          Suggestion.new(@words.join(separator), @source)
        end

        # Inspect string.
        #
        # @return [String]
        def inspect
          "Suggestion[#{@source}](#{@words.inspect})"
        end
      end

      # Main suggestion class.
      #
      # Typically, you would not use this directly, but you might want to for
      # experiments.
      #
      # Example:
      #   dictionary = Kotoshu::Dictionary.load('en_US')
      #   suggester = dictionary.suggester
      #
      #   suggester.suggestions('spylls') do |suggestion|
      #     puts suggestion
      #   end
      #
      #   # Output:
      #   # Suggestion[badchar](spell)
      #   # Suggestion[badchar](spill)
      class Suggester
        # @return [Object] Aff data structure (from aff file)
        attr_reader :aff

        # @return [Object] Dic data structure (from dic file)
        attr_reader :dic

        # @return [Object] Lookup object
        attr_reader :lookup

        def initialize(aff, dic, lookup)
          @aff = aff
          @dic = dic
          @lookup = lookup

          # Prepare words for ngram (exclude those with bad flags)
          bad_flags = [
            @aff[:FORBIDDENWORD],
            @aff[:NOSUGGEST],
            @aff[:ONLYINCOMPOUND]
          ].compact

          @words_for_ngram = @dic[:words].select do |word|
            flags = word[:flags] || []
            (flags & bad_flags).empty?
          end
        end

        # Outer "public" interface: returns all valid suggestions as strings.
        #
        # Returns an enumerator for lazy evaluation.
        #
        # @param word [String] Word to check
        # @return [Enumerator<String>] Suggestions as strings
        def call(word)
          return enum_for(:call, word) unless block_given?

          suggestions(word) do |suggestion|
            yield suggestion.text
          end
        end

        # Main suggestion search loop.
        #
        # What it does, in general:
        # 1. Generates possible misspelled word cases (capitalization variants)
        # 2. Produces word edits with edits, checks them with Lookup
        # 3. If needed, produces ngram-based suggestions
        # 4. If needed, produces phonetically similar suggestions
        #
        # @param word [String] Word to check
        # @yield [Suggestion, MultiWordSuggestion] Each suggestion object
        def suggestions(word, &block)
          return enum_for(:suggestions, word) unless block

          # Track all suggestions we've already yielded
          handled = Set.new

          # Helper: Check if suggestion is a valid word
          is_good_suggestion = ->(w) do
            # Check if there's any good form of this exact word
            # Note: We check good_forms directly to avoid ICONV and dash-breaking
            good_forms = @lookup.good_forms(w, capitalization: false, allow_nosuggest: false)
            good_forms.any?
          end

          # Helper: same as is_good_suggestion but with capitalization variants.
          # Used for CHECKSHARPS where the candidate differs in case from any
          # dictionary entry (e.g. "MÜSSIG" vs stem "müßig").
          is_good_suggestion_cap = ->(w) do
            @lookup.good_forms(w, capitalization: true, allow_nosuggest: false).any?
          end

          # Helper: Check if word is forbidden
          is_forbidden = ->(w) do
            return false unless @aff[:FORBIDDENWORD]

            @dic[:has_flag]&.call(w, @aff[:FORBIDDENWORD]) || false
          end

          # Get capitalization type and variants
          captype, variants = @aff[:casing].corrections(word)

          # Special case: CHECKSHARPS with sharp-s in word
          #
          # German capitalizes sharp s as SS — when CHECKSHARPS is on, an
          # ALLCAPS word like "MÜßIG" is wrong even though its stem "müßig"
          # carries KEEPCASE. We replace ß→SS and try the result as a
          # candidate.
          if @aff[:CHECKSHARPS] && captype == Capitalization::Type::ALL && word.include?('ß')
            sharp_swapped = word.gsub('ß', 'SS')
            if is_good_suggestion_cap.call(sharp_swapped)
              yield Suggestion.new(sharp_swapped, 'checksharps')
              return
            end
          end

          # Special case: FORCEUCASE with NO capitalization
          if @aff[:FORCEUCASE] && captype == Capitalization::Type::NO
            @aff[:casing].capitalize(word).each do |capitalized|
              if is_good_suggestion.call(capitalized)
                yield Suggestion.new(capitalized.capitalize, 'forceucase')
                return
              end
            end
          end

          good_edits_found = false

          # Process each capitalization variant
          variants.each_with_index do |variant, idx|
            # If different from original and is good, suggest it
            if idx.positive? && is_good_suggestion.call(variant)
              handle_found(
                Suggestion.new(variant, 'case'),
                word: word,
                captype: captype,
                is_forbidden: is_forbidden,
                handled: handled, &block
              )
            end

            # Generate and check edits (non-compound first)
            nocompound = false

            edit_suggestions(variant, compounds: false, limit: MAXSUGGESTIONS) do |suggestion|
              handle_found(
                suggestion,
                word: word,
                captype: captype,
                is_forbidden: is_forbidden,
                handled: handled,
                check_inclusion: false
              ) do |handled_suggestion|
                yield handled_suggestion

                kind = handled_suggestion.kind
                good_edits_found = true if GOOD_EDITS.include?(kind)
                nocompound = true if %w[uppercase replchars mapchars].include?(kind)

                # If we found a spaceword that's in the dictionary as a whole,
                # that's the only suggestion we need
                return if kind == 'spaceword'
              end
            end

            # Generate compound suggestions if not excluded
            unless nocompound
              limit = @aff[:MAXCPDSUGS] || MAXSUGGESTIONS
              edit_suggestions(variant, compounds: true, limit: limit) do |suggestion|
                handle_found(
                  suggestion,
                  word: word,
                  captype: captype,
                  is_forbidden: is_forbidden,
                  handled: handled,
                  check_inclusion: false
                ) do |handled_suggestion|
                  yield handled_suggestion
                  kind = handled_suggestion.kind
                  good_edits_found = true if GOOD_EDITS.include?(kind)
                end
              end
            end
          end

          # Skip ngram/phonetic if we found good edits
          return if good_edits_found

          # Try fixing words with dashes
          if word.include?('-') && handled.none? { |s| s.include?('-') }
            chunks = word.split('-')
            chunks.each_with_index do |chunk, idx|
              next if is_good_suggestion.call(chunk)

              # Try all suggestions for this chunk
              call(chunk).each do |sug|
                candidate = chunks[0...idx] + [sug] + chunks[(idx + 1)..]
                candidate_str = candidate.join('-')

                # Check if the whole word with replacement is good
                if @lookup.call(candidate_str, capitalization: true, allow_nosuggest: true)
                  yield Suggestion.new(candidate_str, 'dashes')
                end
              end

              # Only try one misspelled chunk
              break
            end
          end

          # Ngram-based suggestions
          if @aff[:MAXNGRAMSUGS]&.positive?
            limit = @aff[:MAXNGRAMSUGS]
            ngrams_seen = 0
            ngram_suggestions(word, handled: handled) do |sug|
              handle_found(
                Suggestion.new(sug, 'ngram'),
                word: word,
                captype: captype,
                is_forbidden: is_forbidden,
                handled: handled,
                check_inclusion: true
              ) do |suggestion|
                yield suggestion
                ngrams_seen += 1
              end
              # break out of ngram_suggestions, not just handle_found
              break if ngrams_seen >= limit
            end
          end

          # Phonetic suggestions
          if @aff[:PHONE]
            phonet_seen = 0
            phonet_suggestions(word) do |sug|
              handle_found(
                Suggestion.new(sug, 'phonet'),
                word: word,
                captype: captype,
                is_forbidden: is_forbidden,
                handled: handled,
                check_inclusion: true
              ) do |suggestion|
                yield suggestion
                phonet_seen += 1
              end
              break if phonet_seen >= MAXPHONSUGS
            end
          end
        end

        # Generate all possible word edits in order of priority.
        #
        # Order is important - it's the order user receives suggestions.
        #
        # @param word [String] Word to mutate
        # @yield [Suggestion, MultiWordSuggestion] Each edit suggestion
        def edits(word)
          # Uppercase suggestion (html -> HTML)
          yield Suggestion.new(@aff[:casing].upper(word), 'uppercase')

          # REP table replacements
          reptable = @aff[:REP] || []
          Permutations.replchars(word, reptable) do |suggestion|
            if suggestion.is_a?(Array)
              # Multi-word suggestion from REP with underscore
              yield Suggestion.new(suggestion.join(' '), 'replchars')
              yield MultiWordSuggestion.new(suggestion, 'replchars', allow_dash: false)
            else
              yield Suggestion.new(suggestion, 'replchars')
            end
          end

          # Split into two words (spaceword)
          Permutations.twowords(word) do |words|
            yield Suggestion.new(words.join(' '), 'spaceword')
            yield Suggestion.new(words.join('-'), 'spaceword') if use_dash?
          end

          # MAP table (related character replacements)
          maptable = @aff[:MAP] || []
          Permutations.mapchars(word, maptable) do |suggestion|
            yield Suggestion.new(suggestion, 'mapchars')
          end

          # Swap adjacent characters
          Permutations.swapchar(word) do |suggestion|
            yield Suggestion.new(suggestion, 'swapchar')
          end

          # Long swaps (up to 4 chars distance)
          Permutations.longswapchar(word) do |suggestion|
            yield Suggestion.new(suggestion, 'longswapchar')
          end

          # Replace with keyboard-adjacent chars
          layout = @aff[:KEY] || ''
          Permutations.badcharkey(word, layout) do |suggestion|
            yield Suggestion.new(suggestion, 'badcharkey')
          end

          # Remove one character
          Permutations.extrachar(word) do |suggestion|
            yield Suggestion.new(suggestion, 'extrachar')
          end

          # Insert one character (from TRY string)
          trystring = @aff[:TRY] || ''
          Permutations.forgotchar(word, trystring) do |suggestion|
            yield Suggestion.new(suggestion, 'forgotchar')
          end

          # Move character forward/backward
          Permutations.movechar(word) do |suggestion|
            yield Suggestion.new(suggestion, 'movechar')
          end

          # Replace each character
          Permutations.badchar(word, trystring) do |suggestion|
            yield Suggestion.new(suggestion, 'badchar')
          end

          # Fix two-character doubling
          Permutations.doubletwochars(word) do |suggestion|
            yield Suggestion.new(suggestion, 'doubletwochars')
          end

          # Split by space in all positions
          unless @aff[:NOSPLITSUGS]
            Permutations.twowords(word) do |words|
              yield MultiWordSuggestion.new(words, 'twowords', allow_dash: use_dash?)
            end
          end
        end

        # Generate edit suggestions and filter for valid words.
        #
        # @param word [String] Word to generate edits for
        # @param compounds [Boolean] Whether to check compound words
        # @param limit [Integer] Maximum number of suggestions to yield
        # @yield [Suggestion, MultiWordSuggestion] Each valid edit suggestion
        def edit_suggestions(word, compounds:, limit:)
          count = 0

          edits(word) do |suggestion|
            break if count > limit

            filtered = filter_suggestion(suggestion, compounds)
            next unless filtered

            Array(filtered).each do |sug|
              yield sug
              count += 1
            end
          end
        end

        # Generate ngram-based suggestions.
        #
        # @param word [String] Misspelled word
        # @param handled [Set<String>] Already suggested words
        # @yield [String] Each ngram suggestion
        def ngram_suggestions(word, handled:, &block)
          return unless @aff[:MAXNGRAMSUGS]&.positive?

          known_lower = handled.map(&:downcase).to_set

          NgramSuggest.suggest(
            word.downcase,
            dictionary_words: @words_for_ngram,
            prefixes: @aff[:prefixes_by_flag] || {},
            suffixes: @aff[:suffixes_by_flag] || {},
            known: known_lower,
            maxdiff: @aff[:MAXDIFF] || 2,
            onlymaxdiff: @aff[:ONLYMAXDIFF] || false,
            has_phonetic: !@aff[:PHONE].nil?, &block
          )
        end

        # Generate phonetic suggestions.
        #
        # @param word [String] Misspelled word
        # @yield [String] Each phonetic suggestion
        def phonet_suggestions(word, &)
          return unless @aff[:PHONE]

          PhonetSuggest.suggest(
            word,
            dictionary_words: @words_for_ngram,
            table: @aff[:PHONE], &
          )
        end

        # Check if dashes are allowed for joining words.
        #
        # Definition from Hunspell: Either dash is in TRY directive, or TRY
        # indicates Latinic script (by having 'a').
        #
        # @return [Boolean] Whether dashes are allowed
        def use_dash?
          try_chars = @aff[:TRY] || ''
          try_chars.include?('-') || try_chars.include?('a')
        end

        private

        # Handle a found suggestion with proper capitalization and validation.
        #
        # @param suggestion [Suggestion, MultiWordSuggestion] Raw suggestion
        # @param word [String] Original misspelled word (used for case preservation)
        # @param captype [Symbol] Original word's capitalization type
        # @param is_forbidden [Proc] Function to check if word is forbidden
        # @param handled [Set<String>] Already handled suggestions
        # @param check_inclusion [Boolean] Whether to check for subsumption
        # @yield [Suggestion] Processed suggestion if valid
        def handle_found(suggestion, word:, captype:, is_forbidden:, handled:, check_inclusion: false)
          return unless block_given?

          text = suggestion.text

          # Apply capitalization coercion
          unless @aff[:KEEPCASE] && suggestion_has_keepcase_flag?(suggestion)
            text = @aff[:casing].coerce(text, captype)

            # If coerced form is forbidden, revert to original
            if text != suggestion.text && is_forbidden.call(text)
              text = suggestion.text
            end

            # "aNew" coerces to "a new"; restore the original word's capital
            # at the split boundary so it reads "a New" (matching the input's
            # HUHINIT/HUH case pattern).
            if [Capitalization::Type::HUH, Capitalization::Type::HUHINIT].include?(captype) && text.include?(' ')
              pos = text.index(' ')
              if pos && text[pos + 1] != word[pos] && text[pos + 1]&.upcase == word[pos]
                text = text[0...pos + 1] + word[pos] + text[(pos + 2)..]
              end
            end
          end

          # Skip if forbidden
          return if is_forbidden.call(text)

          # Apply OCONV transformation if present
          if @aff[:OCONV]
            text = @aff[:OCONV].call(text)
          end

          # Skip if already seen
          return if handled.include?(text)

          # Skip if subsumed by existing suggestion
          if check_inclusion && handled.any? { |prev| text.downcase.include?(prev.downcase) }
            return
          end

          handled.add(text)
          yield suggestion.replace(text: text)
        end

        # Check if suggestion's stem carries the KEEPCASE flag.
        #
        # Mirrors Spylls suggest.py:206: when KEEPCASE is set and the
        # candidate's stem has the flag, the candidate's case must NOT be
        # coerced to the misspelling's captype (e.g. input "FOO" should
        # suggest "foo", not "FOO"). The CHECKSHARPS exception is that for
        # ß-containing words, KEEPCASE has its German-specific meaning
        # (ß↔SS) and case coercion still applies.
        #
        # @param suggestion [Suggestion, MultiWordSuggestion]
        # @return [Boolean]
        def suggestion_has_keepcase_flag?(suggestion)
          return false unless @aff[:KEEPCASE]
          return false if @aff[:CHECKSHARPS] && suggestion.text.include?('ß')

          @dic[:has_flag]&.call(suggestion.text, @aff[:KEEPCASE]) || false
        end

        # Filter suggestion to only valid words.
        #
        # For MultiWordSuggestion with allow_dash and use_dash?, returns BOTH
        # the space-joined and dash-joined forms (matching Hunspell behavior).
        #
        # @param suggestion [Suggestion, MultiWordSuggestion]
        # @param compounds [Boolean] Whether to check compound forms
        # @return [Suggestion, Array<Suggestion>, nil] Filtered suggestion(s) or nil
        def filter_suggestion(suggestion, compounds)
          is_good = ->(word) do
            if compounds
              @lookup.good_forms(word, capitalization: false, allow_nosuggest: false, affix_forms: false).any?
            else
              @lookup.good_forms(word, capitalization: false, allow_nosuggest: false, compound_forms: false).any?
            end
          end

          if suggestion.is_a?(MultiWordSuggestion)
            return nil unless suggestion.words.all? { |w| is_good.call(w) }

            if suggestion.allow_dash && use_dash?
              [suggestion.stringify(' '), suggestion.stringify('-')]
            else
              suggestion.stringify(' ')
            end
          else
            return nil unless is_good.call(suggestion.text)

            suggestion
          end
        end
      end
    end
  end
end
