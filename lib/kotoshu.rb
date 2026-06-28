# frozen_string_literal: true

# Kotoshu is a semantic spell checker for Ruby.
#
# Public API entry point. All internal namespaces are autoloaded on first
# reference; loading this file is cheap and triggers no heavy work.
#
# Exception: version.rb is required because autoload only works for module
# constants, and Bundler/gemspec also reads Kotoshu::VERSION from it.
require_relative "kotoshu/version"

module Kotoshu
  # ---- Namespaces (autoloaded; each namespace file declares its children) ----
  autoload :Algorithms, "kotoshu/algorithms"
  autoload :Analyzers, "kotoshu/analyzers"
  autoload :Cache, "kotoshu/cache"
  autoload :Cli, "kotoshu/cli"
  autoload :Commands, "kotoshu/commands"
  autoload :Components, "kotoshu/components"
  autoload :Configuration, "kotoshu/configuration"
  autoload :Core, "kotoshu/core"
  autoload :Data, "kotoshu/data"
  autoload :DataStructures, "kotoshu/data_structures"
  autoload :Defaults, "kotoshu/defaults"
  autoload :Dictionaries, "kotoshu/dictionaries"
  autoload :Dictionary, "kotoshu/dictionary"
  autoload :Embeddings, "kotoshu/embeddings"
  autoload :FluentChecker, "kotoshu/fluent_checker"
  autoload :Grammar, "kotoshu/grammar"
  autoload :Integrity, "kotoshu/integrity"
  autoload :Keyboard, "kotoshu/keyboard"
  autoload :Language, "kotoshu/language"
  autoload :Languages, "kotoshu/languages"
  autoload :Models, "kotoshu/models"
  autoload :Paths, "kotoshu/paths"
  autoload :PersonalDictionary, "kotoshu/personal_dictionary"
  autoload :Plugins, "kotoshu/plugins"
  autoload :ProjectConfig, "kotoshu/project_config"
  autoload :Readers, "kotoshu/readers"
  autoload :ResourceBundle, "kotoshu/resource_bundle"
  autoload :ResourceManager, "kotoshu/resource_manager"
  autoload :Results, "kotoshu/results"
  autoload :SourceRegistry, "kotoshu/source_registry"
  autoload :Spellchecker, "kotoshu/spellchecker"
  autoload :StringMetrics, "kotoshu/string_metrics"
  autoload :Suggestions, "kotoshu/suggestions"

  # ---- Top-level error classes (all defined in core/exceptions.rb) ----
  autoload :Error, "kotoshu/core/exceptions"
  autoload :DictionaryNotFoundError, "kotoshu/core/exceptions"
  autoload :InvalidDictionaryFormatError, "kotoshu/core/exceptions"
  autoload :ConfigurationError, "kotoshu/core/exceptions"
  autoload :SpellcheckError, "kotoshu/core/exceptions"
  autoload :AffixRuleError, "kotoshu/core/exceptions"
  autoload :ResourceNotCachedError, "kotoshu/core/exceptions"
  autoload :ResourceNotSetupError, "kotoshu/core/exceptions"
  autoload :ResourceResolutionError, "kotoshu/core/exceptions"
  autoload :IntegrityError, "kotoshu/core/exceptions"
  autoload :SuikaUnavailable, "kotoshu/core/exceptions"

  # ---- Lazily-loaded singletons (not in their own namespace file) ----
  autoload :Debug, "kotoshu/debug_mode"
  autoload :DebugLogger, "kotoshu/debug_logger"
  autoload :LanguageCache, "kotoshu/cache/language_cache"
  autoload :LanguageIdentifier, "kotoshu/language/identifier"
  autoload :Metrics, "kotoshu/metrics_module"
  autoload :MetricsCollector, "kotoshu/metrics_collector"
  autoload :ModelCache, "kotoshu/cache/model_cache"
  autoload :SemanticAnalyzer, "kotoshu/analyzers/semantic_analyzer"
end

