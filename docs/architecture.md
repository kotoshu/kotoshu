# Kotoshu Architecture Document

## Purpose

This document describes the complete architecture of Kotoshu, a spellchecker library for Ruby designed with a modular, object-oriented architecture supporting multiple interfaces (CLI, Ruby API) and multiple dictionary backends.

## Architectural Principles

### Hexagonal Architecture (Ports and Adapters)

Kotoshu follows Hexagonal Architecture principles, separating the code into three distinct layers:

1. **Domain Layer** - Core business logic, completely independent of external concerns
2. **Application Layer** - Use cases that orchestrate domain operations
3. **Interface Layer** - Adapters for different interfaces (CLI, Ruby API)

This separation ensures:
- Core logic can be tested in isolation
- New interfaces can be added without modifying core
- Each interface has consistent access to domain operations

### Design Patterns

The following design patterns are used throughout Kotoshu:

| Pattern | Purpose | Location |
|---------|---------|----------|
| Facade | Simple public API hiding complexity | `Kotoshu.spellcheck()` |
| Repository | Cache and manage loaded dictionaries | `DictionaryRepository` |
| Command | Encapsulate CLI operations | `Commands::*` |
| Strategy | Pluggable algorithms | Dictionary backends, Suggestions |
| Registry | Plugin system for extensions | `Kotoshu::Dictionary.register_type` |
| Value Object | Immutable result objects | `Result`, `DocumentResult` |

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                        Interface Layer                         │
├──────────────────────────┬────────────────────────────────────┤
│      CLI (Thor)          │          Ruby API                  │
│   lib/kotoshu/cli/       │      Public Facade Methods        │
│                          │   (Kotoshu.check, correct?, etc)  │
└──────────────┬───────────┴────────────────┬───────────────────┘
               │                             │
               └─────────────┬───────────────┘
                             │
        ┌────────────────────┴────────────────────┐
        │      Application Layer (Facades)         │
        │  ─────────────────────────────────────   │
        │  • spellchecker.rb (Main Facade)        │
        │  • configuration.rb                      │
        │  • registry.rb                           │
        └────────────────────┬────────────────────┘
                             │
        ┌────────────────────┴────────────────────┐
        │      Domain Layer (Core Logic)           │
        ├──────────────────┬───────────────────────┤
        │   Dictionary      │      Suggestions      │
        │   Backends       │      Algorithms       │
        ├──────────────────┼───────────────────────┤
        │  • Hunspell      │  • EditDistance       │
        │  • CSpell        │  • Phonetic          │
        │  • UnixWords     │  • KeyboardProximity │
        │  • PlainText     │  • NGram             │
        │  • Custom        │  • TrieWalk          │
        ├──────────────────┼───────────────────────┤
        │    Models        │    Data Structures   │
        │  • Word          │    • Trie            │
        │  • AffixRule     │    • Hash            │
        │  • Suggestion    │                      │
        └──────────────────────────────────────────┘
```

## Domain Layer

### Models (Value Objects)

Located in `lib/kotoshu/core/models/`, these are immutable value objects that represent domain concepts.

```ruby
# Word model
class Kotoshu::Models::Word
  attr_reader :text, :flags, :morphological_data

  def initialize(text, flags: [], morphological_data: {})
    @text = text
    @flags = flags
    @morphological_data = morphological_data
    freeze
  end
end

# Affix rule model
class Kotoshu::Models::AffixRule
  attr_reader :type, :flag, :strip_chars, :add_chars, :condition

  def initialize(type:, flag:, strip_chars:, add_chars:, condition:)
    @type = type # :prefix or :suffix
    @flag = flag
    @strip_chars = strip_chars
    @add_chars = add_chars
    @condition = condition
    freeze
  end
end

# Suggestion model
class Kotoshu::Models::Suggestion
  attr_reader :word, :distance, :confidence

  def initialize(word, distance: 0, confidence: 1.0)
    @word = word
    @distance = distance
    @confidence = confidence
    freeze
  end
