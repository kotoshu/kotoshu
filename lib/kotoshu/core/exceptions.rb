# frozen_string_literal: true

module Kotoshu
  # Base error class for all Kotoshu exceptions.
  #
  # @example Raising a custom Kotoshu error
  #   raise Kotoshu::Error, "Something went wrong"
  class Error < StandardError; end

  # Error raised when a dictionary file cannot be found.
  #
  # @example Dictionary not found
  #   raise DictionaryNotFoundError, "Dictionary not found: /path/to/dic.dic"
  class DictionaryNotFoundError < Error
    # Create a new dictionary not found error.
    #
    # @param path [String] The path that was not found
    # @param message [String] Custom message (optional)
    def initialize(path, message = nil)
      @path = path
      super(message || "Dictionary not found: #{path}")
    end

    # @return [String] The path that was not found
    attr_reader :path
  end

  # Error raised when a dictionary file has an invalid format.
  #
  # @example Invalid dictionary format
  #   raise InvalidDictionaryFormatError, "Invalid .dic file format"
  class InvalidDictionaryFormatError < Error
    # Create a new invalid format error.
    #
    # @param path [String] The file path
    # @param details [String] Details about the format issue
    def initialize(path, details = nil)
      @path = path
      @details = details
      super("Invalid dictionary format#{": #{details}" if details}: #{path}")
    end

    # @return [String] The file path
    attr_reader :path

    # @return [String, nil] Details about the format issue
    attr_reader :details
  end

  # Error raised when there is a configuration issue.
  #
  # @example Invalid configuration
  #   raise ConfigurationError, "Invalid dictionary type: unknown_type"
  class ConfigurationError < Error
    # Create a new configuration error.
    #
    # @param message [String] The error message
    # @param key [String, Symbol] The configuration key (optional)
    def initialize(message, key: nil)
      @key = key
      super(message)
    end

    # @return [String, Symbol, nil] The configuration key
    attr_reader :key
  end

  # Error raised during spell checking operations.
  #
  # @example Spell check failure
  #   raise SpellcheckError, "Failed to check word: encoding error"
  class SpellcheckError < Error
    # Create a new spellcheck error.
    #
    # @param message [String] The error message
    # @param word [String] The word being checked (optional)
    def initialize(message, word: nil)
      @word = word
      super(message)
    end

    # @return [String, nil] The word being checked
    attr_reader :word
  end

  # Error raised when an affix rule cannot be parsed.
  #
  # @example Invalid affix rule
  #   raise AffixRuleError, "Invalid affix rule: PFX A Y 1 re"
  class AffixRuleError < Error
    # Create a new affix rule error.
    #
    # @param message [String] The error message
    # @param rule [String] The rule that failed to parse (optional)
    def initialize(message, rule: nil)
      @rule = rule
      super(message)
    end

    # @return [String, nil] The rule that failed to parse
    attr_reader :rule
  end
end
