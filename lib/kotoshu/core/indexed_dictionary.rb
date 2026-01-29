# frozen_string_literal: true

module Kotoshu
  module Core
    # Indexed dictionary for efficient word lookup with multiple indexes.
    # This is MORE model-driven than Spylls which uses simple hash indices.
    #
    # This is a proper domain model with rich behavior including:
    # - Multiple indexes (case-sensitive, case-insensitive, prefix, suffix)
    # - Rich query methods
    # - Index management
    # - Domain-specific behavior
    class IndexedDictionary
      attr_reader :words, :size

      # @param words [Array<String>] Initial words to add
      def initialize(words = [])
        @words = []
        @indexes = {
          exact: {},              # case_sensitive: word => [positions]
          lowercase: {},          # case_insensitive: word.downcase => [positions]
          prefix: {},             # prefix => [words]
          suffix: {},             # suffix => [words]
          flag: {}                # flag => [words] (future: for Hunspell)
        }
        @size = 0

        words.each { |word| add_word(word) }
      end

      # Add a word to the dictionary with optional metadata.
      #
      # @param word [String] The word to add
      # @param metadata [Hash] Optional metadata associated with the word
      # @return [IndexedDictionary] Self for chaining
      def add_word(word, metadata = {})
        # Store the word with its index and metadata
        entry = { word: word, index: @size, metadata: metadata }
        @words << entry
        @size += 1

        # Update exact index (case-sensitive)
        @indexes[:exact][word] ||= []
        @indexes[:exact][word] << @size - 1

        # Update lowercase index (case-insensitive)
        lower = word.downcase
        @indexes[:lowercase][lower] ||= []
        @indexes[:lowercase][lower] << @size - 1

        # Update prefix indexes (for prefix searching)
        (1...word.length).each do |i|
          prefix = word[0...i]
          @indexes[:prefix][prefix] ||= []
          @indexes[:prefix][prefix] << word
        end

        # Update suffix indexes (for suffix searching)
        (1...word.length).each do |i|
          suffix = word[i..]
          @indexes[:suffix][suffix] ||= []
          @indexes[:suffix][suffix] << word
        end

        self
      end
      alias << add_word

      # Add multiple words.
      #
      # @param new_words [Array<String>] Words to add
      # @return [IndexedDictionary] Self for chaining
      def add_words(new_words)
        new_words.each { |word| add_word(word) }
        self
      end

      # Check if a word exists (case-sensitive).
      #
      # @param word [String] The word to check
      # @return [Boolean] True if word exists
      def has_word?(word)
        @indexes[:exact].key?(word)
      end
      alias include? has_word?
      alias contains? has_word?

      # Check if a word exists (case-insensitive).
      #
      # @param word [String] The word to check
      # @return [Boolean] True if word exists (any case)
      def has_word_ignorecase?(word)
        @indexes[:lowercase].key?(word.downcase)
      end

      # Look up a word (case-sensitive).
      #
      # @param word [String] The word to look up
      # @return [Hash, nil] Word entry or nil
      def lookup(word)
        indices = @indexes[:exact][word]
        return nil if indices.nil? || indices.empty?

        @words[indices.first]
      end

      # Look up a word (case-insensitive).
      #
      # @param word [String] The word to look up
      # @return [Hash, nil] Word entry or nil
      def lookup_ignorecase(word)
        indices = @indexes[:lowercase][word.downcase]
        return nil if indices.nil? || indices.empty?

        @words[indices.first]
      end

      # Find all words with a given prefix.
      #
      # @param prefix [String] The prefix to match
      # @param ignore_case [Boolean] Whether to ignore case
      # @return [Array<String>] Words with the prefix
      def find_by_prefix(prefix, ignore_case: false)
        if ignore_case
          prefix_lower = prefix.downcase
          all_words.select { |w| w.downcase.start_with?(prefix_lower) }
        else
          @indexes[:prefix].fetch(prefix, []).dup
        end
      end

      # Find all words with a given suffix.
      #
      # @param suffix [String] The suffix to match
      # @param ignore_case [Boolean] Whether to ignore case
      # @return [Array<String>] Words with the suffix
      def find_by_suffix(suffix, ignore_case: false)
        if ignore_case
          suffix_lower = suffix.downcase
          all_words.select { |w| w.downcase.end_with?(suffix_lower) }
        else
          @indexes[:suffix].fetch(suffix, []).dup
        end
      end

      # Find words matching a pattern.
      #
      # @param pattern [Regexp] The pattern to match
      # @return [Array<String>] Matching words
      def find_by_pattern(pattern)
        all_words.select { |w| w.match?(pattern) }
      end

      # Find words of a specific length.
      #
      # @param length [Integer] The exact length
      # @return [Array<String>] Words of the given length
      def find_by_length(length)
        all_words.select { |w| w.length == length }
      end

      # Find words within a length range.
      #
      # @param min_length [Integer] Minimum length
      # @param max_length [Integer] Maximum length
      # @return [Array<String>] Words within the length range
      def find_by_length_range(min_length:, max_length:)
        all_words.select { |w| w.length >= min_length && w.length <= max_length }
      end

      # Get all words in the dictionary.
      #
      # @return [Array<String>] All words
      def all_words
        @words.map { |entry| entry[:word] }
      end

      # Get random words from the dictionary.
      #
      # @param count [Integer] Number of random words
      # @return [Array<String>] Random words
      def random_words(count: 1)
        return [] if @words.empty?

        indices = (0...@size).to_a.sample(count)
        indices.map { |i| @words[i][:word] }
      end

      # Get words starting with each letter (A-Z).
      #
      # @return [Hash] Hash of letter => word count
      def count_by_first_letter
        result = Hash.new(0)
        all_words.each do |word|
          next if word.empty?
          letter = word[0].upcase
          result[letter] += 1
        end
        result
      end

      # Get word length distribution.
      #
      # @return [Hash] Hash of length => count
      def count_by_length
        result = Hash.new(0)
        all_words.each { |word| result[word.length] += 1 }
        result
      end

      # Check if the dictionary is empty.
      #
      # @return [Boolean] True if empty
      def empty?
        @size.zero?
      end

      # Iterate over all words.
      #
      # @yield [word] Each word
      # @return [Enumerator] Enumerator if no block given
      def each_word
        return enum_for(:each_word) unless block_given?
        @words.each { |entry| yield entry[:word] }
      end

      # Iterate over all words with indices.
      #
      # @yield [word, index] Each word and its index
      # @return [Enumerator] Enumerator if no block given
      def each_with_index
        return enum_for(:each_with_index) unless block_given?
        @words.each { |entry| yield entry[:word], entry[:index] }
      end

      # Build a Trie from the dictionary words.
      #
      # @return [Trie] New trie containing all words
      def to_trie
        require_relative "trie/trie"
        require_relative "trie/builder"

        Trie::Builder.from_array(all_words)
      end

      # Get statistics about the dictionary.
      #
      # @return [Hash] Statistics
      def statistics
        lengths = all_words.map(&:length)

        {
          total_words: @size,
          unique_words: all_words.uniq.size,
          min_length: lengths.min || 0,
          max_length: lengths.max || 0,
          avg_length: lengths.empty? ? 0 : (lengths.sum.to_f / lengths.size).round(2),
          count_by_first_letter: count_by_first_letter,
          count_by_length: count_by_length
        }
      end

      # Convert to string.
      #
      # @return [String] String representation
      def to_s
        "IndexedDictionary(size: #{@size})"
      end
      alias inspect to_s

      # Create indexed dictionary from a file.
      #
      # @param path [String] Path to word list file
      # @return [IndexedDictionary] New dictionary
      def self.from_file(path)
        words = File.foreach(path, chomp: true).reject { |l| l.empty? || l.start_with?("#") }
        new(words)
      end

      # Create indexed dictionary from a Trie.
      #
      # @param trie [Trie] The trie to convert
      # @return [IndexedDictionary] New dictionary
      def self.from_trie(trie)
        words = trie.all_words
        new(words)
      end
    end
  end
end
