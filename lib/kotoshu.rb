# frozen_string_literal: true

# EAGER: Core infrastructure
require_relative "kotoshu/version"
require_relative "kotoshu/core"
require_relative "kotoshu/core/models/word"
require_relative "kotoshu/core/models/affix_rule"
require_relative "kotoshu/core/models/result/word_result"
require_relative "kotoshu/core/models/result/document_result"

# EAGER: String metrics (used by algorithms)
require_relative "kotoshu/string_metrics"

# EAGER: Algorithms namespace
require_relative "kotoshu/algorithms"

# EAGER: Algorithms (ported from Spylls)
require_relative "kotoshu/algorithms/ngram_suggest"
require_relative "kotoshu/suggestions/suggestion"
require_relative "kotoshu/suggestions/suggestion_set"
require_relative "kotoshu/suggestions/context"
require_relative "kotoshu/suggestions/generator"

# EAGER: Dictionary base
require_relative "kotoshu/dictionary/base"
require_relative "kotoshu/dictionary/repository"

# EAGER: Dictionary backends (load all for now, can optimize later)
require_relative "kotoshu/dictionary/unix_words"
require_relative "kotoshu/dictionary/plain_text"
require_relative "kotoshu/dictionary/custom"
require_relative "kotoshu/dictionary/hunspell"
require_relative "kotoshu/dictionary/cspell"

# EAGER: Language module (multi-language support)
require_relative "kotoshu/language"

# EAGER: Strategy base
require_relative "kotoshu/suggestions/strategies/base_strategy"

# EAGER: Strategies (load all for now, can optimize later)
require_relative "kotoshu/suggestions/strategies/edit_distance_strategy"
require_relative "kotoshu/suggestions/strategies/symspell_strategy"
require_relative "kotoshu/suggestions/strategies/phonetic_strategy"
require_relative "kotoshu/suggestions/strategies/keyboard_proximity_strategy"
require_relative "kotoshu/suggestions/strategies/ngram_strategy"
require_relative "kotoshu/suggestions/strategies/composite_strategy"

# EAGER: Readers for Hunspell files
require_relative "kotoshu/readers"

# EAGER: Configuration and main interface
require_relative "kotoshu/dictionaries/catalog"
require_relative "kotoshu/configuration"
require_relative "kotoshu/spellchecker"

module Kotoshu
  # LAZY: Trie components (autoload)
  autoload :TrieNode, "kotoshu/core/trie/node"
  autoload :Trie, "kotoshu/core/trie/trie"
  autoload :TrieBuilder, "kotoshu/core/trie/builder"

  # LAZY: Features (autoload)
  autoload :Defaults, "kotoshu/defaults"
  autoload :PersonalDictionary, "kotoshu/personal_dictionary"
  autoload :ProjectConfig, "kotoshu/project_config"
  autoload :FluentChecker, "kotoshu/fluent_checker"
  autoload :ResourceManager, "kotoshu/resource_manager"
  autoload :ResourceBundle, "kotoshu/resource_bundle"

  # LAZY: Integrity verification (autoload)
  autoload :Integrity, "kotoshu/integrity"

  # LAZY: FastText integration (autoload)
  autoload :WordEmbedding, "kotoshu/models/word_embedding"
  autoload :NearestNeighbor, "kotoshu/models/nearest_neighbor"
  autoload :SemanticError, "kotoshu/models/semantic_error"
  autoload :Context, "kotoshu/models/context"
  autoload :Suggestion, "kotoshu/models/suggestion"
  autoload :EmbeddingModel, "kotoshu/models/embedding_model"
  autoload :FastTextModel, "kotoshu/models/fasttext_model"
  autoload :OnnxModel, "kotoshu/models/onnx_model"
  autoload :SemanticAnalyzer, "kotoshu/analyzers/semantic_analyzer"

  # LAZY: Document abstraction (autoload)
  autoload :Location, "kotoshu/documents/location"
  autoload :Document, "kotoshu/documents/document"
  autoload :PlainTextDocument, "kotoshu/documents/plain_text_document"
  autoload :MarkdownDocument, "kotoshu/documents/markdown_document"
  autoload :AsciidocDocument, "kotoshu/documents/asciidoc_document"

  # LAZY: CLI components (autoload)
  autoload :NavigationManager, "kotoshu/cli/navigation_manager"
  autoload :DisplayFormatter, "kotoshu/cli/display_formatter"
  autoload :InteractiveReviewer, "kotoshu/cli/interactive_reviewer"
  autoload :BatchReporter, "kotoshu/cli/batch_reporter"

  # LAZY: Cache management (autoload)
  autoload :LanguageCache, "kotoshu/cache/language_cache"
  autoload :ModelCache, "kotoshu/cache/model_cache"

  # LAZY: Language detection (autoload)
  autoload :LanguageIdentifier, "kotoshu/language/identifier"

  # LAZY: Development tools (autoload)
  autoload :Debug, "kotoshu/debug_mode"
  autoload :DebugLogger, "kotoshu/debug_logger"
  autoload :Metrics, "kotoshu/metrics_module"
  autoload :MetricsCollector, "kotoshu/metrics_collector"
end

