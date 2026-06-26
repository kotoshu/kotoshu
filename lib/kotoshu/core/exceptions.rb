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

  # Error raised when a required resource is not cached and cannot be
  # downloaded (offline mode or network failure).
  class ResourceNotCachedError < Error
    def initialize(language, resource_type)
      @language = language
      @resource_type = resource_type
      super("Resource not cached: #{language}:#{resource_type}. " \
            "Pre-fetch with `kotoshu cache download language #{language}` " \
            "or disable offline mode (KOTOSHU_OFFLINE=0).")
    end

    attr_reader :language, :resource_type
  end

  # Error raised by the hot path (Kotoshu.correct?, .suggest, .check,
  # .check_file, .spellchecker_for) when a language hasn't been set up
  # via Kotoshu.setup / kotoshu setup. The hot path is cache-only and
  # never downloads — explicit setup is required.
  class ResourceNotSetupError < Error
    def initialize(language, resource_type = "spelling")
      @language = language
      @resource_type = resource_type
      super("Language '#{language}' is not set up (missing #{resource_type}). " \
            "Run `kotoshu setup #{language}` or " \
            "`Kotoshu.setup(:#{language})` first.")
    end

    attr_reader :language, :resource_type
  end

  # Error raised when a resource cannot be resolved for a language
  # (unsupported language, download failure, etc.).
  class ResourceResolutionError < Error
    def initialize(language, reason)
      @language = language
      super("Cannot resolve resources for '#{language}': #{reason}")
    end

    attr_reader :language
  end

  # Error raised when a downloaded resource fails integrity verification
  # (SHA-256 mismatch against manifest, truncated content, etc.).
  #
  # The downloaded bytes are never trusted until verified against a known
  # manifest entry. Mismatch raises this error with both hashes so the
  # caller can surface them in audit logs and CI output.
  class IntegrityError < Error
    def initialize(resource_id, expected:, actual:, url: nil)
      @resource_id = resource_id
      @expected = expected
      @actual = actual
      @url = url
      msg = +"Integrity verification failed for #{resource_id}: "
      msg << "expected sha256=#{expected}, got sha256=#{actual}"
      msg << " (url: #{url})" if url
      super(msg)
    end

    attr_reader :resource_id, :expected, :actual, :url
  end
end
