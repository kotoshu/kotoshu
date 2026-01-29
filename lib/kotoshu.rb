# frozen_string_literal: true

require_relative "kotoshu/version"
require_relative "kotoshu/core/exceptions"
require_relative "kotoshu/core/indexed_dictionary"
require_relative "kotoshu/core/trie/node"
require_relative "kotoshu/core/trie/trie"
require_relative "kotoshu/core/trie/builder"
require_relative "kotoshu/core/models/word"
require_relative "kotoshu/core/models/affix_rule"
require_relative "kotoshu/core/models/result/word_result"
require_relative "kotoshu/core/models/result/document_result"
require_relative "kotoshu/suggestions/suggestion"
require_relative "kotoshu/suggestions/suggestion_set"
require_relative "kotoshu/suggestions/context"
require_relative "kotoshu/suggestions/strategies/base_strategy"
require_relative "kotoshu/suggestions/strategies/composite_strategy"
require_relative "kotoshu/suggestions/strategies/edit_distance_strategy"
require_relative "kotoshu/suggestions/strategies/phonetic_strategy"
require_relative "kotoshu/suggestions/strategies/keyboard_proximity_strategy"
require_relative "kotoshu/suggestions/strategies/ngram_strategy"
require_relative "kotoshu/suggestions/generator"
require_relative "kotoshu/dictionary/base"
require_relative "kotoshu/dictionary/unix_words"
require_relative "kotoshu/dictionary/plain_text"
require_relative "kotoshu/dictionary/custom"
require_relative "kotoshu/dictionary/hunspell"
require_relative "kotoshu/dictionary/cspell"
require_relative "kotoshu/dictionary/repository"
require_relative "kotoshu/configuration"
require_relative "kotoshu/spellchecker"

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

  # Reset the spellchecker (force reload).
  #
  # @return [Spellchecker] The reset spellchecker
  def self.reset_spellchecker
    @spellchecker = nil
    spellchecker
  end

  # Check if a word is spelled correctly.
  #
  # @param word [String] The word to check
  # @return [Boolean] True if the word is correct
  #
  # @example
  #   Kotoshu.correct?("hello")  # => true
  #   Kotoshu.correct?("helo")   # => false
  def self.correct?(word)
    spellchecker.correct?(word)
  end

  # Check if a word is misspelled.
  #
  # @param word [String] The word to check
  # @return [Boolean] True if the word is misspelled
  def self.misspelled?(word)
    !correct?(word)
  end

  # Get spelling suggestions for a word.
  #
  # @param word [String] The misspelled word
  # @param options [Hash] Options (max_suggestions, etc.)
  # @return [Suggestions::SuggestionSet] Generated suggestions
  #
  # @example
  #   suggestions = Kotoshu.suggest("helo")
  #   suggestions.to_words  # => ["hello", "help", "held", ...]
  def self.suggest(word, **options)
    spellchecker.suggest(word, **options)
  end

  # Check text for spelling errors.
  #
  # @param text [String] The text to check
  # @param options [Hash] Options
  # @return [Models::Result::DocumentResult] The check result
  #
  # @example
  #   result = Kotoshu.check("Hello wrold")
  #   result.errors.map(&:word)  # => ["wrold"]
  def self.check(text, **options)
    spellchecker.check(text)
  end

  # Check a file for spelling errors.
  #
  # @param path [String] The file path
  # @param options [Hash] Options
  # @return [Models::Result::DocumentResult] The check result
  #
  # @example
  #   result = Kotoshu.check_file("README.md")
  #   result.success?  # => false
  def self.check_file(path, **options)
    spellchecker.check_file(path)
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
end
