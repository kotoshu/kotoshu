# frozen_string_literal: true

module Kotoshu
  module Suggestions
    # Per-dictionary sweep invariants, built once at the first
    # suggestion sweep and kept for the dictionary's lifetime.
    #
    # Every strategy used to walk the whole word list per sweep and
    # compute per-word values before its gate — the length window, the
    # Soundex code, the n-gram length bound — so a full dictionary paid
    # for work on words a sweep was about to skip. Those per-word
    # values never change with the query: they are computed here one
    # time (char lengths, packed Soundex codes, length buckets), and
    # the sweeps touch only the entries their gates admit.
    #
    # Soundex codes are the 4-character {Algorithms::Soundex} strings
    # (frozen); two letter-less words both code to +""+ and compare
    # equal, exactly as the live computation does. Lengths are char
    # counts. +by_length+ groups word indices by length in original
    # order so the edit-distance sweep can iterate only its ±2 window;
    # {#indices_in_length_range} restores word-list order because ties
    # in the strategies' ranking sorts are decided by input order.
    #
    # The index derives only from the word list it was built over.
    # Dictionary backends memoize it (see
    # {Dictionary::Base#sweep_index}) and invalidate the memo wherever
    # they mutate the word list ({Dictionary::Base#add_word} /
    # {Dictionary::Base#remove_word} implementations).
    #
    # This mirrors SweepIndex in kotoshu-rs
    # (kotoshu/src/suggest/sweep_index.rs).
    class SweepIndex
      # @return [Array<String>] The words in list order (as captured at
      #   build time)
      attr_reader :words

      # Build an index over a word list.
      #
      # @param words [Array<String>] Dictionary words in list order
      # @return [SweepIndex] The built index
      def self.build(words)
        lengths = Array.new(words.length)
        soundex_codes = Array.new(words.length)
        by_length = {}
        words.each_with_index do |word, idx|
          length = word.length
          lengths[idx] = length
          soundex_codes[idx] = Algorithms::Soundex.code(word).freeze
          (by_length[length] ||= []) << idx
        end
        new(words, lengths, soundex_codes, by_length)
      end

      # Create an index from prebuilt structures.
      #
      # @param words [Array<String>] The indexed words in list order
      # @param lengths [Array<Integer>] Char length per word index
      # @param soundex_codes [Array<String>] Soundex code per word index
      # @param by_length [Hash<Integer, Array<Integer>>] Length => word
      #   indices in list order
      def initialize(words, lengths, soundex_codes, by_length)
        @words = words
        @lengths = lengths
        @soundex_codes = soundex_codes
        @by_length = by_length
      end

      # Char length of the word at +idx+.
      #
      # @param idx [Integer] Word index
      # @return [Integer] Char count
      def length(idx)
        @lengths[idx]
      end

      # Soundex code of the word at +idx+ — equal codes compare equal,
      # including two letter-less empty codes.
      #
      # @param idx [Integer] Word index
      # @return [String] The frozen 4-char (or empty) Soundex code
      def soundex(idx)
        @soundex_codes[idx]
      end

      # Word indices whose length is within +min..max+, every word in
      # exactly one bucket, each bucket in original order.
      #
      # @param min [Integer] Minimum length (inclusive)
      # @param max [Integer] Maximum length (inclusive)
      # @return [Array<Integer>] Matching indices in word-list order
      def indices_in_length_range(min, max)
        hits = []
        (min..max).each do |length|
          bucket = @by_length[length]
          hits.concat(bucket) if bucket
        end
        # Restore the word-list order the strategies' candidate arrays
        # were built in before this index existed — ties in the ranking
        # sort are decided by input order, so this must not drift.
        hits.sort!
      end

      # Words whose length is within +min..max+, in word-list order —
      # exactly the set and order {Dictionary::Base#find_by_length_range}
      # historically returned.
      #
      # @param min [Integer] Minimum length (inclusive)
      # @param max [Integer] Maximum length (inclusive)
      # @return [Array<String>] Matching words in word-list order
      def words_in_length_range(min, max)
        indices_in_length_range(min, max).map { |idx| @words[idx] }
      end

      # Yield every word with its memoized char length.
      #
      # @yield [String, Integer] Each word and its char count
      # @return [void]
      def each_with_length
        @words.each_with_index do |word, idx|
          yield word, @lengths[idx]
        end
        nil
      end

      # Yield every word with its memoized Soundex code.
      #
      # @yield [String, String] Each word and its Soundex code
      # @return [void]
      def each_with_soundex
        @words.each_with_index do |word, idx|
          yield word, @soundex_codes[idx]
        end
        nil
      end
    end
  end
end
