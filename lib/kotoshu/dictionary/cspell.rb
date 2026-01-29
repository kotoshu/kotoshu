# frozen_string_literal: true

require_relative "base"
require_relative "../core/trie/trie"
require_relative "../core/trie/builder"
require_relative "../core/exceptions"

module Kotoshu
  module Dictionary
    # CSpell dictionary backend.
    #
    # This dictionary reads CSpell-formatted dictionary files (plain text .txt
    # or compressed .trie files). CSpell is the spell checker used by VS Code.
    #
    # File format:
    # - .txt: Plain text with one word per line, # comments supported
    # - .trie: Compressed trie format (DAFSA - Deterministic Acyclic Finite State Automaton)
    #
    # @example Creating from a text file
    #   dict = CSpell.new("words.txt", language_code: "en-US")
    #   dict.lookup?("hello")  # => true
    #
    # @example Creating from a trie file
    #   dict = CSpell.new("words.trie", language_code: "en")
    class CSpell < Base
      # @return [String] The path to the dictionary file
      attr_reader :path

      # @return [Boolean] Whether lookups are case-sensitive
      attr_reader :case_sensitive

      # @return [Core::Trie::Trie] The trie data structure
      attr_reader :trie

      # Create a new CSpell dictionary.
      #
      # @param path [String] Path to the dictionary file (.txt or .trie)
      # @param language_code [String] The language code
      # @param locale [String, nil] The locale (optional)
      # @param case_sensitive [Boolean] Whether lookups are case-sensitive
      # @param metadata [Hash] Additional metadata (optional)
      def initialize(path, language_code:, locale: nil, case_sensitive: false, metadata: {})
        super(language_code, locale: locale, metadata: metadata)

        @path = File.expand_path(path)
        @case_sensitive = case_sensitive

        raise DictionaryNotFoundError, @path unless File.exist?(@path)

        # Load based on file extension
        if @path.end_with?(".trie")
          @trie = load_trie_file(@path)
        else
          @trie = load_text_file(@path)
        end

        # Register this dictionary type
        self.class.register_type(:cspell) unless Dictionary.registry.key?(:cspell)
      end

      # Check if a word exists in the dictionary.
      #
      # @param word [String] The word to look up
      # @return [Boolean] True if the word exists
      def lookup(word)
        return false if word.nil? || word.empty?

        lookup_word = @case_sensitive ? word : word.downcase
        @trie.lookup(lookup_word)
      end

      # Check if the dictionary has words with a prefix.
      #
      # @param prefix [String] The prefix
      # @return [Boolean] True if words exist with the prefix
      def has_prefix?(prefix)
        return false if prefix.nil? || prefix.empty?

        lookup_prefix = @case_sensitive ? prefix : prefix.downcase
        @trie.has_prefix?(lookup_prefix)
      end

      # Generate spelling suggestions.
      #
      # Uses trie walk to find similar words.
      #
      # @param word [String] The misspelled word
      # @param max_suggestions [Integer] Maximum suggestions
      # @return [Array<String>] List of suggested words
      def suggest(word, max_suggestions: 10)
        return [] if word.nil? || word.empty?

        lookup_word = @case_sensitive ? word : word.downcase

        # First try prefix-based suggestions
        prefix_suggestions = @trie.suggestions(lookup_word, max_results: max_suggestions)

        # If we have enough prefix suggestions, return them
        return prefix_suggestions if prefix_suggestions.length >= max_suggestions

        # Otherwise, use edit distance for more suggestions
        all_words = @trie.all_words
        candidates = all_words.select { |w| w.length >= lookup_word.length - 2 &&
                                               w.length <= lookup_word.length + 2 }

        # Calculate edit distances
        results = candidates.map do |dict_word|
          dist = edit_distance(lookup_word, dict_word)
          [dict_word, dist]
        end.select { |_, dist| dist > 0 && dist <= 2 }
         .sort_by { |_, dist| dist }
         .first(max_suggestions - prefix_suggestions.length)
         .map(&:first)

        # Combine both sets
        (prefix_suggestions + results).uniq.first(max_suggestions)
      end

      # Add a word to the dictionary.
      #
      # @param word [String] The word to add
      # @param flags [Array<String>] Flags (ignored for CSpell)
      # @return [Boolean] True if added
      def add_word(word, flags: [])
        return false if word.nil? || word.empty?

        lookup_word = @case_sensitive ? word : word.downcase
        return false if @trie.lookup(lookup_word)

        @trie.insert(lookup_word)
        true
      end

      # Remove a word from the dictionary.
      #
      # @param word [String] The word to remove
      # @return [Boolean] True if removed
      # @note CSpell dictionaries are typically immutable after loading
      def remove_word(word)
        # Trie doesn't support removal easily
        # Would need to rebuild the trie
        false
      end

      # Get all words in the dictionary.
      #
      # @return [Array<String>] All words
      def words
        @trie.all_words
      end

      # Get words with a prefix.
      #
      # @param prefix [String] The prefix
      # @return [Array<String>] Words with the prefix
      def words_with_prefix(prefix)
        return [] if prefix.nil? || prefix.empty?

        lookup_prefix = @case_sensitive ? prefix : prefix.downcase
        @trie.words_with_prefix(lookup_prefix)
      end

      # Create a dictionary from an array of words.
      #
      # @param words [Array<String>] The words
      # @param language_code [String] The language code
      # @param locale [String, nil] The locale (optional)
      # @param case_sensitive [Boolean] Whether lookups are case-sensitive
      # @return [CSpell] New dictionary
      #
      # @example
      #   dict = CSpell.from_words(%w[hello world test], language_code: "en")
      def self.from_words(words, language_code:, locale: nil, case_sensitive: false)
        dict = allocate

        # Build trie from words
        normalized_words = words.map { |w| case_sensitive ? w : w.downcase }.uniq
        trie = Core::Trie::Builder.from_array(normalized_words).build

        dict.instance_variable_set(:@language_code, language_code.dup.freeze)
        dict.instance_variable_set(:@locale, locale&.dup&.freeze)
        dict.instance_variable_set(:@path, nil)
        dict.instance_variable_set(:@case_sensitive, case_sensitive)
        dict.instance_variable_set(:@trie, trie)
        dict.instance_variable_set(:@metadata, {}.freeze)

        # Register this dictionary type (unless already registered)
        register_type(:cspell) unless Dictionary.registry.key?(:cspell)

        dict
      end

      private

      # Load a text dictionary file.
      #
      # @param path [String] The file path
      # @return [Core::Trie::Trie] The loaded trie
      def load_text_file(path)
        words = File.foreach(path, chomp: true)
                      .reject { |line| line.empty? || line.strip.empty? || line.strip.start_with?("#") }
                      .map(&:strip)
                      .map { |word| @case_sensitive ? word : word.downcase }
                      .uniq

        Core::Trie::Builder.from_array(words).build
      end

      # Load a compressed trie file.
      #
      # @param path [String] The file path
      # @return [Core::Trie::Trie] The loaded trie
      #
      # @note For now, this falls back to treating the file as text.
      #       Full .trie format support would require implementing DAFSA decompression.
      def load_trie_file(path)
        # For now, treat as text file
        # Full implementation would parse the CSpell .trie format
        # which uses DAFSA (Deterministic Acyclic Finite State Automaton) compression
        load_text_file(path)
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
