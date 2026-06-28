# frozen_string_literal: true

module Kotoshu
  module Algorithms
    # N-gram based suggestion algorithm.
    #
    # Ported from Spylls (Python) ngram_suggest.py
    #
    # This is the core Hunspell suggestion algorithm that uses n-gram
    # similarity to rank and filter spelling corrections.
    #
    # The algorithm works in three stages:
    # 1. root_score: Quick n-gram score + left common substring
    # 2. rough_affix_score: Affixed form n-gram score
    # 3. precise_affix_score: Full scoring with LCS, bigrams, etc.
    module NgramSuggest
      # Maximum number of root words to consider in first pass
      MAX_ROOTS = 100

      # Maximum number of suggestions to generate
      MAX_GUESSES = 200

      class << self
        # Main entry point for n-gram based suggestions.
        #
        # @param misspelling [String] The misspelled word
        # @param dictionary_words [Array<Hash>] Dictionary entries with stem and flags
        # @param prefixes [Hash] Prefix flags to prefix objects mapping
        # @param suffixes [Hash] Suffix flags to suffix objects mapping
        # @param known [Set<String>] Already suggested words (to avoid duplicates)
        # @param maxdiff [Integer] MAXDIFF value from aff file (0-10)
        # @param onlymaxdiff [Boolean] ONLYMAXDIFF flag
        # @param has_phonetic [Boolean] Whether PHONE table exists in aff file
        # @yield [String] Each suggestion
        #
        # This is a simplified version that works with basic dictionary structures.
        # Full implementation would need affix flag parsing and Word model objects.
        def suggest(misspelling,
                    dictionary_words:,
                    prefixes: {},
                    suffixes: {},
                    known: Set.new,
                    maxdiff: 2,
                    onlymaxdiff: true,
                    has_phonetic: false,
                    &block)

          # Stage 1: Find best root candidates by n-gram score
          root_scores = []

          dictionary_words.each do |word_entry|
            stem = word_entry[:stem] || word_entry

            # Skip words with length difference > 4
            next if (stem.length - misspelling.length).abs > 4

            # Use the best score across the stem and any ph: alt-spellings,
            # matching Hunspell's ngram_suggest behavior (without this,
            # dictionaries that rely on `ph:` for phonetic hints never
            # surface those words as candidates).
            score = if word_entry[:alt_spellings]&.any?
                      alts = word_entry[:alt_spellings].map do |alt|
                        root_score(misspelling, alt)
                      end
                      [root_score(misspelling, stem), *alts].max
                    else
                      root_score(misspelling, stem)
                    end

            # Use heap to keep only MAX_ROOTS best results
            if root_scores.size >= MAX_ROOTS
              # Keep only the best scores
              root_scores = root_scores.sort.reverse.first(MAX_ROOTS)
            end

            root_scores << [score, word_entry] if score > 0
          end

          # Stage 2: Generate affixed forms and score them
          threshold = detect_threshold(misspelling)
          guess_scores = []

          # Sort by score descending
          root_scores.sort_by { |score, _| -score }.first(MAX_ROOTS).each do |(_, root_entry)|
            root = root_entry[:stem] || root_entry

            # Alt spellings (from `ph:` morph data): if the alt form passes
            # the threshold, we suggest the STEM (not the alt) — this is
            # how Hunspell/Spylls surface dictionary entries whose canonical
            # form is unrelated but whose pronunciation matches. The alt is
            # only used for scoring; the real suggestion is the stem.
            if root_entry[:alt_spellings]
              root_entry[:alt_spellings].each do |variant|
                score = rough_affix_score(misspelling, variant.downcase)
                next unless score > threshold

                guess_scores << [score, variant, root]
              end
            end

            # Generate forms with suffixes
            forms = forms_for(root_entry, prefixes, suffixes, similar_to: misspelling)

            forms.each do |form|
              score = rough_affix_score(misspelling, form.to_s.downcase)
              next unless score > threshold

              guess_scores << [score, form.to_s, form.to_s]
            end
          end

          # Limit to MAX_GUESSES. Use stable descending sort (Ruby's sort_by
          # with a negated key is stable, matching Python's
          # sorted(key=..., reverse=True) which preserves input order for
          # ties — important for reproducibility against Hunspell fixtures
          # where dictionary order matters).
          guesses = guess_scores.sort_by { |score, _, _| -score }.first(MAX_GUESSES)

          # Stage 3: Calculate precise scores
          fact = maxdiff >= 0 ? (10.0 - maxdiff) / 5.0 : 1.0

          guesses2 = guesses.map do |score, compared, real|
            [precise_affix_score(misspelling, compared.to_s.downcase,
                                 fact, base: score, has_phonetic: has_phonetic), real.to_s]
          end.sort_by { |score, _| -score }

          # Stage 4: Filter and yield suggestions
          filter_guesses(guesses2, known: known, onlymaxdiff: onlymaxdiff, &block)
        end

        # Stage 1 scoring: 3-gram score + left common substring.
        #
        # @param word1 [String] Misspelled word
        # @param word2 [String] Possible suggestion
        # @return [Float] Root score
        def root_score(word1, word2)
          # Use lowercase for comparison as per Hunspell
          word2_lower = word2.downcase

          StringMetrics.ngram(3, word1, word2_lower, longer_worse: true) +
            StringMetrics.leftcommonsubstring(word1, word2_lower).to_f
        end

        # Stage 2 scoring: N-gram score with n=len(word1) + left common substring.
        #
        # @param word1 [String] Misspelled word
        # @param word2 [String] Possible suggestion
        # @return [Float] Rough affix score
        def rough_affix_score(word1, word2)
          # Use lowercase for comparison as per Hunspell
          word2_lower = word2.downcase

          StringMetrics.ngram(word1.length, word1, word2_lower, any_mismatch: true) +
            StringMetrics.leftcommonsubstring(word1, word2_lower).to_f
        end

        # Stage 3 scoring: Full precise scoring.
        #
        # Returns one of three "score groups":
        # - > 1000: Very good (same word, different casing)
        # - < -100: Questionable (too different)
        # - -100 to 1000: Normal suggestion
        #
        # @param word1 [String] Misspelled word
        # @param word2 [String] Possible suggestion
        # @param diff_factor [Float] Factor based on MAXDIFF (0-2)
        # @param base [Float] Base score from stage 2
        # @param has_phonetic [Boolean] Whether PHONE table exists
        # @return [Float] Precise affix score
        def precise_affix_score(word1, word2, diff_factor, base:, has_phonetic: false)
          # Use lowercase for LCS to catch case-only differences
          word1_lower = word1.downcase
          word2_lower = word2.downcase

          lcs = StringMetrics.lcslen(word1_lower, word2_lower)

          # Same characters with different casing -- "very good" suggestion
          if word1.length == word2.length && word1.length == lcs
            return base + 2000
          end

          # Score is: 2 * LCS - length difference
          result = 2 * lcs - (word1.length - word2.length).abs

          # Add common start substring length
          result += StringMetrics.leftcommonsubstring(word1_lower, word2_lower)

          # Add 1 if any characters match at same positions
          result += 1 if StringMetrics.commoncharacters(word1_lower, word2_lower) > 0

          # Add regular 4-gram score
          result += StringMetrics.ngram(4, word1_lower, word2_lower, any_mismatch: true)

          # Add weighted bigrams (both directions)
          bigrams = (
            StringMetrics.ngram(2, word1_lower, word2_lower, any_mismatch: true, weighted: true) +
            StringMetrics.ngram(2, word2_lower, word1_lower, any_mismatch: true, weighted: true)
          )
          result += bigrams

          # Apply "questionable" threshold based on diff_factor and has_phonetic
          questionable_limit = if has_phonetic
                                word2.length * diff_factor
                              else
                                (word1.length + word2.length) * diff_factor
                              end

          result -= 1000 if bigrams < questionable_limit

          result
        end

        # Calculate minimum threshold for passable suggestions.
        #
        # Mangles the word in 3 different ways (replacing each 4th char with '*')
        # and scores them to generate a minimum acceptable score.
        #
        # @param word [String] The misspelled word
        # @return [Float] Minimum threshold score
        def detect_threshold(word)
          thresh = 0.0

          (1..3).each do |start_pos|
            mangled = word.chars.map.with_index do |char, pos|
              ((pos - start_pos) % 4).zero? && pos >= start_pos ? "*" : char
            end.join

            thresh += StringMetrics.ngram(word.length, word, mangled, any_mismatch: true)
          end

          # Take average of the three scores and subtract 1
          (thresh / 3.0) - 1
        end

        # Generate all possible affixed forms for a dictionary word.
        #
        # For each flag the word carries, the corresponding affix entries are
        # considered. A suffix/prefix is only kept when (a) its condition
        # matches the stem (e.g. `[^ey]$` for the `-ed` suffix on "look"),
        # and (b) its `add` is a suffix/prefix of the misspelling. This
        # two-clause filter is what keeps the candidate space bounded — the
        # condition check rejects entries that simply can't apply to this
        # stem, and the `similar_to` check rejects entries that can't
        # produce the misspelling we're trying to fix.
        #
        # Then, for every valid suffix we produce `stem + add` (with the
        # suffix's `strip` length removed from the stem end). For every
        # valid prefix we produce `add + stem` (with the prefix's `strip`
        # length removed from the stem start). For every (prefix, suffix)
        # cross-product pair, we produce `prefix.add + (stripped stem) +
        # suffix.add`.
        #
        # The base stem is always the first form in the result.
        #
        # @param word_entry [Hash] Dictionary word with stem and flags
        # @param all_prefixes [Hash] Flag → list of prefix hashes
        # @param all_suffixes [Hash] Flag → list of suffix hashes
        # @param similar_to [String] Misspelling being corrected (used as
        #   the suffix/prefix filter)
        # @return [Array<String>] Generated affixed forms
        def forms_for(word_entry, all_prefixes, all_suffixes, similar_to:)
          stem = word_entry[:stem] || word_entry
          flags = word_entry[:flags] || []

          res = [stem]

          similar = similar_to.to_s

          suffixes = flags.flat_map { |f| all_suffixes[f] || [] }
          prefixes = flags.flat_map { |f| all_prefixes[f] || [] }

          applicable_suffixes = suffixes.select do |suffix|
            add = suffix[:affix]
            next false if add.nil? || add.empty?
            next false if similar.length < add.length
            next false unless similar.end_with?(add)

            checker = suffix[:condition_checker]
            checker.nil? || checker.matches?(stem)
          end

          applicable_prefixes = prefixes.select do |prefix|
            add = prefix[:affix]
            next false if add.nil? || add.empty?
            next false if similar.length < add.length
            next false unless similar.start_with?(add)

            checker = prefix[:condition_checker]
            checker.nil? || checker.matches?(stem)
          end

          cross = applicable_prefixes.product(applicable_suffixes).select do |prefix, suffix|
            prefix[:crossproduct] && suffix[:crossproduct]
          end

          applicable_suffixes.each do |suffix|
            strip = suffix[:strip] || ''
            add = suffix[:affix]
            root = strip.empty? ? stem : stem[0...(stem.length - strip.length)]
            res << root + add
          end

          applicable_prefixes.each do |prefix|
            strip = prefix[:strip] || ''
            add = prefix[:affix]
            root = strip.empty? ? stem : stem[strip.length..]
            res << add + root
          end

          cross.each do |prefix, suffix|
            pstrip = prefix[:strip] || ''
            sstrip = suffix[:strip] || ''
            pad = prefix[:affix]
            sad = suffix[:affix]
            base = stem.dup
            base = base[pstrip.length..] if !pstrip.empty? && base.start_with?(pstrip)
            base = base[0...(base.length - sstrip.length)] if !sstrip.empty? && base.end_with?(sstrip)
            res << pad + base + sad
          end

          res.uniq
        end

        # Filter guesses by score into quality buckets.
        #
        # Score buckets:
        # - > 1000: Very good (same word, different casing)
        # - 1000 to -100: Normal suggestions
        # - < -100: Questionable (too different)
        #
        # Stops yielding when:
        # - A very good suggestion was found and then a normal one
        # - A questionable suggestion was found (only yields one)
        #
        # @param guesses [Array<Array>] Array of [score, value] pairs
        # @param known [Set<String>] Already suggested words
        # @param onlymaxdiff [Boolean] Whether to exclude questionable
        # @yield [String] Each filtered suggestion
        def filter_guesses(guesses, known:, onlymaxdiff: true)
          seen = false
          found = 0

          guesses.each do |score, value|
            # Stop if we saw very good and now have normal suggestions
            return if seen && score <= 1000

            if score > 1000
              # Very good suggestion - set flag to only accept other very good ones
              seen = true
            elsif score < -100
              # Questionable suggestion
              # Stop if we already found good ones, or if we're excluding questionable
              return if found.positive? || onlymaxdiff
              seen = true
            end

            # Skip if this word was already suggested
            next if known.any? { |known_word| value.include?(known_word) }

            found += 1
            yield value
          end
        end
      end
    end
  end
end