end
```

### Result Objects

Located in `lib/kotoshu/core/models/result/`, these objects represent the outcome of spell checking operations.

```ruby
# Single word check result
class Kotoshu::Models::Result::WordResult
  attr_reader :word, :correct?, :suggestions

  def initialize(word, correct:, suggestions: [])
    @word = word
    @correct = correct
    @suggestions = suggestions.freeze
    freeze
  end

  def to_h
    {
      word: @word,
      correct: @correct,
      suggestions: @suggestions.map(&:to_h)
    }
  end
end

# Document check result
class Kotoshu::Models::Result::DocumentResult
  attr_reader :file, :errors, :word_count

  def initialize(file, errors: [], word_count: 0)
    @file = file
    @errors = errors.freeze
    @word_count = word_count
    freeze
  end

  def success?
    @errors.empty?
  end

  def to_h
    {
      file: @file,
      success: success?,
      error_count: @errors.count,
      word_count: @word_count,
      errors: @errors.map(&:to_h)
    }
  end
end
```

### Data Structures

Located in `lib/kotoshu/core/trie/`, the trie data structure is used for efficient word lookups (particularly for CSpell dictionaries).

```ruby
# Trie node for compressed trie (DAFSA)
class Kotoshu::Trie::Node
  attr_reader :children, :terminal?, :word

  def initialize
    @children = {}
    @terminal = false
    @word = nil
  end

  def insert(word)
    # Implementation for inserting words into trie
  end

  def lookup(word)
    # Implementation for looking up words in trie
  end
end
```

## Dictionary Backends

Located in `lib/kotoshu/dictionary/`, each dictionary backend implements the common `Dictionary::Base` interface.

### Base Interface

```ruby
class Kotoshu::Dictionary::Base
  attr_reader :language_code, :locale

  def initialize(language_code, locale: nil)
    @language_code = language_code
    @locale = locale
  end

  # Abstract methods - must be implemented by subclasses
  def lookup(word)
    raise NotImplementedError, "#{self.class} must implement #lookup"
  end

  def suggest(word, max_suggestions: 15)
    raise NotImplementedError, "#{self.class} must implement #suggest"
  end

  def add_word(word, flags: [])
    raise NotImplementedError, "#{self.class} must implement #add_word"
  end

  def remove_word(word)
    raise NotImplementedError, "#{self.class} must implement #remove_word"
  end
end
```

### Hunspell Dictionary

```ruby
class Kotoshu::Dictionary::Hunspell < Kotoshu::Dictionary::Base
  attr_reader :word_index, :affix_rules

  def initialize(dic_path, aff_path, language_code:, locale: nil)
    super(language_code, locale: locale)
    @word_index = {}
    @affix_rules = { prefix: [], suffix: [] }
    load_dic_file(dic_path)
    load_aff_file(aff_path)
  end

  def lookup(word)
    # Direct lookup
    return true if @word_index.key?(word.downcase)

    # Apply affix rules to generate word variants
    word_variants(word).any? { |v| @word_index.key?(v.downcase) }
  end

  private

  def load_dic_file(path)
    # Parse .dic file and populate word_index
  end

  def load_aff_file(path)
    # Parse .aff file and populate affix_rules
  end

  def word_variants(word)
    # Generate all possible word forms by applying affix rules
  end
end
```

### CSpell Dictionary

```ruby
class Kotoshu::Dictionary::CSpell < Kotoshu::Dictionary::Base
  attr_reader :trie

  def initialize(path, language_code:, locale: nil)
    super(language_code, locale: locale)
    @trie = Kotoshu::Trie::Builder.build_from_file(path)
  end

  def lookup(word)
    @trie.lookup(word.downcase)
  end

  def suggest(word, max_suggestions: 15)
    # Use trie walking algorithm for suggestions
    @trie.nearby_words(word, max_results: max_suggestions)
  end
