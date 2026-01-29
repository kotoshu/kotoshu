# frozen_string_literal: true

require_relative "base"

module Kotoshu
  module Dictionary
    # Custom in-memory dictionary.
    #
    # This is a simple dictionary that stores words in memory,
    # designed for runtime customization and user-defined words.
    #
    # @example Creating an empty dictionary
    #   dict = Custom.new(language_code: "en-US")
    #   dict.add_word("Kotoshu")
    #   dict.lookup?("Kotoshu")  # => true
    #
    # @example Creating with initial words
    #   dict = Custom.new(words: %w[hello world], language_code: "en")
    #   dict.lookup?("hello")  # => true
    class Custom < Base
      # @return [Boolean] Whether lookups are case-sensitive
      attr_reader :case_sensitive

      # Create a new Custom dictionary.
      #
      # @param words [Array<String>] Initial words (optional)
      # @param language_code [String] The language code
      # @param locale [String, nil] The locale (optional)
      # @param case_sensitive [Boolean] Whether lookups are case-sensitive
      # @param metadata [Hash] Additional metadata (optional)
      def initialize(words: [], language_code:, locale: nil, case_sensitive: false, metadata: {})
        super(language_code, locale: locale, metadata: metadata)

        @case_sensitive = case_sensitive
        @words = normalize_words(words)
        @word_set = build_word_set

        # Register this dictionary type
        self.class.register_type(:custom) unless Dictionary.registry.key?(:custom)
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
        prefix_len = [lookup_word.length - 1, 2].max
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
      # @param flags [Array<String>] Flags (ignored for Custom)
      # @return [Boolean] True if added
      def add_word(word, flags: [])
        return false if word.nil? || word.empty?

        lookup_word = normalize_word(word)
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

        lookup_word = normalize_word(word)
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

      # Clear all words from the dictionary.
      #
      # @return [self] Self for chaining
      def clear
        @words.clear
        @word_set.clear
        self
      end

      # Check if the dictionary is read-only.
      #
      # @return [Boolean] Always false for Custom dictionary
      def readonly?
        false
      end

      # Merge another dictionary into this one.
      #
      # @param other [Base, Array<String>] Dictionary or words to merge
      # @return [self] Self for chaining
      #
      # @example Merging another dictionary
      #   dict1 = Custom.new(words: %w[hello], language_code: "en")
      #   dict2 = Custom.new(words: %w[world], language_code: "en")
      #   dict1.merge(dict2)
      #
      # @example Merging an array of words
      #   dict.merge(%w[test example])
      def merge(other)
        words_to_add = if other.is_a?(Base)
                         other.words
                       elsif other.is_a?(Array)
                         other
                       else
                         []
                       end

        words_to_add.each { |word| add_word(word) }

        self
      end

      private

      # Normalize words for storage.
      #
      # @param words [Array<String>] Words to normalize
      # @return [Array<String>] Normalized words
      def normalize_words(words)
        words.map { |w| normalize_word(w) }.compact
      end

      # Normalize a single word.
      #
      # @param word [String] The word to normalize
      # @return [String, nil] Normalized word or nil if invalid
      def normalize_word(word)
        return nil if word.nil? || word.empty?

        word = word.strip
        return nil if word.empty?

        @case_sensitive ? word : word.downcase
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
