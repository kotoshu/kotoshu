# frozen_string_literal: true

require "set"

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

    # @return [ResourceBundle, nil] The resource bundle if provided
    attr_reader :resource_bundle

    # @return [NativeBackend, nil] The native engine, when backend
    #   selection activated one (see Configuration#backend /
    #   KOTOSHU_BACKEND). Nil means every call runs the pure-Ruby engine.
    attr_reader :native_backend

    # Word characters for extraction when the language has no script
    # tokenizer: ASCII letters and the apostrophe, the pre-plan-91 set
    # (kept as the fallback so unknown languages behave as before).
    ASCII_WORD_REGEX = /[a-zA-Z']/

    # Create a new spellchecker.
    #
    # @param dictionary [Dictionary::Base, nil] The dictionary (optional)
    # @param config [Configuration, Hash] Configuration or settings
    # @param resource_bundle [ResourceBundle, nil] Pre-resolved resource bundle
    # @param kwargs [Hash] Additional configuration options
    #
    # @example With dictionary
    #   spellchecker = Spellchecker.new(dictionary: dict)
    #
    # @example With resource bundle (0.2+)
    #   bundle = Kotoshu::ResourceManager.resolve(language: "en")
    #   spellchecker = Spellchecker.new(resource_bundle: bundle)
    #   spellchecker.correct?("hello")  # => true
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
    def initialize(dictionary: nil, config: nil, resource_bundle: nil, **kwargs)
      @resource_bundle = resource_bundle

      if resource_bundle
        dictionary ||= resource_bundle.dictionary
        kwargs[:language] = resource_bundle.language unless kwargs.key?(:language)
      end

      if config.is_a?(Configuration)
        @config = config
      else
        settings = kwargs.dup
        settings[:dictionary_path] = dictionary.path if dictionary
        @config = Configuration.new(settings)
      end

      @config.dictionary = dictionary if dictionary

      dict = @config.dictionary
      max_suggestions = @config.max_suggestions

      @generator = Suggestions::Generator.new(
        dict,
        max_suggestions: max_suggestions,
        algorithms: @config.suggestion_algorithms
      )

      # Backend selection (plan 66): when active, correct?/suggest run on
      # the native engine; everything else keeps using @generator. The
      # generator is always built — the native backend is an accelerator,
      # never a replacement for the Ruby engine's non-hot-path surface.
      @native_backend = NativeBackend.resolve(
        dictionary: dict,
        backend: @config.backend,
        max_suggestions: max_suggestions
      )

      # Word extraction follows the configured language's script
      # (plan 91): its tokenizer decides which letters form words,
      # so Greek/Cyrillic words become checkable for el/uk while
      # wrong-script words stay invisible. Nil keeps the ASCII set.
      @language_tokenizer = resolve_language_tokenizer
      @word_char_regex = @language_tokenizer&.spellcheck_word_regex || ASCII_WORD_REGEX
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

      return @native_backend.correct?(word) if @native_backend

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

      return @native_backend.suggest(word, max_suggestions: max_suggestions) if @native_backend

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
      if word.nil? || word.empty?
        return Models::Result::WordResult.new(word: "", correct: false,
                                              suggestions: Suggestions::SuggestionSet.empty)
      end

      if correct?(word)
        Models::Result::WordResult.correct(word)
      else
        suggestions = suggest(word)
        Models::Result::WordResult.incorrect(word, suggestions: suggestions)
      end
    end

    # Check text for spelling errors.
    #
    # Words present in the user's personal dictionary
    # (~/.config/kotoshu/personal.dic, KOTOSHU_PERSONAL_DIC override)
    # never surface as errors — the same semantics the LSP applies to
    # its diagnostics (plan 105). They are dropped at result assembly
    # without suppression metadata, still count toward +word_count+,
    # and remain spellcheckable through {#suggest}. Opt out with
    # {Configuration#personal_dictionary} (KOTOSHU_PERSONAL_DICTIONARY,
    # `kotoshu check --no-personal`).
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

      # Inline ignore directives (plan 82): suppressed errors move into
      # suppressed_errors instead of failing the check. The :auto profile
      # recognizes bare, Markdown HTML-comment, and AsciiDoc // directives
      # because the facade sees raw text without a format parser.
      words = tokenize(text)
      suppressions = Documents::Suppressions.scan(text, format: :auto)
      personal = personal_words
      errors = []
      suppressed_errors = []
      words.each do |word, pos|
        next if personal.include?(word.downcase)

        result = check_word(word)
        next if result.correct?

        line = Documents::SourcePosition.line_for_offset(text, pos)
        suppressed = suppressions.any? { |s| s.applies_to?(line, word: word) }
        entry = Models::Result::WordResult.new(
          word: word,
          correct: false,
          suggestions: result.suggestions,
          position: pos,
          suppressed: suppressed,
          suppressed_by: (Models::Result::WordResult::SUPPRESSED_BY_INLINE if suppressed)
        )
        (suppressed ? suppressed_errors : errors) << entry
      end
      Models::Result::DocumentResult.new(
        file: nil,
        errors: errors,
        suppressed_errors: suppressed_errors,
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
        elsif !word_buffer.empty?
          words << [word_buffer.dup.freeze, word_start]
          word_buffer.clear
        end
      end

      # Don't forget the last word
      words << [word_buffer.dup.freeze, word_start] unless word_buffer.empty?

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
      @native_backend = NativeBackend.resolve(
        dictionary: dict,
        backend: @config.backend,
        max_suggestions: @config.max_suggestions
      )

      self
    end

    private

    # The personal dictionary as a downcased Set for the check path
    # (plan 105), mirroring the LSP's filter. Loaded once per process:
    # the first {#check} call snapshots the words, and later edits to
    # personal.dic take effect in the next process (the LSP reloads on
    # mtime change; this path deliberately does not — one-shot CLI runs
    # always read fresh, and long-lived embedders rebuild the
    # spellchecker via {Kotoshu.reset_spellchecker}). An empty set when
    # disabled through {Configuration#personal_dictionary}.
    #
    # @return [Set<String>]
    def personal_words
      return @personal_words if instance_variable_defined?(:@personal_words)

      @personal_words =
        if @config.personal_dictionary
          PersonalDictionary.words.map(&:downcase).to_set
        else
          Set.new
        end
    end

    # Resolve the tokenizer of the language being checked for word
    # extraction (plan 91).
    #
    # Only Language::Tokenizer::Base tokenizers participate: their
    # script subclasses (Greek, Cyrillic, Latin) declare which letters
    # form words. Anything else — components tokenizers such as
    # English's whitespace tokenizer, or an unknown language — returns
    # nil and the ASCII fallback applies.
    #
    # A resource bundle pins the language: spellchecker_for passes the
    # shared global Configuration next to the resolved bundle, and the
    # config may still carry the global default language instead of
    # the one actually being checked.
    #
    # @return [Language::Tokenizer::Base, nil] The language tokenizer
    def resolve_language_tokenizer
      code = @resource_bundle&.language || @config.language
      return nil if code.nil? || code.empty?

      language_class = Language::Registry.get(code)
      return nil if language_class.nil?

      tokenizer = language_class.new.tokenizer
      tokenizer.is_a?(Language::Tokenizer::Base) ? tokenizer : nil
    end

    # Check if a character is part of a word.
    #
    # Uses the language tokenizer's script-aware set when one is
    # configured; otherwise the historical ASCII letters plus
    # apostrophe.
    #
    # @param char [String] The character
    # @return [Boolean] True if it's a word character
    def word_char?(char)
      @word_char_regex.match?(char)
    end
  end
end