end
```

### UnixWords Dictionary

```ruby
class Kotoshu::Dictionary::UnixWords < Kotoshu::Dictionary::Base
  attr_reader :word_set

  def initialize(path = nil, language_code: "en", locale: nil)
    super(language_code, locale: locale)
    @path = path || detect_system_dictionary
    @word_set = load_words
  end

  def lookup(word)
    @word_set.include?(word.downcase)
  end

  def suggest(word, max_suggestions: 15)
    # Simple edit distance suggestions from word_set
    Kotoshu::Suggestions::Algorithms::EditDistance
      .new(@word_set)
      .generate(word, max_results: max_suggestions)
  end

  private

  def detect_system_dictionary
    # Check common paths in order of precedence
    [
      "/usr/share/dict/words",
      "/usr/share/dict/web2",
      "/usr/dict/words"
    ].find { |path| File.exist?(path) }
  end

  def load_words
    File.foreach(@path, chomp: true).with_object(Set.new) do |line, set|
      word = line.strip
      set << word unless word.empty? || word.start_with?("#")
    end
  end
end
```

### Custom Dictionary

```ruby
class Kotoshu::Dictionary::Custom < Kotoshu::Dictionary::Base
  attr_reader :words

  def initialize(words: [], language_code: "custom", locale: nil)
    super(language_code, locale: locale)
    @words = Set.new(words)
  end

  def lookup(word)
    @words.include?(word.downcase)
  end

  def add_word(word, flags: [])
    @words << word.downcase
  end

  def remove_word(word)
    @words.delete(word.downcase)
  end
end
```

### Dictionary Repository

```ruby
class Kotoshu::Dictionary::Repository
  def initialize
    @dictionaries = {}
  end

  def register(key, dictionary)
    @dictionaries[key] = dictionary
  end

  def get(key)
    @dictionaries[key]
  end

  def clear
    @dictionaries.clear
  end
end
```

## Suggestion Algorithms

Located in `lib/kotoshu/suggestions/`, each algorithm implements the common `Suggestions::Base` interface.

### Base Interface

```ruby
class Kotoshu::Suggestions::Base
  def initialize(dictionary_or_word_set)
    @dictionary = dictionary_or_word_set
  end

  def generate(word, max_results: 5)
    raise NotImplementedError, "#{self.class} must implement #generate"
  end
end
```

### Edit Distance Algorithm

```ruby
class Kotoshu::Suggestions::Algorithms::EditDistance < Kotoshu::Suggestions::Base
  def generate(word, max_results: 5)
    candidates = if @dictionary.is_a?(Kotoshu::Dictionary::Base)
                    @dictionary.word_index.keys
                  else
                    @dictionary
                  end

    candidates
      .map { |c| [c, distance(word, c)] }
      .select { |_, d| d <= 2 }
      .sort_by { |_, d| d }
      .first(max_results)
      .map(&:first)
  end

  private

  def distance(a, b)
    # Levenshtein distance implementation
  end
end
```

### Phonetic Algorithm

```ruby
class Kotoshu::Suggestions::Algorithms::Phonetic < Kotoshu::Suggestions::Base
  def generate(word, max_results: 5)
    word_code = phonetic_code(word)

    candidates = if @dictionary.is_a?(Kotoshu::Dictionary::Base)
                    @dictionary.word_index.keys
                  else
                    @dictionary
                  end

    candidates
      .select { |c| phonetic_code(c) == word_code }
      .take(max_results)
  end

  private

  def phonetic_code(word)
    # Soundex or Metaphone algorithm
  end
end
```

### Suggestion Generator

```ruby
class Kotoshu::Suggestions::Generator
  def initialize(dictionary, algorithms: default_algorithms)
    @dictionary = dictionary
    @algorithms = algorithms
  end

  def generate(word, max_suggestions: 15)
    return [] if @dictionary.lookup(word)

    @algorithms
      .flat_map { |algo| algo.generate(word, max_results: max_suggestions) }
      .uniq
      .first(max_suggestions)
  end

  private

  def default_algorithms
    [
      Kotoshu::Suggestions::Algorithms::EditDistance.new(@dictionary),
      Kotoshu::Suggestions::Algorithms::Phonetic.new(@dictionary)
    ]
  end
