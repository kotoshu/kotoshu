# frozen_string_literal: true

require_relative "base"
require_relative "../core/exceptions"

module Kotoshu
  module Dictionary
    # Plain text dictionary backend.
    #
    # This dictionary reads from simple plain text word lists,
    # with support for comments and various formatting options.
    #
    # File format:
    # - One word per line
    # - Lines starting with # are comments
    # - Empty lines are ignored
    # - Supports multi-word phrases (e.g., "New York")
    #
    # @example Creating from a file
    #   dict = PlainText.new("words.txt", language_code: "en-US")
    #   dict.lookup?("hello")  # => true
    #
    # @example Creating from an array
    #   dict = PlainText.from_words(%w[hello world test], language_code: "en")
    class PlainText < Base
      # @return [String] The path to the dictionary file (or nil if created from array)
      attr_reader :path

      # @return [Boolean] Whether lookups are case-sensitive
      attr_reader :case_sensitive

      # @return [Regexp, nil] Pattern for word filtering
      attr_reader :word_pattern

      # Create a new PlainText dictionary.
      #
      # @param path [String] Path to the dictionary file
      # @param language_code [String] The language code
      # @param locale [String, nil] The locale (optional)
      # @param case_sensitive [Boolean] Whether lookups are case-sensitive
      # @param word_pattern [Regexp, nil] Pattern to filter words (optional)
      # @param metadata [Hash] Additional metadata (optional)
      def initialize(path, language_code:, locale: nil, case_sensitive: false,
                     word_pattern: nil, metadata: {})
        super(language_code, locale: locale, metadata: metadata)

        @path = File.expand_path(path)
        @case_sensitive = case_sensitive
        @word_pattern = word_pattern
        @words = load_words(@path)
        @word_set = build_word_set

        # Register this dictionary type
        self.class.register_type(:plain_text) unless Dictionary.registry.key?(:plain_text)
      end

      # Check if a word exists in the dictionary.
      #
      # @param word [String] The word to look up
      # @return [Boolean] True if the word exists
      def lookup(word)
        return false if word.nil? || word.empty?

        lookup_word = @case_sensitive ? word : word.downcase
        @word_set.key?(lookup_word)
      end

      # Generate spelling suggestions.
      #
      # Uses edit distance to find similar words in the dictionary.
      #
      # @param word [String] The misspelled word
      # @param max_suggestions [Integer] Maximum suggestions
      # @return [Array<String>] List of suggested words
      def suggest(word, max_suggestions: 10)
        return [] if word.nil? || word.empty?

        lookup_word = @case_sensitive ? word : word.downcase

        # Find words with same prefix
        prefix_len = [lookup_word.length - 1, 3].max
        prefix = lookup_word[0...prefix_len]
        candidates = @words.select { |w| w.start_with?(prefix) }

        # Calculate edit distances
        results = candidates.map do |dict_word|
          dist = edit_distance(lookup_word, dict_word)
          [dict_word, dist]
        end.select { |_, dist| dist > 0 && dist <= 2 }
         .sort_by { |_, dist| dist }
         .first(max_suggestions)
         .map(&:first)

        results
      end

      # Add a word to the dictionary.
      #
      # @param word [String] The word to add
      # @param flags [Array<String>] Flags (ignored for PlainText)
      # @return [Boolean] True if added
      def add_word(word, flags: [])
        return false if word.nil? || word.empty?

        lookup_word = @case_sensitive ? word : word.downcase
        return false if @word_set.key?(lookup_word)

        @words << lookup_word
        @word_set[lookup_word] = @words.length - 1

        true
      end

      # Remove a word from the dictionary.
      #
      # @param word [String] The word to remove
      # @return [Boolean] True if removed
      def remove_word(word)
        return false if word.nil? || word.empty?

        lookup_word = @case_sensitive ? word : word.downcase
        return false unless @word_set.key?(lookup_word)

        index = @word_set.delete(lookup_word)
        @words.delete_at(index)

        true
      end

      # Get all words in the dictionary.
      #
      # @return [Array<String>] All words
      def words
        @words.dup
      end

      # Create a dictionary from an array of words.
      #
      # @param words [Array<String>] The words
      # @param language_code [String] The language code
      # @param locale [String, nil] The locale (optional)
      # @param case_sensitive [Boolean] Whether lookups are case-sensitive
      # @return [PlainText] New dictionary
      #
      # @example
      #   dict = PlainText.from_words(%w[hello world test], language_code: "en")
      def self.from_words(words, language_code:, locale: nil, case_sensitive: false)
        dict = allocate

        dict.instance_variable_set(:@language_code, language_code.dup.freeze)
        dict.instance_variable_set(:@locale, locale&.dup&.freeze)
        dict.instance_variable_set(:@path, nil)
        dict.instance_variable_set(:@case_sensitive, case_sensitive)
        dict.instance_variable_set(:@word_pattern, nil)
        dict.instance_variable_set(:@words, words.dup.map { |w| case_sensitive ? w : w.downcase })
        dict.instance_variable_set(:@word_set, dict.instance_variable_get(:@words).each_with_index.to_h)
        dict.instance_variable_set(:@metadata, {}.freeze)

        # Register this dictionary type (unless already registered)
        register_type(:plain_text) unless Dictionary.registry.key?(:plain_text)

        dict
      end

      # Create a dictionary from a string.
      #
      # @param text [String] The text containing words (newline separated)
      # @param language_code [String] The language code
      # @param locale [String, nil] The locale (optional)
      # @param case_sensitive [Boolean] Whether lookups are case-sensitive
      # @return [PlainText] New dictionary
      #
      # @example
      #   text = "hello\nworld\ntest"
      #   dict = PlainText.from_string(text, language_code: "en")
      def self.from_string(text, language_code:, locale: nil, case_sensitive: false)
        words = text.split("\n").reject { |l| l.empty? || l.strip.start_with?("#") }
                   .map(&:strip)

        from_words(words, language_code: language_code, locale: locale,
                   case_sensitive: case_sensitive)
      end

      private

      # Load words from dictionary file.
      #
      # @param path [String] The file path
      # @return [Array<String>] List of words
      def load_words(path)
        raise DictionaryNotFoundError, path unless File.exist?(path)

        File.foreach(path, chomp: true)
            .reject { |line| line.empty? || line.strip.start_with?("#") }
            .map(&:strip)
            .select { |word| @word_pattern.nil? || word.match?(@word_pattern) }
            .map { |word| @case_sensitive ? word : word.downcase }
      end

      # Build a hash set for O(1) lookups.
      #
      # @return [Hash] Word to index mapping
      def build_word_set
        @words.each_with_index.to_h
      end

      # Calculate Levenshtein edit distance.
      #
      # @param str1 [String] First string
      # @param str2 [String] Second string
      # @return [Integer] Edit distance
      def edit_distance(str1, str2)
        return str2.length if str1.empty?
        return str1.length if str2.empty?

        # Use smaller string for inner loop
        if str1.length > str2.length
          str1, str2 = str2, str1
        end

        previous = (0..str1.length).to_a

        str2.each_char.with_index do |char2, j|
          current = [j + 1]

          str1.each_char.with_index do |char1, i|
            insert_cost = current[i] + 1
            delete_cost = previous[i + 1] + 1
            substitute_cost = previous[i] + (char1 == char2 ? 0 : 1)

            current << [insert_cost, delete_cost, substitute_cost].min
          end

          previous = current
        end

        previous.last
      end
    end
  end
end
