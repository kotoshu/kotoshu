# frozen_string_literal: true

require_relative "base"
require_relative "../core/exceptions"

module Kotoshu
  module Dictionary
    # Unix system dictionary backend.
    #
    # This dictionary reads from Unix-style system dictionary files,
    # typically located at `/usr/share/dict/words` or symlinks to
    # dictionaries like `web2` (Webster's Second International).
    #
    # @example Using system dictionary
    #   dict = UnixWords.new("/usr/share/dict/words", language_code: "en-US")
    #   dict.lookup?("hello")     # => true
    #   dict.suggest("helo")      # => ["hello", "help", "held", ...]
    #
    # @example Auto-detecting system dictionary
    #   dict = UnixWords.detect(language_code: "en-US")
    class UnixWords < Base
      # Standard system paths to check for dictionaries.
      SYSTEM_PATHS = [
        "/usr/share/dict/words",
        "/usr/share/dict/web2",
        "/usr/share/dict/american-english",
        "/usr/share/dict/british-english",
        "/usr/dict/words",
        "/System/Library/Assets/com_apple_MobileAsset_DictionaryServices_dictionaryOS/Dictionary/words" # macOS
      ].freeze

      # @return [String] The path to the dictionary file
      attr_reader :path

      # @return [Boolean] Whether lookups are case-sensitive
      attr_reader :case_sensitive

      # Create a new UnixWords dictionary.
      #
      # @param path [String] Path to the dictionary file
      # @param language_code [String] The language code
      # @param locale [String, nil] The locale (optional)
      # @param case_sensitive [Boolean] Whether lookups are case-sensitive
      # @param metadata [Hash] Additional metadata (optional)
      def initialize(path, language_code:, locale: nil, case_sensitive: false, metadata: {})
        super(language_code, locale: locale, metadata: metadata)

        @path = File.expand_path(path)
        @case_sensitive = case_sensitive
        @words = load_words(@path)
        @word_set = build_word_set

        # Register this dictionary type
        self.class.register_type(:unix_words) unless Dictionary.registry.key?(:unix_words)
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

        # For now, use simple prefix matching and edit distance
        # This will be improved with the suggestion algorithms
        lookup_word = @case_sensitive ? word : word.downcase

        # Find words with same prefix
        prefix_len = [lookup_word.length - 1, 3].max
        prefix = lookup_word[0...prefix_len]
        candidates = @words.select { |w| w.start_with?(prefix) }

        # Calculate edit distances
        results = candidates.map do |dict_word|
          dist = edit_distance(lookup_word, dict_word)
          [dict_word, dist]
        end.select { |_, dist| dist > 0 && dist <= 2 }  # Only close matches
         .sort_by { |_, dist| dist }
         .first(max_suggestions)
         .map(&:first)

        results
      end

      # Add a word to the dictionary.
      #
      # @param word [String] The word to add
      # @param flags [Array<String>] Flags (ignored for UnixWords)
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

      # Detect system dictionary path.
      #
      # Checks standard system paths for an existing dictionary file.
      #
      # @return [String, nil] The detected path or nil
      #
      # @example
      #   UnixWords.detect_system_dictionary  # => "/usr/share/dict/words"
      def self.detect_system_dictionary
        SYSTEM_PATHS.find { |p| File.exist?(p) }
      end

      # Create a dictionary by auto-detecting system dictionary.
      #
      # @param language_code [String] The language code
      # @param locale [String, nil] The locale (optional)
      # @param case_sensitive [Boolean] Whether lookups are case-sensitive
      # @return [UnixWords, nil] The dictionary or nil if not found
      #
      # @example
      #   dict = UnixWords.detect(language_code: "en-US")
      def self.detect(language_code:, locale: nil, case_sensitive: false)
        path = detect_system_dictionary
        return nil unless path

        new(path, language_code: language_code, locale: locale,
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
            .reject { |line| line.empty? || line.start_with?("#") }
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