end
```

## Application Layer

### Main Facade

Located in `lib/kotoshu/spellchecker.rb`, this is the primary entry point for the Ruby API.

```ruby
class Kotoshu::Spellchecker
  attr_reader :dictionary, :suggestion_generator

  def initialize(dictionary:)
    @dictionary = dictionary
    @suggestion_generator = Kotoshu::Suggestions::Generator.new(@dictionary)
  end

  def correct?(word)
    @dictionary.lookup(word)
  end

  def suggest(word, max_suggestions: 15)
    return [] if correct?(word)
    @suggestion_generator.generate(word, max_suggestions: max_suggestions)
  end

  def check(text)
    # Tokenize text and check each word
    # Returns DocumentResult
  end

  def check_file(path)
    # Read file and check contents
    # Returns DocumentResult
  end

  def check_directory(path)
    # Check all files in directory
    # Returns array of DocumentResult
  end
end
```

### Public API Module

Located in `lib/kotoshu.rb`, this provides the convenient module-level API.

```ruby
module Kotoshu
  class << self
    def configure
      yield configuration
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def spellchecker
      @spellchecker ||= Spellchecker.new(
        dictionary: configuration.dictionary
      )
    end

    # Convenience methods
    def correct?(word)
      spellchecker.correct?(word)
    end

    def check(text, options = {})
      # Apply per-call options and check
    end

    def check_file(path)
      spellchecker.check_file(path)
    end

    def suggest(word, options = {})
      spellchecker.suggest(word, **options)
    end
  end
end
```

### Configuration

```ruby
class Kotoshu::Configuration
  attr_accessor :dictionary_path, :dictionary_type, :language,
                :max_suggestions, :case_sensitive, :verbose

  def initialize
    @dictionary_path = nil
    @dictionary_type = :unix_words
    @language = "en"
    @max_suggestions = 15
    @case_sensitive = false
    @verbose = false
  end

  def dictionary
    @dictionary ||= load_dictionary
  end

  private

  def load_dictionary
    klass = case @dictionary_type
            when :hunspell then Kotoshu::Dictionary::Hunspell
            when :cspell then Kotoshu::Dictionary::CSpell
            when :unix_words then Kotoshu::Dictionary::UnixWords
            when :plain_text then Kotoshu::Dictionary::PlainText
            when :custom then Kotoshu::Dictionary::Custom
            else raise ArgumentError, "Unknown dictionary type: #{@dictionary_type}"
            end

    klass.new(@dictionary_path, language_code: @language)
  end
end
```

### Registry

```ruby
module Kotoshu
  class << self
    def register_dictionary_type(type, klass)
      Dictionary.register_type(type, klass)
    end

    def register_suggestion_algorithm(name, klass)
      Suggestions.register_algorithm(name, klass)
    end
  end
end

module Kotoshu::Dictionary
  @registry = {}

  class << self
    def register_type(type, klass)
      @registry[type] = klass
    end

    def load(type, *args)
      klass = @registry[type] || raise(ArgumentError, "Unknown dictionary type: #{type}")
      klass.new(*args)
    end
  end
end
```

## Interface Layer

### CLI Adapter

Located in `lib/kotoshu/cli/`, the CLI is implemented using Thor following Ribose Ruby gem standards.

**Main CLI Class (`lib/kotoshu/cli.rb`):**

```ruby
class Kotoshu::Cli < Thor
  class_option :verbose, type: :boolean, desc: "Enable verbose output"
  class_option :dictionary, aliases: :d, desc: "Dictionary path or type"
  class_option :language, aliases: :l, desc: "Language code"
  class_option :output, aliases: :o, desc: "Output format (text, json)"

  desc "check TEXT|FILE", "Check spelling"
  option :write, aliases: :w, desc: "Write corrections to file"
  def check(target)
    command = Commands::CheckCommand.new(options)
    command.run(target)
  end

  desc "dict [ACTION]", "Dictionary management"
  subcommand "dict", DictCommand

  desc "version", "Show version"
  def version
    puts "Kotoshu #{Kotoshu::VERSION}"
  end
