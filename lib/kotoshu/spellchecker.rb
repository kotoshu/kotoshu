# frozen_string_literal: true

require_relative "configuration"
require_relative "suggestions/generator"
require_relative "core/models/result/word_result"
require_relative "core/models/result/document_result"

module Kotoshu
  # Main spellchecker class.
  #
  # This is the primary facade for spell checking operations,
  # providing methods to check words, text, and files.
  #
  # @example Creating a spellchecker with a dictionary
  #   dict = Kotoshu::Dictionary::UnixWords.new("/usr/share/dict/words", language_code: "en-US")
  #   spellchecker = Spellchecker.new(dictionary: dict)
  #   spellchecker.correct?("hello")  # => true
  #
  # @example Using configuration
  #   spellchecker = Spellchecker.new(
  #     dictionary_path: "/usr/share/dict/words",
  #     language: "en-US"
  #   )
  class Spellchecker
    # @return [Suggestions::Generator] The suggestion generator
    attr_reader :generator

    # @return [Configuration] The configuration
    attr_reader :config

    # Create a new spellchecker.
    #
    # @param dictionary [Dictionary::Base, nil] The dictionary (optional)
    # @param config [Configuration, Hash] Configuration or settings
    # @param kwargs [Hash] Additional configuration options
    #
    # @example With dictionary
    #   spellchecker = Spellchecker.new(dictionary: dict)
    #
    # @example With configuration hash
    #   spellchecker = Spellchecker.new(
    #     dictionary_path: "/usr/share/dict/words",
    #     language: "en-US"
    #   )
    #
    # @example With Configuration object
    #   config = Configuration.new(dictionary_path: "words.txt")
    #   spellchecker = Spellchecker.new(config: config)
    def initialize(dictionary: nil, config: nil, **kwargs)
      if config.is_a?(Configuration)
        @config = config
      else
        settings = kwargs.dup
        settings[:dictionary_path] = dictionary.path if dictionary && dictionary.respond_to?(:path)
        @config = Configuration.new(settings)
      end

      # If dictionary was provided directly, use it
      if dictionary
        @config.dictionary = dictionary
      end

      dict = @config.dictionary
      max_suggestions = @config.max_suggestions

      @generator = Suggestions::Generator.new(
        dict,
        max_suggestions: max_suggestions,
        algorithms: @config.suggestion_algorithms
      )
    end

    # Check if a word is spelled correctly.
    #
    # @param word [String] The word to check
    # @return [Boolean] True if the word is correct
    #
    # @example
    #   spellchecker.correct?("hello")  # => true
    #   spellchecker.correct?("helo")   # => false
    def correct?(word)
      return false if word.nil? || word.empty?

      @generator.correct?(word)
    end

    # Check if a word is misspelled.
    #
    # @param word [String] The word to check
    # @return [Boolean] True if the word is misspelled
    def incorrect?(word)
      !correct?(word)
    end

    # Get spelling suggestions for a word.
    #
    # @param word [String] The misspelled word
    # @param max_suggestions [Integer] Maximum suggestions (optional)
    # @return [Suggestions::SuggestionSet] Generated suggestions
    #
    # @example
    #   suggestions = spellchecker.suggest("helo")
    #   suggestions.to_words  # => ["hello", "help", "held", ...]
    def suggest(word, max_suggestions: nil)
      return Suggestions::SuggestionSet.empty if word.nil? || word.empty?

      @generator.generate(word, max_suggestions: max_suggestions)
    end

    # Check a word and return a result object.
    #
    # @param word [String] The word to check
    # @return [Models::Result::WordResult] The check result
    #
    # @example
    #   result = spellchecker.check_word("hello")
    #   result.correct?  # => true
    #
    # @example With misspelled word
    #   result = spellchecker.check_word("helo")
    #   result.correct?         # => false
    #   result.suggestions      # => SuggestionSet with suggestions
    def check_word(word)
      return Models::Result::WordResult.new("", correct: false, suggestions: Suggestions::SuggestionSet.empty) if word.nil? || word.empty?

      if correct?(word)
        Models::Result::WordResult.correct(word)
      else
        suggestions = suggest(word)
        Models::Result::WordResult.incorrect(word, suggestions: suggestions)
      end
    end

    # Check text for spelling errors.
    #
    # @param text [String] The text to check
    # @return [Models::Result::DocumentResult] The check result
    #
    # @example
    #   result = spellchecker.check("Hello wrold")
    #   result.success?    # => false
    #   result.errors.map(&:word)  # => ["wrold"]
    def check(text)
      return Models::Result::DocumentResult.success if text.nil? || text.empty?

      words = tokenize(text)
      errors = []
      position = 0

      words.each do |word_data|
        word, pos = word_data
        result = check_word(word)

        if result.incorrect?
          errors << Models::Result::WordResult.new(
            word,
            correct: false,
            suggestions: result.suggestions,
            position: pos
          )
        end

        position = pos
      end

      Models::Result::DocumentResult.new(
        file: nil,
        errors: errors,
        word_count: words.size
      )
    end

    # Check a file for spelling errors.
    #
    # @param path [String] The file path
    # @return [Models::Result::DocumentResult] The check result
    #
    # @example
    #   result = spellchecker.check_file("README.md")
    #   result.to_s  # => "File 'README.md': 3 spelling error(s) found"
    def check_file(path)
      raise DictionaryNotFoundError, path unless File.exist?(path)

      text = File.read(path, encoding: @config.encoding)
      result = check(text)

      # Create a new result with the file path
      Models::Result::DocumentResult.new(
        file: path,
        errors: result.errors,
        word_count: result.word_count
      )
    end

    # Check a directory for spelling errors.
    #
    # @param path [String] The directory path
    # @param pattern [String] File pattern to match (default: "*.txt")
    # @return [Array<Models::Result::DocumentResult>] Results for each file
    #
    # @example
    #   results = spellchecker.check_directory("docs/")
    #   results.select(&:failed?).map(&:file)
    def check_directory(path, pattern: "*.txt")
      raise DictionaryNotFoundError, path unless File.exist?(path) && File.directory?(path)

      files = Dir.glob(File.join(path, pattern))
      files.map { |file| check_file(file) }
    end

    # Tokenize text into words.
    #
    # @param text [String] The text to tokenize
    # @return [Array<Array>] Array of [word, position] pairs
    #
    # @example
    #   spellchecker.tokenize("Hello world!")
    #   # => [["Hello", 0], ["world", 6]]
    def tokenize(text)
      return [] if text.nil? || text.empty?

      words = []
      position = 0
      word_buffer = String.new
      word_start = 0

      text.each_char.with_index do |char, i|
        if word_char?(char)
          word_buffer << char
          word_start = i if word_buffer.length == 1
          position = i
        else
          if !word_buffer.empty?
            words << [word_buffer.dup.freeze, word_start]
            word_buffer.clear
          end
        end
      end

      # Don't forget the last word
      words << [word_buffer.dup.freeze, word_start] if !word_buffer.empty?

      words
    end

    # Get the dictionary being used.
    #
    # @return [Dictionary::Base] The dictionary
    def dictionary
      @generator.dictionary
    end

    # Reload the dictionary.
    #
    # @return [self] Self for chaining
    def reload_dictionary
      @config.reset_dictionary

      dict = @config.dictionary
      @generator = Suggestions::Generator.new(
        dict,
        max_suggestions: @config.max_suggestions,
        algorithms: @config.suggestion_algorithms
      )

      self
    end

    private

    # Check if a character is part of a word.
    #
    # @param char [String] The character
    # @return [Boolean] True if it's a word character
    def word_char?(char)
      case char
      when "a".."z", "A".."Z", "'"
        true
      else
        false
      end
    end
  end
end