module Kotoshu
  class Error < StandardError; end

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

  # Get the global spellchecker instance (lazy loaded).
  #
  # @return [Spellchecker] The spellchecker
  #
  # @example
  #   spellchecker = Kotoshu.spellchecker
  def self.spellchecker
    @spellchecker ||= Spellchecker.new(config: configuration)
  end

  # Get a spellchecker for a specific language (downloads on first call).
  #
  # @param language [String, Symbol] Language code (e.g., "en", "de", "fr")
  # @param offline [Boolean, nil] Override offline mode
  # @param strict [Boolean, nil] Re-raise on optional-resource failure (frequency, model)
  # @return [Spellchecker] Spellchecker using a ResourceManager-resolved bundle
  #
  # @example
  #   Kotoshu.spellchecker_for("de").correct?("Hallo")  # => true
  def self.spellchecker_for(language, offline: nil, strict: nil)
    key = "#{language}:#{offline}:#{strict}"
    @spellcheckers ||= {}
    @spellcheckers[key] ||= begin
      bundle = ResourceManager.resolve(language: language, offline: offline, strict: strict)
      Spellchecker.new(resource_bundle: bundle, config: configuration)
    end
  end

  # Resolve language resources (dictionary, frequency, model, rules) on demand.
  #
  # @param language [String, Symbol, nil] Language code (e.g., "en", "de-DE"), or nil
  # @param text [String, nil] Text to auto-detect language from
  # @param want [Array<Symbol>] Resource types (default: [:spelling])
  # @param offline [Boolean, nil] Override offline mode
  # @param strict [Boolean, nil] Re-raise on optional-resource failure
  # @return [ResourceBundle] Resolved bundle
  #
  # @example Resolve by language
  #   bundle = Kotoshu.resolve(language: "en")
  #   bundle.dictionary  # => #<Dictionary::Hunspell ...>
  #
  # @example Auto-detect from text
  #   bundle = Kotoshu.resolve(text: "Guten Tag")
  #   bundle.language  # => "de"
  def self.resolve(language: nil, text: nil, want: nil, offline: nil, strict: nil)
    want_param = want || ResourceManager::DEFAULT_WANT
    ResourceManager.resolve(text: text, language: language, want: want_param,
                            offline: offline, strict: strict)
  end

  # Reset the spellchecker (force reload).
  #
  # @return [Spellchecker] The reset spellchecker
  def self.reset_spellchecker
    @spellchecker = nil
    @spellcheckers = nil
    spellchecker
  end

  # Check if a word is spelled correctly.
  #
  # @param word [String] The word to check
  # @param language [String, nil] Language code; if provided, uses a per-language spellchecker
  # @param offline [Boolean, nil] Override offline mode
  # @param strict [Boolean, nil] Re-raise on optional-resource failure
  # @return [Boolean] True if the word is correct
  #
  # @example
  #   Kotoshu.correct?("hello")            # => true (default language)
  #   Kotoshu.correct?("Hallo", language: "de")  # => true
  def self.correct?(word, language: nil, offline: nil, strict: nil)
    checker = language ? spellchecker_for(language, offline: offline, strict: strict) : spellchecker
    checker.correct?(word)
  end

  # Check if a word is misspelled.
  #
  # @param word [String] The word to check
  # @param language [String, nil] Language code; if provided, uses a per-language spellchecker
  # @param offline [Boolean, nil] Override offline mode
  # @param strict [Boolean, nil] Re-raise on optional-resource failure
  # @return [Boolean] True if the word is misspelled
  def self.misspelled?(word, language: nil, offline: nil, strict: nil)
    !correct?(word, language: language, offline: offline, strict: strict)
  end

  # Get spelling suggestions for a word.
  #
  # @param word [String] The misspelled word
  # @param language [String, nil] Language code; if provided, uses a per-language spellchecker
  # @param offline [Boolean, nil] Override offline mode
  # @param strict [Boolean, nil] Re-raise on optional-resource failure
  # @param options [Hash] Options (max_suggestions, etc.)
  # @return [Suggestions::SuggestionSet] Generated suggestions
  #
  # @example
  #   suggestions = Kotoshu.suggest("helo")
  #   suggestions.to_words  # => ["hello", "help", "held", ...]
  def self.suggest(word, language: nil, offline: nil, strict: nil, **options)
    checker = language ? spellchecker_for(language, offline: offline, strict: strict) : spellchecker
    checker.suggest(word, **options)
  end

  # Check text for spelling errors.
  #
  # @param text [String] The text to check
  # @param language [String, nil] Language code; if provided, uses a per-language spellchecker
  # @param offline [Boolean, nil] Override offline mode
  # @param strict [Boolean, nil] Re-raise on optional-resource failure
  # @param options [Hash] Options
  # @return [Models::Result::DocumentResult] The check result
  #
  # @example
  #   result = Kotoshu.check("Hello wrold")
  #   result.errors.map(&:word)  # => ["wrold"]
  def self.check(text, language: nil, offline: nil, strict: nil, **_options)
    checker = language ? spellchecker_for(language, offline: offline, strict: strict) : spellchecker
    checker.check(text)
  end

  # Check a file for spelling errors.
  #
  # @param path [String] The file path
  # @param language [String, nil] Language code; if provided, uses a per-language spellchecker
  # @param offline [Boolean, nil] Override offline mode
  # @param strict [Boolean, nil] Re-raise on optional-resource failure
  # @param options [Hash] Options
  # @return [Models::Result::DocumentResult] The check result
  #
  # @example
  #   result = Kotoshu.check_file("README.md")
  #   result.success?  # => false
  def self.check_file(path, language: nil, offline: nil, strict: nil, **_options)
    checker = language ? spellchecker_for(language, offline: offline, strict: strict) : spellchecker
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