end
```

**Command Classes:**

Each command is implemented as a separate class in `lib/kotoshu/commands/`:

```ruby
# lib/kotoshu/commands/check_command.rb
class Kotoshu::Commands::CheckCommand < Kotoshu::Cli
  def initialize(options = {})
    @options = options
  end

  def run(target)
    configure_from_options

    result = if File.exist?(target)
               Kotoshu.check_file(target)
             else
               Kotoshu.check_string(target)
             end

    format_and_display(result)
    exit(result.success? ? 0 : 1)
  end

  private

  def configure_from_options
    Kotoshu.configure do |config|
      config.dictionary_path = @options[:dictionary] if @options[:dictionary]
      config.language = @options[:language] if @options[:language]
      config.verbose = @options[:verbose]
    end
  end
end

# lib/kotoshu/commands/dict_command.rb
class Kotoshu::Commands::DictCommand < Kotoshu::Cli
  desc "list", "List available dictionaries"
  def list
    # Implementation
  end

  desc "info ID", "Show dictionary information"
  def info(id)
    # Implementation
  end
end
```

**CLI Executable (`exe/kotoshu`):**

```ruby
#!/usr/bin/env ruby
# frozen_string_literal: true

require "kotoshu/cli"
Kotoshu::Cli.start(ARGV)
```

## Exception Hierarchy

```ruby
class Kotoshu::Error < StandardError; end

class Kotoshu::DictionaryNotFoundError < Kotoshu::Error; end
class Kotoshu::InvalidDictionaryFormatError < Kotoshu::Error; end
class Kotoshu::ConfigurationError < Kotoshu::Error; end
class Kotoshu::SpellcheckError < Kotoshu::Error; end
```

## Error Handling by Interface

| Interface | Error Handling Strategy |
|-----------|------------------------|
| CLI | Catch exceptions, display user-friendly messages, exit with code |
| Ruby API | Propagate exceptions for caller to handle |
| HTTP API (future) | Catch exceptions, return JSON with HTTP status codes |

## File Structure

```
lib/kotoshu/
├── version.rb                          # Version constant
├── spellchecker.rb                     # Main Spellchecker class
├── configuration.rb                    # Configuration management
├── registry.rb                         # Plugin registry
│
├── core/                               # Domain Layer
│   ├── models/
│   │   ├── word.rb
│   │   ├── affix_rule.rb
│   │   ├── suggestion.rb
│   │   └── result/
│   │       ├── word_result.rb
│   │       └── document_result.rb
│   ├── trie/
│   │   ├── node.rb
│   │   └── builder.rb
│   └── exceptions.rb
│
├── dictionary/
│   ├── base.rb
│   ├── repository.rb
│   ├── hunspell.rb
│   ├── cspell.rb
│   ├── unix_words.rb
│   ├── plain_text.rb
│   └── custom.rb
│
├── suggestions/
│   ├── generator.rb
│   ├── base.rb
│   └── algorithms/
│       ├── edit_distance.rb
│       ├── phonetic.rb
│       ├── keyboard_proximity.rb
│       ├── ngram.rb
│       └── trie_walk.rb
│
└── cli/                                # Interface Layer
    ├── cli.rb
    └── commands/
        ├── check_command.rb
        ├── dict_command.rb
        └── version_command.rb
```

## Dependencies

- **Ruby**: 3.1+
- **Thor**: CLI option parsing
- **RSpec**: Testing
- **RuboCop**: Linting

No external dependencies for core functionality (dictionary loading, suggestions, etc.).

## Performance Considerations

- **Dictionary Loading**: Expensive operation, loaded once per configuration
- **Word Lookup**: O(1) for hash-based, O(n) for trie-based
- **Suggestions**: Generated only for misspelled words
- **Memory**: Dictionaries cached for lifetime of process

## Future HTTP API

The HTTP API will be implemented in a separate gem (`kotoshu-server`) with:

- Sinatra for routing
- JSON request/response
- RESTful endpoints
- Versioned API (/v1/)
- Rate limiting capability
- Standalone server mode

This separation ensures:
- Core library has no web dependencies
- HTTP API can be versioned independently
- Can be embedded in Rails apps or run standalone