module Kotoshu
  # Global configuration instance.
  #
  # @return [Configuration] The global configuration
  #
  # @example
  #   Kotoshu.configure do |config|
  #     config.dictionary_path = "/usr/share/dict/words"
  #     config.language = "en-US"
  #   end
  def self.configure
    yield configuration if block_given?
    configuration
  end

  # Get the global configuration.
  #
  # @return [Configuration] The global configuration
  #
  # @example
  #   config = Kotoshu.configuration
  def self.configuration
    Configuration.instance
  end

  # Default spellchecker (singleton). Uses the configured default language.
  # Cache-only — raises ResourceNotSetupError if the default language hasn't
  # been set up via Kotoshu.setup.
  #
  # @return [Spellchecker] The default spellchecker
  # @raise [ResourceNotSetupError] if no language is set up
  def self.spellchecker
    return @spellchecker if @spellchecker

    lang = configuration.default_language
    raise ResourceNotSetupError.new(lang || "default", "spelling") if lang.nil? || lang.to_s.empty?

    @spellchecker = spellchecker_for(lang)
  end

  # Get a spellchecker for a specific language (cache-only, raises on miss).
  #
  # @param language [String, Symbol] Language code (e.g., "en", "de", "fr")
  # @return [Spellchecker] Spellchecker using a ResourceManager-resolved bundle
  # @raise [ResourceNotSetupError] if the language hasn't been set up
  #
  # @example
  #   Kotoshu.setup(:de)
  #   Kotoshu.spellchecker_for("de").correct?("Hallo")  # => true
  def self.spellchecker_for(language)
    key = language.to_s
    @spellcheckers ||= {}
    @spellcheckers[key] ||= begin
      bundle = ResourceManager.resolve(language: language)
      Spellchecker.new(resource_bundle: bundle, config: configuration)
    end
  end

  # Resolve language resources from the cache (no download).
  #
  # @param language [String, Symbol, nil] Language code; if nil, uses default
  # @param want [Array<Symbol>] Resource types (default: [:spelling])
  # @return [ResourceBundle] Resolved bundle
  # @raise [ResourceNotSetupError] if the language hasn't been set up
  #
  # @example
  #   Kotoshu.setup(:en)
  #   bundle = Kotoshu.resolve(language: "en")
  #   bundle.dictionary  # => #<Dictionary::Hunspell ...>
  def self.resolve(language: nil, want: nil)
    lang = language || configuration.default_language
    raise ResourceNotSetupError.new(lang || "default", "spelling") if lang.nil?

    want_param = want || ResourceManager::DEFAULT_WANT
    ResourceManager.resolve(language: lang, want: want_param)
  end

  # ---- Stage 1: Setup ----

  # Set up resources for one or more languages (download or register local files).
  # Idempotent: re-running with the same args is a no-op unless `force: true`.
  #
  # @param languages [String, Symbol, Array<String, Symbol>] One or more language codes
  # @param want [Array<Symbol>] Resource types to fetch (default: [:spelling])
  # @param force [Boolean] Re-fetch even if already cached
  # @param strict [Boolean] Re-raise on optional-resource failure
  # @param aff [String, nil] Path to local .aff file (single-language only)
  # @param dic [String, nil] Path to local .dic file (single-language only)
  # @param from [String, nil] Directory containing local .aff/.dic (single-language only)
  # @param frequency [String, nil] Path to local frequency.json (single-language only)
  # @return [SetupResult, Array<SetupResult>] Result or results (array if multiple languages)
  #
  # @example Download from kotoshu/dictionaries
  #   Kotoshu.setup(:en)                                 # spelling only
  #   Kotoshu.setup(:en, want: %i[spelling frequency])   # spelling + frequency
  #   Kotoshu.setup(:en, :de, :fr)                       # multiple languages
  #
  # @example Register local files (user already has hunspell dicts)
  #   Kotoshu.setup(:en, aff: "/usr/share/hunspell/en_US.aff",
  #                       dic: "/usr/share/hunspell/en_US.dic")
  #
  # @example Register local files from a directory
  #   Kotoshu.setup(:en, from: "/usr/share/hunspell/")  # looks for en.aff, en.dic
  def self.setup(*languages, want: nil, **opts)
    raise ArgumentError, "Kotoshu.setup requires at least one language" if languages.empty?

    want_param = want || ResourceManager::DEFAULT_WANT
    if languages.size == 1
      ResourceManager.setup(languages.first, want: want_param, **opts)
    else
      languages.map { |lang| ResourceManager.setup(lang, want: want_param, **opts) }
    end
  end

  # Check if a language (or a specific resource for that language) is set up.
  #
  # @param language [String, Symbol] Language code
  # @param resource [Symbol, nil] :spelling, :frequency, :model, or nil for any
  # @return [Boolean] True if the resource is cached and available
  #
  # @example
  #   Kotoshu.setup(:en)
  #   Kotoshu.setup?(:en)              # => true
  #   Kotoshu.setup?(:en, :spelling)   # => true
  #   Kotoshu.setup?(:en, :frequency)  # => false (not set up)
  def self.setup?(language, resource = nil)
    ResourceManager.setup?(language, resource: resource)
  end

  # List languages that have been set up.
  #
  # @return [Array<String>] Sorted array of language codes with cached spelling
  #
  # @example
  #   Kotoshu.languages_setup  # => ["de", "en", "fr"]
  def self.languages_setup
    ResourceManager.languages_setup
  end

  # Reset the spellchecker cache. The next call to `spellchecker` or
  # `spellchecker_for` re-resolves from the current configuration.
  #
  # Does NOT eagerly reload — clearing the cache is enough. This makes
  # the method safe to call between tests even when no language is set
  # up yet (the next call will raise ResourceNotSetupError per the
  # strict two-stage contract).
  def self.reset_spellchecker
    @spellchecker = nil
    @spellcheckers = nil
    nil
  end

  # Check if a word is spelled correctly.
  # Hot path — cache-only, raises if language not set up.
  #
  # @param word [String] The word to check
  # @param language [String, Symbol, nil] Language code; if nil, uses configured default
  # @return [Boolean] True if the word is correct
  # @raise [ResourceNotSetupError] if the language hasn't been set up
  #
  # @example
  #   Kotoshu.setup(:en)
  #   Kotoshu.correct?("hello")            # => true
  #   Kotoshu.correct?("Hallo", language: "de")  # requires Kotoshu.setup(:de) first
  def self.correct?(word, language: nil)
    checker = language ? spellchecker_for(language) : spellchecker
    checker.correct?(word)
  end

  # Check if a word is misspelled. Hot path.
  #
  # @param word [String] The word to check
  # @param language [String, Symbol, nil] Language code
  # @return [Boolean] True if the word is misspelled
  # @raise [ResourceNotSetupError] if the language hasn't been set up
  def self.misspelled?(word, language: nil)
    !correct?(word, language: language)
  end

  # Get spelling suggestions for a word. Hot path.
  #
  # @param word [String] The misspelled word
  # @param language [String, Symbol, nil] Language code
  # @param options [Hash] Options (max_suggestions, etc.)
  # @return [Suggestions::SuggestionSet] Generated suggestions
  # @raise [ResourceNotSetupError] if the language hasn't been set up
  #
  # @example
  #   Kotoshu.setup(:en)
  #   suggestions = Kotoshu.suggest("helo")
  #   suggestions.to_words  # => ["hello", "help", "held", ...]
  def self.suggest(word, language: nil, **options)
    checker = language ? spellchecker_for(language) : spellchecker
    checker.suggest(word, **options)
  end

  # Check text for spelling errors. Hot path.
  #
  # @param text [String] The text to check
  # @param language [String, Symbol, nil] Language code; if nil, uses configured default
  # @param options [Hash] Options
  # @return [Models::Result::DocumentResult] The check result
  # @raise [ResourceNotSetupError] if the language hasn't been set up
  #
  # @example
  #   Kotoshu.setup(:en)
  #   result = Kotoshu.check("Hello wrold")
  #   result.errors.map(&:word)  # => ["wrold"]
  def self.check(text, language: nil, **_options)
    checker = language ? spellchecker_for(language) : spellchecker
    checker.check(text)
  end

  # Check a file for spelling errors. Hot path.
  #
  # @param path [String] The file path
  # @param language [String, Symbol, nil] Language code
  # @param options [Hash] Options
  # @return [Models::Result::DocumentResult] The check result
  # @raise [ResourceNotSetupError] if the language hasn't been set up
  #
  # @example
  #   Kotoshu.setup(:en)
  #   result = Kotoshu.check_file("README.md")
  #   result.success?  # => false
  def self.check_file(path, language: nil, **_options)
    checker = language ? spellchecker_for(language) : spellchecker
    checker.check_file(path)
  end

  # Check multiple files for spelling errors.
  #
  # @param paths [Array<String>] The file paths
  # @param options [Hash] Options
  # @return [Array<Models::Result::DocumentResult>] Results for each file
  #
  # @example
  #   results = Kotoshu.check_files(%w[README.md CHANGELOG.md])
  #   results.select(&:failed?)
  def self.check_files(paths, **options)
    paths.map { |path| check_file(path, **options) }
  end

  # Convenience method for creating an indexed dictionary.
  #
  # @param source [Array<String>, Hash, nil] Words or file path
  # @return [Core::IndexedDictionary] New dictionary
  def self.dictionary(source = nil)
    case source
    when Array
      Core::IndexedDictionary.new(source)
    when String
      Core::IndexedDictionary.from_file(source)
    when nil, Hash
      Core::IndexedDictionary.new
    else
      raise ArgumentError, "Invalid dictionary source: #{source.inspect}"
    end
  end

  # Convenience method for creating a trie.
  #
  # @param source [Array<String>, String, nil] Words or file path
  # @return [Core::Trie::Trie] New trie
  def self.trie(source = nil)
    case source
    when Array
      Core::Trie::Builder.from_array(source)
    when String
      if File.exist?(source)
        Core::Trie::Builder.from_file(source)
      else
        Core::Trie::Builder.from_string(source)
      end
    when nil
      Core::Trie::Trie.new
    else
      raise ArgumentError, "Invalid trie source: #{source.inspect}"
    end
  end

  # Convenience method for creating a suggestion pipeline.
  #
  # @param strategies [Array] Optional strategies to add
  # @return [Suggestions::Strategies::CompositeStrategy] New pipeline
  def self.suggestion_pipeline(*strategies)
    pipeline = Suggestions::Strategies::CompositeStrategy.new(name: :default)
    strategies.each { |s| pipeline.add(s) }
    pipeline
  end

  # Register a custom dictionary type.
  #
  # @param type [Symbol] The type key
  # @param klass [Class] The dictionary class
  #
  # @example
  #   Kotoshu.register_dictionary_type(:my_custom, MyDictionary)
  def self.register_dictionary_type(type, klass)
    Dictionary.register_type(type, klass)
  end

  # Register a custom suggestion algorithm.
  #
  # @param name [Symbol] The algorithm name
  # @param klass [Class] The algorithm class
  #
  # @example
  #   Kotoshu.register_suggestion_algorithm(:my_custom, MyStrategy)
  def self.register_suggestion_algorithm(name, klass)
    Suggestions::Strategies::BaseStrategy.register_type(name, klass)
  end

  # Access the language module.
  #
  # @return [Module] The Language module
  #
  # @example
  #   Kotoshu::Language.detect("Hello world")  # => "en"
  def self.language
    Language
  end

  # Detect language of text.
  #
  # @param text [String] Text to analyze
  # @return [String, nil] Detected language code
  #
  # @example
  #   Kotoshu.detect_language("Bonjour le monde")  # => "fr"
  #   Kotoshu.detect_language("こんにちは")        # => "ja"
  def self.detect_language(text)
    Language.detect(text)
  end

  # Detect language with confidence score.
  #
  # @param text [String] Text to analyze
  # @return [Array<String, Float>] Language code and confidence
  #
  # @example
  #   lang, conf = Kotoshu.detect_language_with_confidence("Hello world")
  #   lang  # => "en"
  #   conf  # => 0.85
  def self.detect_language_with_confidence(text)
    Language.detect_with_confidence(text)
  end

  # Get language class by code.
  #
  # @param code [String] Language code (e.g., "en-US", "de-DE")
  # @return [Class, nil] Language class or nil
  #
  # @example
  #   Kotoshu.get_language("en-US")
  def self.get_language(code)
    Language.get(code)
  end

  # Check if a language is registered.
  #
  # @param code [String] Language code
  # @return [Boolean] True if registered
  #
  # @example
  #   Kotoshu.language_registered?("en-US")  # => true or false
  def self.language_registered?(code)
    Language.registered?(code)
  end

  # Get all supported language codes.
  #
  # @return [Array<String>] List of language codes
  #
  # @example
  #   Kotoshu.supported_languages  # => ["de-DE", "en-US", "fr-FR", ...]
  def self.supported_languages
    Language.supported_codes
  end
end
