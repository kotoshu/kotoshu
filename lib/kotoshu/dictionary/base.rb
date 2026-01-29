# frozen_string_literal: true

module Kotoshu
  module Dictionary
    # Base class for all dictionary backends.
    #
    # This abstract class defines the interface that all dictionary
    # implementations must follow.
    #
    # @note Subclasses must implement the abstract methods: {#lookup},
    #       {#suggest}, {#add_word}, and {#remove_word}.
    #
    # @example Implementing a custom dictionary
    #   class MyDictionary < Base
    #     def initialize(path, language_code:, locale: nil)
    #       super(language_code, locale: locale)
    #       @words = load_words(path)
    #     end
    #
    #     def lookup(word)
    #       @words.include?(word.downcase)
    #     end
    #
    #     # ... implement other abstract methods
    #   end
    class Base
      # @return [String] The language code (e.g., "en-US", "en-GB")
      attr_reader :language_code

      # @return [String, nil] The locale (e.g., "en", "en_US")
      attr_reader :locale

      # @return [Hash] Additional metadata
      attr_reader :metadata

      # Create a new dictionary.
      #
      # @param language_code [String] The language code (e.g., "en-US")
      # @param locale [String, nil] The locale (optional)
      # @param metadata [Hash] Additional metadata (optional)
      def initialize(language_code, locale: nil, metadata: {})
        raise ArgumentError, "Language code cannot be empty" if language_code.nil? || language_code.empty?

        @language_code = language_code.dup.freeze
        @locale = locale&.dup&.freeze
        @metadata = metadata.dup.freeze
      end

      # Check if a word exists in the dictionary.
      #
      # @abstract Subclasses must implement this method.
      # @param word [String] The word to look up
      # @return [Boolean] True if the word exists
      # @raise [NotImplementedError] Subclass must implement
      def lookup(word)
        raise NotImplementedError, "#{self.class} must implement #lookup"
      end

      # Check if a word exists in the dictionary (alias for lookup).
      #
      # @param word [String] The word to look up
      # @return [Boolean] True if the word exists
      def lookup?(word)
        lookup(word)
      end

      alias has_word? lookup
      alias include? lookup
      alias contains? lookup

      # Generate spelling suggestions for a word.
      #
      # @abstract Subclasses must implement this method.
      # @param word [String] The misspelled word
      # @param max_suggestions [Integer] Maximum number of suggestions
      # @return [Array<String>] List of suggested words
      # @raise [NotImplementedError] Subclass must implement
      def suggest(word, max_suggestions: 10)
        raise NotImplementedError, "#{self.class} must implement #suggest"
      end

      # Add a word to the dictionary.
      #
      # @abstract Subclasses must implement this method.
      # @param word [String] The word to add
      # @param flags [Array<String>] Morphological flags (optional)
      # @return [Boolean] True if the word was added
      # @raise [NotImplementedError] Subclass must implement
      def add_word(word, flags: [])
        raise NotImplementedError, "#{self.class} must implement #add_word"
      end
      alias << add_word

      # Remove a word from the dictionary.
      #
      # @abstract Subclasses must implement this method.
      # @param word [String] The word to remove
      # @return [Boolean] True if the word was removed
      # @raise [NotImplementedError] Subclass must implement
      def remove_word(word)
        raise NotImplementedError, "#{self.class} must implement #remove_word"
      end

      # Get all words in the dictionary.
      #
      # @abstract Subclasses must implement this method.
      # @return [Array<String>] All words
      # @raise [NotImplementedError] Subclass must implement
      def words
        raise NotImplementedError, "#{self.class} must implement #words"
      end
      alias all_words words

      # Get the number of words in the dictionary.
      #
      # @return [Integer] Word count
      def size
        words.length
      end
      alias count size
      alias length size

      # Check if the dictionary is empty.
      #
      # @return [Boolean] True if empty
      def empty?
        size.zero?
      end

      # Iterate over all words.
      #
      # @yield [word] Each word
      # @return [Enumerator] Enumerator if no block given
      def each_word
        return enum_for(:each_word) unless block_given?
        words.each { |word| yield word }
      end

      # Get words starting with a prefix.
      #
      # @param prefix [String] The prefix
      # @return [Array<String>] Words with the prefix
      def words_with_prefix(prefix)
        words.select { |w| w.start_with?(prefix) }
      end

      # Get words matching a pattern.
      #
      # @param pattern [Regexp] The pattern
      # @return [Array<String>] Matching words
      def words_matching(pattern)
        words.select { |w| w.match?(pattern) }
      end

      # Convert to string.
      #
      # @return [String] String representation
      def to_s
        "#{self.class.name}(language: #{@language_code}, size: #{size})"
      end
      alias inspect to_s

      # Dictionary type identifier.
      #
      # @return [Symbol] The dictionary type
      def type
        self.class.name.split("::").last.gsub(/(.)([A-Z])/, '\1_\2').downcase.to_sym
      end

      # Register this dictionary type.
      #
      # @param type_key [Symbol] The type key to register as
      #
      # @example Registering a custom dictionary type
      #   MyDictionary.register_type(:my_custom)
      def self.register_type(type_key)
        Kotoshu::Dictionary.register_type(type_key, self)
      end

      # Class-level registry for dictionary types.
      #
      # @return [Hash] Registry of type keys to classes
      def self.registry
        @registry ||= {}
      end

      # Load a dictionary by type.
      #
      # @param type [Symbol] The dictionary type
      # @param args [Array] Arguments to pass to constructor
      # @return [Base] The loaded dictionary
      # @raise [ConfigurationError] If type is not registered
      def self.load(type, *args)
        klass = registry[type]
        raise ConfigurationError, "Unknown dictionary type: #{type}" unless klass

        klass.new(*args)
      end
    end

    # Module-level registry for dictionary types.
    #
    # @return [Hash] Registry of type keys to classes
    def self.registry
      @registry ||= {}
    end

    # Register a dictionary type.
    #
    # @param type [Symbol] The type key
    # @param klass [Class] The dictionary class
    #
    # @example Registering a custom dictionary type
    #   Dictionary.register_type(:my_custom, MyDictionary)
    def self.register_type(type, klass)
      @registry ||= {}
      @registry[type] = klass
    end

    # Load a dictionary by type.
    #
    # @param type [Symbol] The dictionary type
    # @param args [Array] Arguments to pass to constructor
    # @return [Base] The loaded dictionary
    #
    # @example Loading a dictionary
    #   dict = Dictionary.load(:unix_words, "/usr/share/dict/words",
    #                          language_code: "en-US")
    def self.load(type, *args)
      klass = registry[type]
      raise ConfigurationError, "Unknown dictionary type: #{type}" unless klass

      klass.new(*args)
    end
  end
end
