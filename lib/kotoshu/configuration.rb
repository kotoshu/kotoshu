# frozen_string_literal: true

require_relative "core/exceptions"
require_relative "dictionary/base"
require_relative "dictionary/unix_words"
require_relative "dictionary/plain_text"
require_relative "dictionary/custom"
require_relative "dictionary/hunspell"
require_relative "dictionary/cspell"

module Kotoshu
  # Configuration for Kotoshu spell checker.
  #
  # This class manages configuration options for spell checking,
  # including dictionary settings, suggestion limits, and language options.
  #
  # @example Creating a configuration
  #   config = Configuration.new
  #   config.dictionary_path = "/usr/share/dict/words"
  #   config.dictionary_type = :unix_words
  #   config.max_suggestions = 15
  #
  # @example Using a block
  #   Configuration.new do |c|
  #     c.dictionary_path = "words.txt"
  #     c.language = "en-US"
  #   end
  class Configuration
    # Default configuration values.
    DEFAULTS = {
      dictionary_path: nil,
      dictionary_type: :unix_words,
      language: "en-US",
      locale: nil,
      max_suggestions: 10,
      case_sensitive: false,
      verbose: false,
      suggestion_algorithms: nil,  # Use defaults
      custom_words: [],
      encoding: "UTF-8"
    }.freeze

    # @return [String, nil] Path to the dictionary file
    attr_accessor :dictionary_path

    # @return [Symbol] Dictionary type (:unix_words, :plain_text, :hunspell, :cspell, :custom)
    attr_accessor :dictionary_type

    # @return [String] Language code (e.g., "en-US", "en-GB")
    attr_accessor :language

    # @return [String, nil] Locale (e.g., "en", "en_US")
    attr_accessor :locale

    # @return [Integer] Maximum number of suggestions to return
    attr_accessor :max_suggestions

    # @return [Boolean] Whether lookups are case-sensitive
    attr_accessor :case_sensitive

    # @return [Boolean] Whether to enable verbose output
    attr_accessor :verbose

    # @return [Array<Class>, nil] Suggestion algorithms to use
    attr_accessor :suggestion_algorithms

    # @return [Array<String>] Custom words to add to dictionary
    attr_accessor :custom_words

    # @return [String] Character encoding
    attr_accessor :encoding

    # @return [Dictionary::Base, nil] The loaded dictionary (lazy loaded)
    attr_accessor :dictionary

    # Create a new configuration.
    #
    # @param settings [Hash] Configuration settings
    # @yield [config] Optional block for configuration
    #
    # @example With hash
    #   config = Configuration.new(
    #     dictionary_path: "/usr/share/dict/words",
    #     language: "en-US"
    #   )
    #
    # @example With block
    #   Configuration.new do |c|
    #     c.dictionary_path = "words.txt"
    #     c.max_suggestions = 15
    #   end
    def initialize(settings = {}, &block)
      apply_defaults

      settings.each do |key, value|
        send("#{key}=", value) if respond_to?("#{key}=")
      end

      yield self if block_given?
    end

    # Load or get the dictionary.
    #
    # @return [Dictionary::Base] The loaded dictionary
    def dictionary
      @dictionary ||= load_dictionary
    end

    # Load the dictionary based on configuration.
    #
    # @return [Dictionary::Base] The loaded dictionary
    # @raise [DictionaryNotFoundError] If dictionary file not found
    # @raise [ConfigurationError] If dictionary type is invalid
    def load_dictionary
      dict = case @dictionary_type
              when :unix_words
                load_unix_words_dictionary
              when :plain_text
                load_plain_text_dictionary
              when :custom
                load_custom_dictionary
              when :hunspell
                load_hunspell_dictionary
              when :cspell
                load_cspell_dictionary
              else
                raise ConfigurationError, "Unknown dictionary type: #{@dictionary_type}"
              end

      # Add custom words
      @custom_words.each do |word|
        dict.add_word(word)
      end

      dict
    end

    # Reset the dictionary (force reload on next access).
    #
    # @return [self] Self for chaining
    def reset_dictionary
      @dictionary = nil
      self
    end

    # Convert to hash.
    #
    # @return [Hash] Hash representation
    def to_h
      {
        dictionary_path: @dictionary_path,
        dictionary_type: @dictionary_type,
        language: @language,
        locale: @locale,
        max_suggestions: @max_suggestions,
        case_sensitive: @case_sensitive,
        verbose: @verbose,
        suggestion_algorithms: @suggestion_algorithms&.map(&:name),
        custom_words: @custom_words,
        encoding: @encoding
      }
    end

    # Clone the configuration.
    #
    # @return [Configuration] A new configuration with the same settings
    def clone
      self.class.new(to_h)
    end

    # Get the default configuration.
    #
    # @return [Configuration] Default configuration instance
    #
    # @example
    #   config = Configuration.default
    def self.default
      new(DEFAULTS.dup)
    end

    # Global configuration instance.
    #
    # @return [Configuration] The global configuration
    #
    # @example
    #   Configuration.instance.dictionary_path = "/usr/share/dict/words"
    def self.instance
      @instance ||= default
    end

    # Reset the global configuration.
    #
    # @return [Configuration] The reset configuration
    def self.reset
      @instance = default
    end

    private

    # Apply default values.
    def apply_defaults
      @dictionary_path = DEFAULTS[:dictionary_path]
      @dictionary_type = DEFAULTS[:dictionary_type]
      @language = DEFAULTS[:language]
      @locale = DEFAULTS[:locale]
      @max_suggestions = DEFAULTS[:max_suggestions]
      @case_sensitive = DEFAULTS[:case_sensitive]
      @verbose = DEFAULTS[:verbose]
      @suggestion_algorithms = DEFAULTS[:suggestion_algorithms]
      @custom_words = DEFAULTS[:custom_words].dup
      @encoding = DEFAULTS[:encoding]
      @dictionary = nil
    end

    # Load UnixWords dictionary.
    def load_unix_words_dictionary
      # First try configured path or system dictionary
      path = @dictionary_path || Dictionary::UnixWords.detect_system_dictionary

      if path
        raise DictionaryNotFoundError, path unless File.exist?(path)
        return Dictionary::UnixWords.new(
          path,
          language_code: @language,
          locale: @locale,
          case_sensitive: @case_sensitive
        )
      end

      # Try to detect system dictionary
      dict = Dictionary::UnixWords.detect(
        language_code: @language,
        locale: @locale,
        case_sensitive: @case_sensitive
      )

      return dict if dict

      # Fall back to local dictionaries directory
      local_paths = [
        File.expand_path("dictionaries/unix_words/words", __dir__),
        File.expand_path("../../dictionaries/unix_words/web2", __dir__),
        File.expand_path("../../dictionaries/unix_words/web2a", __dir__)
      ]

      local_paths.each do |local_path|
        if File.exist?(local_path)
          return Dictionary::UnixWords.new(
            local_path,
            language_code: @language,
            locale: @locale,
            case_sensitive: @case_sensitive
          )
        end
      end

      # No dictionary found - create an empty one
      Dictionary::Custom.new(words: [], language_code: @language, locale: @locale)
    end

    # Load PlainText dictionary.
    def load_plain_text_dictionary
      path = @dictionary_path

      raise ConfigurationError, "dictionary_path is required for plain_text type" unless path
      raise DictionaryNotFoundError, path unless File.exist?(path)

      Dictionary::PlainText.new(
        path,
        language_code: @language,
        locale: @locale,
        case_sensitive: @case_sensitive
      )
    end

    # Load Custom dictionary.
    def load_custom_dictionary
      Dictionary::Custom.new(
        words: @custom_words,
        language_code: @language,
        locale: @locale,
        case_sensitive: @case_sensitive
      )
    end

    # Load Hunspell dictionary.
    def load_hunspell_dictionary
      dic_path = @dictionary_path

      raise ConfigurationError, "dictionary_path is required for hunspell type" unless dic_path

      # Replace .dic extension with .aff for affix file
      aff_path = dic_path.sub(/\.dic$/i, ".aff")

      raise DictionaryNotFoundError, dic_path unless File.exist?(dic_path)
      raise DictionaryNotFoundError, aff_path unless File.exist?(aff_path)

      Dictionary::Hunspell.new(
        dic_path: dic_path,
        aff_path: aff_path,
        language_code: @language,
        locale: @locale
      )
    end

    # Load CSpell dictionary.
    def load_cspell_dictionary
      path = @dictionary_path

      raise ConfigurationError, "dictionary_path is required for cspell type" unless path
      raise DictionaryNotFoundError, path unless File.exist?(path)

      Dictionary::CSpell.new(
        path,
        language_code: @language,
        locale: @locale,
        case_sensitive: @case_sensitive
      )
    end
  end
end
