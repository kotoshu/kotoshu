# frozen_string_literal: true

require_relative "core/exceptions"
require_relative "dictionary/base"
require_relative "dictionary/unix_words"
require_relative "dictionary/plain_text"
require_relative "dictionary/custom"
require_relative "dictionary/hunspell"
require_relative "dictionary/cspell"
require_relative "configuration/resolver"

module Kotoshu
  # Configuration for Kotoshu spell checker.
  #
  # This class manages configuration options for spell checking,
  # including dictionary settings, suggestion limits, and language options.
  #
  # Configuration priority: CLI > ENV > Programmatic > Defaults
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
  #
  # @example Using environment variables
  #   ENV['KOTOSHU_LANGUAGE'] = 'de'
  #   config = Configuration.new
  #   config.language  # => 'de'
  class Configuration
    # Configuration schema with ENV variable mappings.
    #
    # Each key maps to a hash with:
    # - :env - Environment variable name
    # - :default - Default value (can be a proc for dynamic defaults)
    # - :description - Human-readable description
    # - :type - Expected type (for validation/conversion)
    SCHEMA = {
      dictionary_path: {
        env: "KOTOSHU_DICTIONARIES_PATH",
        default: nil,
        description: "Path to dictionary file",
        type: String
      },
      cache_path: {
        env: "KOTOSHU_CACHE_PATH",
        default: -> { default_cache_path },
        description: "Path to cache directory (~/.cache/kotoshu)",
        type: String
      },
      config_path: {
        env: "KOTOSHU_CONFIG_PATH",
        default: -> { default_config_path },
        description: "Path to user config directory (~/.config/kotoshu)",
        type: String
      },
      data_path: {
        env: "KOTOSHU_DATA_PATH",
        default: -> { default_data_path },
        description: "Path to data directory (~/.local/share/kotoshu)",
        type: String
      },
      dictionaries_url: {
        env: "KOTOSHU_DICTIONARIES_URL",
        default: "https://raw.githubusercontent.com/kotoshu/dictionaries/main",
        description: "Deprecated: use repos_base_url + dictionaries_pin via SourceRegistry",
        type: String
      },
      models_url: {
        env: "KOTOSHU_MODELS_URL",
        default: "https://github.com/kotoshu/models-fasttext-onnx/raw/main",
        description: "Deprecated: use repos_base_url + models_pin via SourceRegistry",
        type: String
      },
      repos_base_url: {
        env: "KOTOSHU_REPOS_BASE_URL",
        default: -> { Kotoshu::SourceRegistry::DEFAULT_BASE_URL },
        description: "GitHub raw root for all kotoshu content repos",
        type: String
      },
      dictionaries_pin: {
        env: "KOTOSHU_DICTIONARIES_PIN",
        default: "v1",
        description: "Branch/tag/commit pinned for kotoshu/dictionaries",
        type: String
      },
      frequency_pin: {
        env: "KOTOSHU_FREQUENCY_PIN",
        default: "main",
        description: "Branch/tag/commit pinned for kotoshu/frequency-list-kelly",
        type: String
      },
      models_pin: {
        env: "KOTOSHU_MODELS_PIN",
        default: "main",
        description: "Branch/tag/commit pinned for kotoshu/models-fasttext-onnx",
        type: String
      },
      auto_download: {
        env: "KOTOSHU_AUTO_DOWNLOAD",
        default: true,
        description: "Automatically download missing dictionaries",
        type: :boolean
      },
      cache_ttl: {
        env: "KOTOSHU_CACHE_TTL",
        default: 86_400, # 24 hours in seconds
        description: "Cache TTL in seconds",
        type: Integer
      },
      max_cache_size: {
        env: "KOTOSHU_MAX_CACHE_SIZE",
        default: 1_073_741_824, # 1GB
        description: "Maximum cache size in bytes",
        type: Integer
      },
      dictionary_type: {
        env: "KOTOSHU_DICTIONARY_TYPE",
        default: :unix_words,
        description: "Dictionary type (:unix_words, :plain_text, :hunspell, :cspell, :custom)",
        type: Symbol
      },
      language: {
        env: "KOTOSHU_LANGUAGE",
        default: "en-US",
        description: "Language code (e.g., en-US, de-DE, ja-JP)",
        type: String
      },
      locale: {
        env: "KOTOSHU_LOCALE",
        default: nil,
        description: "Locale (e.g., en, en_US, de_DE)",
        type: String
      },
      max_suggestions: {
        env: "KOTOSHU_MAX_SUGGESTIONS",
        default: 10,
        description: "Maximum number of suggestions",
        type: Integer
      },
      case_sensitive: {
        env: "KOTOSHU_CASE_SENSITIVE",
        default: false,
        description: "Enable case-sensitive lookups",
        type: :boolean
      },
      verbose: {
        env: "KOTOSHU_VERBOSE",
        default: false,
        description: "Enable verbose output",
        type: :boolean
      },
      encoding: {
        env: "KOTOSHU_ENCODING",
        default: "UTF-8",
        description: "Character encoding",
        type: String
      },
      dictionaries_path: {
        env: "KOTOSHU_DICTIONARIES_PATH",
        default: nil,
        description: "Path to dictionaries directory (for grammar rules)",
        type: String
      },
      offline: {
        env: "KOTOSHU_OFFLINE",
        default: false,
        description: "Use only cached resources; never download",
        type: :boolean
      },
      resource_pin: {
        env: "KOTOSHU_RESOURCE_PIN",
        default: "main",
        description: "Branch/tag/commit pinned for resource downloads",
        type: String
      },
      default_language: {
        env: "KOTOSHU_DEFAULT_LANGUAGE",
        default: "en",
        description: "Fallback language when detection is inconclusive",
        type: String
      }
    }.freeze

    # Default configuration values (legacy, for backward compatibility).
    DEFAULTS = {
      dictionary_path: nil,
      dictionary_type: :unix_words,
      language: "en-US",
      locale: nil,
      max_suggestions: 10,
      case_sensitive: false,
      verbose: false,
      suggestion_algorithms: nil, # Use defaults
      custom_words: [],
      encoding: "UTF-8",
      dictionaries_path: nil, # Path to dictionaries directory (for grammar rules)
      offline: false,
      default_language: "en",
      resource_pin: "main"
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

    # @return [String, nil] Path to dictionaries directory (for grammar rules)
    attr_accessor :dictionaries_path

    # @return [Boolean] Whether to use only cached resources (no downloads)
    attr_accessor :offline

    # @return [String] Fallback language when detection is inconclusive
    attr_accessor :default_language

    # @return [String] Branch/tag/commit pinned for resource downloads
    attr_accessor :resource_pin

    # @return [String, nil] Path to cache directory
    attr_accessor :cache_path

    # @return [String, nil] Path to user config directory
    attr_accessor :config_path

    # @return [String, nil] Path to data directory (audit log, etc.)
    attr_accessor :data_path

    # @return [String] Base URL for downloading dictionaries (deprecated)
    attr_accessor :dictionaries_url

    # @return [String] Base URL for FastText ONNX models (deprecated)
    attr_accessor :models_url

    # @return [String] GitHub raw root for all kotoshu content repos
    attr_accessor :repos_base_url

    # @return [String] Pin for kotoshu/dictionaries
    attr_accessor :dictionaries_pin

    # @return [String] Pin for kotoshu/frequency-list-kelly
    attr_accessor :frequency_pin

    # @return [String] Branch/tag/commit pinned for model downloads
    attr_accessor :models_pin

    # @return [#start,#update,#maybe_report_periodic,#finish,nil]
    #   Optional progress reporter for downloads. Typically set by the
    #   CLI (Cli::ProgressReporter) for human-facing setup runs; nil
    #   (silent) for programmatic API usage.
    attr_accessor :download_reporter

    # @return [Boolean] Whether to automatically download missing dictionaries
    attr_accessor :auto_download

    # @return [Integer] Cache TTL in seconds
    attr_accessor :cache_ttl

    # @return [Integer] Maximum cache size in bytes
    attr_accessor :max_cache_size

    # @return [Resolver] The configuration resolver
    attr_reader :resolver

    # Create a new configuration.
    #
    # @param args [Array] Variable arguments (positional hash or nothing)
    # @param kwargs [Hash] Keyword arguments for configuration
    # @param block [Proc] Optional block for configuration
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
    #
    # @example With CLI options (higher priority)
    #   config = Configuration.new(
    #     language: "en-US",
    #     cli_options: { language: "ja" }  # ja will be used
    #   )
    def initialize(*args, **kwargs, &block)
      # Handle both positional hash and keyword arguments
      settings = args.first.is_a?(Hash) ? args.first : {}
      settings = settings.merge(kwargs)

      # Extract cli_options if provided
      cli_options = settings.delete(:cli_options) || {}

      # Build the resolver with settings as programmatic defaults
      @resolver = Resolver.new(
        env: settings[:env] || {},
        programmatic: settings,
        cli: cli_options,
        defaults: DEFAULTS
      )

      apply_defaults
      apply_resolver_values
      apply_explicit_settings(settings)

      yield self if block
    end

    # Get a configuration value using the resolver.
    #
    # This respects the priority: CLI > ENV > Programmatic > Defaults
    #
    # @param key [Symbol] The configuration key
    # @return [Object] The resolved value
    #
    # @example
    #   config.get(:language)  # => resolved language value
    def get(key)
      @resolver.get(key)
    end

    # Check if a configuration key has a value set.
    #
    # @param key [Symbol] The configuration key
    # @return [Boolean] True if the key is set somewhere
    def key?(key)
      @resolver.key?(key)
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
        encoding: @encoding,
        dictionaries_path: @dictionaries_path,
        cache_path: @cache_path,
        config_path: @config_path,
        data_path: @data_path,
        dictionaries_url: @dictionaries_url,
        repos_base_url: @repos_base_url,
        dictionaries_pin: @dictionaries_pin,
        frequency_pin: @frequency_pin,
        models_pin: @models_pin,
        auto_download: @auto_download,
        cache_ttl: @cache_ttl,
        max_cache_size: @max_cache_size
      }
    end

    # Build a SourceRegistry honoring this configuration's base URL and
    # per-repo pins. Single source of truth for all resource URLs.
    #
    # @return [Kotoshu::SourceRegistry]
    def source_registry
      Kotoshu::SourceRegistry.new(
        base_url: @repos_base_url,
        pins: {
          "dictionaries" => @dictionaries_pin,
          "frequency-list-kelly" => @frequency_pin,
          "models-fasttext-onnx" => @models_pin
        }
      )
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
      @dictionaries_path = DEFAULTS[:dictionaries_path]
      @dictionary = nil

      # New cache-related defaults
      @cache_path = self.class.default_cache_path
      @config_path = self.class.default_config_path
      @data_path = self.class.default_data_path
      @dictionaries_url = SCHEMA[:dictionaries_url][:default]
      @models_url = SCHEMA[:models_url][:default]
      default = SCHEMA[:repos_base_url][:default]
      @repos_base_url = default.is_a?(Proc) ? default.call : default
      @dictionaries_pin = SCHEMA[:dictionaries_pin][:default]
      @frequency_pin = SCHEMA[:frequency_pin][:default]
      @models_pin = SCHEMA[:models_pin][:default]
      @download_reporter = nil
      @auto_download = SCHEMA[:auto_download][:default]
      @cache_ttl = SCHEMA[:cache_ttl][:default]
      @max_cache_size = SCHEMA[:max_cache_size][:default]
      @resource_pin = SCHEMA[:resource_pin][:default]
    end

    # Apply resolved values from the resolver (ENV, defaults).
    def apply_resolver_values
      # Apply values from ENV and defaults via resolver
      SCHEMA.each_key do |key|
        env_value = @resolver.get(key)
        next if env_value.nil?

        # Convert boolean strings if needed
        value = convert_schema_value(key, env_value)
        send("#{key}=", value) if respond_to?("#{key}=")
      end
    end

    # Apply explicit settings from the settings hash.
    #
    # Explicit settings have priority over ENV and defaults.
    def apply_explicit_settings(settings)
      settings.each do |key, value|
        next if %i[env cli_options].include?(key)

        send("#{key}=", value) if respond_to?("#{key}=")
      end
    end

    # Convert a value based on schema type.
    #
    # @param key [Symbol] The configuration key
    # @param value [Object] The value to convert
    # @return [Object] The converted value
    def convert_schema_value(key, value)
      schema = SCHEMA[key]
      return value if schema.nil? || value.nil?

      case schema[:type]
      when :boolean
        parse_boolean(value)
      when Integer
        value.is_a?(Integer) ? value : value.to_i
      when Symbol
        value.is_a?(Symbol) ? value : value.to_sym
      else
        value
      end
    end

    # Parse a boolean value from string.
    #
    # @param value [Object] The value to parse
    # @return [Boolean] The parsed boolean
    def parse_boolean(value)
      return true if value == true || value.to_s =~ /^(true|t|yes|y|1)$/i
      return false if value == false || value.to_s =~ /^(false|f|no|n|0)$/i

      # Default to false for unrecognized values
      false
    end

    # Get default cache path.
    #
    # @return [String] The default cache path
    def self.default_cache_path
      Paths.cache_path
    end

    def self.default_config_path
      Paths.config_path
    end

    def self.default_data_path
      Paths.data_path
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

      raise DictionaryNotFoundError,
            "no unix_words dictionary found; run `kotoshu setup #{@language}`"
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
