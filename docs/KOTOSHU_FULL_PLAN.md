# Kotoshu Implementation Plan

## Overview

This document provides a complete implementation plan for Kotoshu following Ribose Ruby gem standards. The plan is organized into phases, with each phase building on the previous one.

## Phase 0: Gem Setup

### 0.1 Gem Structure

- [ ] Verify gem structure matches Ribose standards:
  ```
  kotoshu/
  ├── exe/                    # Executables
  │   └── kotoshu
  ├── lib/
  │   └── kotoshu/
  ├── spec/
  │   └── fixtures/
  ├── Gemfile
  ├── Rakefile
  ├── kotoshu.gemspec
  ├── .rubocop.yml
  ├── .rspec
  ├── LICENSE
  ├── README.adoc           # AsciiDoc format (not README.md)
  └── sig/                   # RBS type signatures
  ```

- [ ] Ensure `exe/` directory exists
- [ ] Ensure proper executable shebang: `#!/usr/bin/env ruby`

### 0.2 Gemfile Dependencies

- [ ] Update `Gemfile` following Ribose standards:
  ```ruby
  # frozen_string_literal: true

  source "https://rubygems.org"

  # Specify your gem's dependencies in kotoshu.gemspec
  gemspec

  # Local development gems (no :group, no version numbers)
  gem "rake"
  gem "rspec"
  gem "rubocop"
  ```

### 0.3 Rakefile

- [ ] Verify `Rakefile` includes:
  ```ruby
  # frozen_string_literal: true

  require "bundler/gem_tasks"
  require "rspec/core/rake_task"

  RSpec::Core::RakeTask.new(:spec)

  require "rubocop/rake_task"

  RuboCop::RakeTask.new

  task default: %i[spec rubocop]
  ```

### 0.4 RuboCop Configuration

- [ ] Verify `.rubocop.yml` configuration:
  ```yaml
  AllCops:
    TargetRubyVersion: 3.1

  Style/StringLiterals:
    EnforcedStyle: double_quotes

  Style/StringLiteralsInInterpolation:
    EnforcedStyle: double_quotes
  ```

- [ ] Add 80 character line limit if not present
- [ ] Enable performance cops if needed

## Phase 1: Foundation

**Code Style Standards (Ribose Ruby Gem Requirements):**
- [ ] Use 2 spaces for indentation, no tabs
- [ ] Max line length of 80 characters (enforced by RuboCop)
- [ ] Use `frozen_string_literal: true` in all files
- [ ] Use double quotes for strings (enforced by RuboCop)
- [ ] Use `require_relative` to load files in same codebase
- [ ] Use `attr_reader`, `attr_writer`, `attr_accessor` for attributes
- [ ] Never use `Struct` or `OpenStruct` - use dedicated model classes
- [ ] Minimize usage of Hash objects - use model classes instead
- [ ] Ensure separation of concerns and MECE design
- [ ] Each class should have its own file (small classes used only within parent may be defined in same file)
- [ ] Methods should be focused and not exceed 50 lines
- [ ] Classes should be backed by RSpec tests covering all scenarios

### 1.1 Project Structure Setup

- [ ] Create directory structure under `lib/kotoshu/`
  - [ ] `core/models/`
  - [ ] `core/models/result/`
  - [ ] `core/trie/`
  - [ ] `dictionary/`
  - [ ] `suggestions/`
  - [ ] `suggestions/algorithms/`
  - [ ] `cli/`
  - [ ] `cli/commands/`

- [ ] Create `sig/kotoshu/` directory structure
  - [ ] Create RBS files for all public classes

- [ ] Update `lib/kotoshu.rb` with module definition
  ```ruby
  # frozen_string_literal: true

  require_relative "kotoshu/version"
  require_relative "kotoshu/core/exceptions"
  require_relative "kotoshu/core/models/word"
  require_relative "kotoshu/core/models/affix_rule"
  require_relative "kotoshu/core/models/suggestion"
  # ... other requires

  module Kotoshu
    class Error < StandardError; end
    # Your code goes here...
  end
  ```

### 1.2 Core Models

- [ ] `core/models/word.rb`
  - [ ] Implement `Kotoshu::Models::Word` class
  - [ ] Add `text`, `flags`, `morphological_data` attributes
  - [ ] Add `valid?` method
  - [ ] Make immutable (freeze on initialize)
  - [ ] Write RSpec tests

- [ ] `core/models/affix_rule.rb`
  - [ ] Implement `Kotoshu::Models::AffixRule` class
  - [ ] Add `type`, `flag`, `strip_chars`, `add_chars`, `condition` attributes
  - [ ] Add `prefix?` and `suffix?` predicates
  - [ ] Make immutable
  - [ ] Write RSpec tests

- [ ] `core/models/suggestion.rb`
  - [ ] Implement `Kotoshu::Models::Suggestion` class
  - [ ] Add `word`, `distance`, `confidence` attributes
  - [ ] Add `to_h` method for serialization
  - [ ] Make immutable
  - [ ] Write RSpec tests

### 1.3 Result Objects

- [ ] `core/models/result/word_result.rb`
  - [ ] Implement `Kotoshu::Models::Result::WordResult` class
  - [ ] Add `word`, `correct?`, `suggestions` attributes
  - [ ] Add `to_h` method
  - [ ] Make immutable
  - [ ] Write RSpec tests

- [ ] `core/models/result/document_result.rb`
  - [ ] Implement `Kotoshu::Models::Result::DocumentResult` class
  - [ ] Add `file`, `errors`, `word_count` attributes
  - [ ] Add `success?` method
  - [ ] Add `each_error` method for iteration
  - [ ] Add `to_h` method
  - [ ] Make immutable
  - [ ] Write RSpec tests

### 1.4 Exception Hierarchy

- [ ] `core/exceptions.rb`
  ```ruby
  class Kotoshu::Error < StandardError; end
  class Kotoshu::DictionaryNotFoundError < Kotoshu::Error; end
  class Kotoshu::InvalidDictionaryFormatError < Kotoshu::Error; end
  class Kotoshu::ConfigurationError < Kotoshu::Error; end
  class Kotoshu::SpellcheckError < Kotoshu::Error; end
  ```
  - [ ] Create exception hierarchy
  - [ ] Write RSpec tests for exception classes

### 1.5 Trie Data Structure ✅ COMPLETED

**NOTE: This section has been implemented with a MORE model-driven OOP design than Spylls.**

- [x] `core/trie/node.rb` ✅
  - [x] Implement `Kotoshu::Core::Trie::Node` class
  - [x] Add `children` hash with behavior
  - [x] Add `terminal?` flag
  - [x] Add `payload` attribute
  - [x] Implement behavior methods: `add_child`, `child`, `has_child?`, `mark_terminal`, `has_children?`
  - [x] Make nodes immutable (frozen)
  - [x] Write RSpec tests

- [x] `core/trie/trie.rb` ✅
  - [x] Implement `Kotoshu::Core::Trie::Trie` class
  - [x] Add `insert(word, payload)` method with chaining
  - [x] Add `lookup(word)` method (aliases: `has_word?`, `contains?`)
  - [x] Add `has_prefix?(prefix)` method
  - [x] Add `words_with_prefix(prefix)` method
  - [x] Add `suggestions(word, max_results)` method
  - [x] Add `each_word` enumerator
  - [x] Add `traverse` method with visitor pattern support
  - [x] Add set operations: `merge!`, `&`, `|`
  - [x] Add `empty?`, `clear`, `size` methods
  - [x] Make trie immutable after build
  - [x] Write RSpec tests

- [x] `core/trie/builder.rb` ✅
  - [x] Implement `Kotoshu::Core::Trie::Builder` class
  - [x] Add fluent interface: `add_word`, `add_words`, `from_hash`, `from_array`
  - [x] Add `from_file(path)` instance method
  - [x] Add `from_file(path)` class method
  - [x] Add `from_array(words)` class method
  - [x] Add `from_string(text)` class method
  - [x] Implement `build` method that freezes the trie
  - [x] Write RSpec tests
  - [x] Add fixture files in `spec/fixtures/dictionaries/cspell/`

**Key OOP Improvements over Spylls:**
- `Node` has behavior methods instead of being a simple data container
- `Trie` has rich query API with method chaining (`insert` returns self)
- `Builder` pattern with fluent interface for construction
- Enumerable support with lazy evaluation
- Set operations (`&`, `|`, `merge!`) for combining tries

### 1.6 Indexed Dictionary ✅ COMPLETED

**NOTE: This section has been implemented as a proper domain model, MORE OOP than Spylls.**

- [x] `core/indexed_dictionary.rb` ✅
  - [x] Implement `Kotoshu::Core::IndexedDictionary` class
  - [x] Add multiple indexes: exact, lowercase, prefix, suffix, flag
  - [x] Implement `add_word(word, metadata)` with chaining
  - [x] Implement `has_word?(word)` method (case-sensitive)
  - [x] Implement `has_word_ignorecase?(word)` method
  - [x] Implement `lookup(word)` method (case-sensitive)
  - [x] Implement `lookup_ignorecase(word)` method
  - [x] Implement `find_by_prefix(prefix, ignore_case:)` method
  - [x] Implement `find_by_suffix(suffix, ignore_case:)` method
  - [x] Implement `find_by_pattern(pattern)` method
  - [x] Implement `find_by_length(length)` method
  - [x] Implement `find_by_length_range(min:, max:)` method
  - [x] Implement `all_words` method
  - [x] Implement `random_words(count:)` method
  - [x] Implement `count_by_first_letter` method
  - [x] Implement `count_by_length` method
  - [x] Implement `statistics` method (returns hash of stats)
  - [x] Implement `to_trie` method (convert to Trie)
  - [x] Implement `each_word` and `each_with_index` enumerators
  - [x] Add `from_file(path)` class method
  - [x] Add `from_trie(trie)` class method
  - [x] Write RSpec tests

**Key OOP Improvements over Spylls:**
- Domain model with behavior instead of simple hash wrapper
- Multiple index types (exact, lowercase, prefix, suffix)
- Rich query methods returning arrays, not just indices
- Statistics method provides dictionary insights
- Can convert itself to other data structures (Trie)
- Enumerable interface for iteration

## Phase 2: Dictionary Backends

### 2.1 Base Dictionary Interface

- [ ] `dictionary/base.rb`
  - [ ] Implement `Kotoshu::Dictionary::Base` abstract class
  - [ ] Define `initialize(language_code, locale:)`
  - [ ] Define abstract `lookup(word)` method
  - [ ] Define abstract `suggest(word, max_suggestions:)` method
  - [ ] Define abstract `add_word(word, flags:)` method
  - [ ] Define abstract `remove_word(word)` method
  - [ ] Write RSpec tests for interface contract

### 2.2 UnixWords Dictionary (Start with Simplest)

- [ ] `dictionary/unix_words.rb`
  - [ ] Implement `Kotoshu::Dictionary::UnixWords` class
  - [ ] Implement `initialize(path, language_code:, locale:)`
  - [ ] Implement `detect_system_dictionary` method
  - [ ] Implement `load_words` method (load into Set)
  - [ ] Implement `lookup(word)` method (case-insensitive)
  - [ ] Implement `suggest(word, max_suggestions:)` method
  - [ ] Write RSpec tests
  - [ ] Add fixture file in `spec/fixtures/dictionaries/unix_words/`

### 2.3 PlainText Dictionary

- [ ] `dictionary/plain_text.rb`
  - [ ] Implement `Kotoshu::Dictionary::PlainText` class
  - [ ] Implement `initialize(path, language_code:, locale:)`
  - [ ] Implement `load_words` method (handle comments, empty lines)
  - [ ] Implement `lookup(word)` method
  - [ ] Implement `suggest(word, max_suggestions:)` method
  - [ ] Write RSpec tests
  - [ ] Add fixture files in `spec/fixtures/dictionaries/plain_text/`

### 2.4 Custom Dictionary

- [ ] `dictionary/custom.rb`
  - [ ] Implement `Kotoshu::Dictionary::Custom` class
  - [ ] Implement `initialize(words:, language_code:, locale:)`
  - [ ] Implement `lookup(word)` method
  - [ ] Implement `add_word(word, flags:)` method
  - [ ] Implement `remove_word(word)` method
  - [ ] Implement `suggest(word, max_suggestions:)` method
  - [ ] Write RSpec tests

### 2.5 Hunspell Dictionary

- [ ] `dictionary/hunspell.rb`
  - [ ] Implement `Kotoshu::Dictionary::Hunspell` class
  - [ ] Implement `initialize(dic_path, aff_path, language_code:, locale:)`
  - [ ] Implement `load_dic_file(path)` method
    - [ ] Parse word count from first line
    - [ ] Parse words with optional flags
    - [ ] Populate `@word_index` hash
  - [ ] Implement `load_aff_file(path)` method
    - [ ] Parse SET (encoding)
    - [ ] Parse TRY (suggestion characters)
    - [ ] Parse PFX (prefix rules)
    - [ ] Parse SFX (suffix rules)
    - [ ] Populate `@affix_rules` hash
  - [ ] Implement `lookup(word)` method
    - [ ] Direct lookup in word_index
    - [ ] Affix variant generation
  - [ ] Implement `word_variants(word)` method
  - [ ] Write RSpec tests
  - [ ] Add fixture files in `spec/fixtures/dictionaries/hunspell/`
    - [ ] `test.dic`
    - [ ] `test.aff`

### 2.6 CSpell Dictionary

- [ ] `dictionary/cspell.rb`
  - [ ] Implement `Kotoshu::Dictionary::CSpell` class
  - [ ] Implement `initialize(path, language_code:, locale:)`
  - [ ] Implement `load_trie_file(path)` method (for .trie files)
  - [ ] Implement `load_text_file(path)` method (for .txt files)
  - [ ] Implement `lookup(word)` method (using trie)
  - [ ] Implement `suggest(word, max_suggestions:)` method (using trie walk)
  - [ ] Write RSpec tests
  - [ ] Add fixture files in `spec/fixtures/dictionaries/cspell/`
    - [ ] `test.txt`
    - [ ] `test.trie`

### 2.7 Dictionary Repository

- [ ] `dictionary/repository.rb`
  - [ ] Implement `Kotoshu::Dictionary::Repository` class
  - [ ] Implement `register(key, dictionary)` method
  - [ ] Implement `get(key)` method
  - [ ] Implement `clear` method
  - [ ] Write RSpec tests

## Phase 3: Suggestion Algorithms ✅ PARTIALLY COMPLETED

**NOTE: This section uses Strategy Pattern and is MORE OOP than Spylls.**

### 3.1 Context Object ✅ COMPLETED

- [x] `suggestions/context.rb` ✅
  - [x] Implement `Kotoshu::Suggestions::Context` class
  - [x] Add attributes: `word`, `dictionary`, `max_results`, `options`
  - [x] Add `option(key, default)` method
  - [x] Add `has_option?(key)` method
  - [x] Add `to_h` method
  - [x] Make context immutable
  - [x] Write RSpec tests

### 3.2 Suggestion Model ✅ COMPLETED

- [x] `suggestions/suggestion.rb` ✅
  - [x] Implement `Kotoshu::Suggestions::Suggestion` class
  - [x] Add attributes: `word`, `distance`, `confidence`, `source`, `metadata`
  - [x] Add `high_confidence?` predicate method
  - [x] Add `low_confidence?` predicate method
  - [x] Add `combined_score(distance_weight:, confidence_weight:)` method
  - [x] Add `same_word?(other)` method (case-insensitive)
  - [x] Add `from_source?(source)` method
  - [x] Implement `<=>` for sorting
  - [x] Implement `==` and `eql?` for equality
  - [x] Implement `hash` method for hash keys
  - [x] Add `to_h` method
  - [x] Add `as_json` method
  - [x] Add `from_word(word, source:)` class method
  - [x] Make suggestion immutable (frozen)
  - [x] Write RSpec tests

**Key OOP Improvements over Spylls:**
- Rich behavior methods instead of plain string return values
- Self-comparable for sorting by combined score
- Case-insensitive word matching built-in
- Source tracking for multi-strategy scenarios

### 3.3 Suggestion Set ✅ COMPLETED

- [x] `suggestions/suggestion_set.rb` ✅
  - [x] Implement `Kotoshu::Suggestions::SuggestionSet` class
  - [x] Include Enumerable module
  - [x] Add `add(suggestion)` method with chaining
  - [x] Add `concat(suggestions)` method
  - [x] Add `merge!(other)` method
  - [x] Add `from_source(source)` filter method
  - [x] Add `high_confidence` filter method
  - [x] Add `low_confidence` filter method
  - [x] Add `within_distance(min:, max:)` filter method
  - [x] Add `include?(word)` / `has_word?` method
  - [x] Add `find_word(word)` method
  - [x] Add `top(n)` method for best N suggestions
  - [x] Add `first` and `last` methods
  - [x] Add `unique` method (deduplicate by word)
  - [x] Add `to_words` method (convert to array of words)
  - [x] Add `to_a` / `as_json` methods
  - [x] Add `empty?`, `size`, `count`, `length` methods
  - [x] Implement `each` iterator
  - [x] Add `empty(max_size:)` class method
  - [x] Add `from_words(words, source:, max_size:)` class method
  - [x] Auto-sort by combined score and limit to max_size
  - [x] Write RSpec tests

**Key OOP Improvements over Spylls:**
- Enumerable collection instead of simple iterator
- Rich query methods (filter, search, transform)
- Automatic sorting and deduplication
- Max size limiting for memory efficiency

### 3.4 Base Strategy Pattern ✅ COMPLETED

- [x] `suggestions/strategies/base_strategy.rb` ✅
  - [x] Implement `Kotoshu::Suggestions::Strategies::BaseStrategy` abstract class
  - [x] Add attributes: `name`, `config`
  - [x] Define abstract `generate(context)` method returning `SuggestionSet`
  - [x] Add `enabled?` method (checks config)
  - [x] Add `priority` method (for pipeline ordering)
  - [x] Add `max_results` method
  - [x] Add `handles?(context)` predicate method
  - [x] Add `after_initialize` hook for subclasses
  - [x] Add `get_config(key, default)` method
  - [x] Add `has_config?(key)` method
  - [x] Add `create_suggestion(word, distance:, confidence:)` helper
  - [x] Add `create_suggestion_set(words, distances:)` helper
  - [x] Add `calculate_confidence(distance)` protected method
  - [x] Write RSpec tests

**Key OOP Improvements over Spylls:**
- Each algorithm is a proper object with state and config
- Strategy Pattern instead of procedural functions
- Hooks for extensibility (`after_initialize`, `handles?`)
- Helper methods for consistent suggestion creation

### 3.5 Composite Strategy (Pipeline) ✅ COMPLETED

- [x] `suggestions/strategies/composite_strategy.rb` ✅
  - [x] Implement `Kotoshu::Suggestions::Strategies::CompositeStrategy` class
  - [x] Inherit from `BaseStrategy`
  - [x] Add `strategies` array
  - [x] Add `add(strategy)` method with chaining
  - [x] Add `remove(strategy)` method
  - [x] Add `clear` method
  - [x] Add `applicable_strategies(context)` method
  - [x] Implement `generate(context)` to delegate to all strategies
  - [x] Implement `handles?(context)` to check if any strategy handles it
  -x] Add `size`, `count`, `any?` methods
  - [x] Add `each_strategy` iterator
  - [x] Add `sort_by_priority!` method
  - [x] Add `with_defaults` class method
  - [x] Write RSpec tests

**Key OOP Improvements over Spylls:**
- Composite Pattern for chaining multiple strategies
- Strategies are proper objects that can be added/removed/reordered
- Each strategy can be enabled/disabled via config
- Priority-based ordering
- Extensible pipeline architecture

### 3.6 Edit Distance Strategy ✅ COMPLETED

- [x] `suggestions/strategies/edit_distance_strategy.rb` ✅
  - [x] Implement `Kotoshu::Suggestions::Strategies::EditDistanceStrategy` class
  - [x] Inherit from `BaseStrategy`
  - [x] Add `max_distance` config option
  - [x] Implement `generate(context)` method
  - [x] Implement `handles?(context)` method (skip if word in dictionary)
  - [x] Implement Levenshtein distance algorithm
  - [x] Add `dictionary_words(context)` private method (handles multiple types)
  - [x] Add `dictionary_lookup(context, word)` private method
  - [x] Add `edit_distance(str1, str2)` private method
  - [x] Add `edit_distance_with_threshold(str1, str2, threshold)` private method
  - [x] Return `SuggestionSet` with distance-based confidence
  - [x] Write RSpec tests

**Key OOP Improvements over Spylls:**
- Strategy object with configurable max distance
- Handles multiple dictionary types (IndexedDictionary, Hash, Array)
- Suggestion objects with distance and confidence
- Returns rich `SuggestionSet` instead of plain strings

### 3.7 Phonetic Algorithm

- [ ] `suggestions/strategies/phonetic_strategy.rb`
  - [ ] Implement `Kotoshu::Suggestions::Strategies::PhoneticStrategy` class
  - [ ] Inherit from `BaseStrategy`
  - [ ] Add `algorithm` config option (default: :soundex)
  - [ ] Implement `generate(context)` method
  - [ ] Implement Soundex algorithm
  - [ ] Implement Metaphone algorithm (optional)
  - [ ] Add `phonetic_code(word)` private method
  - [ ] Add `phonetic_match?(word1, word2)` private method
  - [ ] Write RSpec tests

### 3.8 Keyboard Proximity Algorithm (Optional)

- [ ] `suggestions/strategies/keyboard_proximity_strategy.rb`
  - [ ] Implement `Kotoshu::Suggestions::Strategies::KeyboardProximityStrategy` class
  - [ ] Inherit from `BaseStrategy`
  - [ ] Define QWERTY keyboard layout as data
  - [ ] Implement `generate(context)` method
  - [ ] Implement `neighbors(char)` method
  - [ ] Implement `keyboard_variants(word)` method
  - [ ] Write RSpec tests

### 3.9 N-Gram Algorithm (Optional)

- [ ] `suggestions/strategies/ngram_strategy.rb`
  - [ ] Implement `Kotoshu::Suggestions::Strategies::NgramStrategy` class
  - [ ] Inherit from `BaseStrategy`
  - [ ] Add `n` config option (n-gram size, default: 3)
  - [ ] Implement `generate(context)` method
  - [ ] Implement `ngram_score(word1, word2)` method
  - [ ] Implement `extract_ngrams(word, n)` method
  - [ ] Write RSpec tests
  - [ ] Implement `generate(word, max_results:)` method
  - [ ] Write RSpec tests

- [ ] `suggestions/algorithms/trie_walk.rb`
  - [ ] Implement trie walking algorithm
  - [ ] Implement `generate(word, max_results:)` method
  - [ ] Write RSpec tests

### 3.5 Suggestion Generator

- [ ] `suggestions/generator.rb`
  - [ ] Implement `Kotoshu::Suggestions::Generator` class
  - [ ] Implement `initialize(dictionary, algorithms:)`
  - [ ] Implement `generate(word, max_suggestions:)` method
  - [ ] Implement `default_algorithms` method
  - [ ] Write RSpec tests

## Phase 4: Application Layer

### 4.1 Configuration

- [ ] `configuration.rb`
  - [ ] Implement `Kotoshu::Configuration` class
  - [ ] Add attributes: `dictionary_path`, `dictionary_type`, `language`,
        `max_suggestions`, `case_sensitive`, `verbose`
  - [ ] Implement `dictionary` method (lazy loads dictionary)
  - [ ] Implement `load_dictionary` method
  - [ ] Write RSpec tests

### 4.2 Main Spellchecker Facade

- [ ] `spellchecker.rb`
  - [ ] Implement `Kotoshu::Spellchecker` class
  - [ ] Implement `initialize(dictionary:)`
  - [ ] Implement `correct?(word)` method
  - [ ] Implement `suggest(word, max_suggestions:)` method
  - [ ] Implement `check(text)` method
    - [ ] Implement text tokenization
    - [ ] Check each word
    - [ ] Return DocumentResult
  - [ ] Implement `check_file(path)` method
    - [ ] Read file contents
    - [ ] Call `check(text)`
    - [ ] Add file path to result
  - [ ] Implement `check_directory(path)` method
    - [ ] Find all text files
    - [ ] Check each file
    - [ ] Return array of DocumentResult
  - [ ] Write RSpec tests
  - [ ] Add fixture files in `spec/fixtures/documents/`

### 4.3 Public Module API

- [ ] Update `lib/kotoshu.rb`
  - [ ] Add `configure` method
  - [ ] Add `configuration` method
  - [ ] Add `spellchecker` method (lazy init)
  - [ ] Add `correct?(word)` convenience method
  - [ ] Add `check(text, options:)` method
  - [ ] Add `check_file(path)` convenience method
  - [ ] Add `check_files(paths)` method
  - [ ] Add `suggest(word, options:)` convenience method
  - [ ] Write RSpec tests for module API

### 4.4 Registry

- [ ] `registry.rb`
  - [ ] Implement `Kotoshu.register_dictionary_type(type, klass)` method
  - [ ] Implement `Kotoshu.register_suggestion_algorithm(name, klass)` method
  - [ ] Implement `Kotoshu::Dictionary.register_type(type, klass)` method
  - [ ] Implement `Kotoshu::Dictionary.load(type, *args)` method
  - [ ] Implement `Kotoshu::Suggestions.register_algorithm(name, klass)` method
  - [ ] Write RSpec tests
  - [ ] Add example of custom registration in documentation

## Phase 5: CLI Adapter

### 5.1 CLI Main Class

- [ ] `cli/cli.rb`
  - [ ] Implement `Kotoshu::Cli` class (inherits from Thor)
  - [ ] Add class options: `verbose`, `dictionary`, `language`, `output`
  - [ ] Implement `check TEXT|FILE` command
  - [ ] Implement `version` command
  - [ ] Implement `help` command (default Thor)
  - [ ] Write RSpec tests

### 5.2 Check Command

- [ ] `cli/commands/check_command.rb`
  - [ ] Implement `Kotoshu::Commands::CheckCommand` class (inherits from `Kotoshu::Cli`)
  - [ ] Implement `initialize(options = {})` method (just passes options)
  - [ ] Implement `run(target)` method containing command logic
    - [ ] Configure from options
    - [ ] Determine if target is file or text
    - [ ] Run check
    - [ ] Format output
    - [ ] Set exit code
  - [ ] Implement `configure_from_options` method
  - [ ] Implement `format_as_text(result)` method
  - [ ] Implement `format_as_json(result)` method
  - [ ] Write RSpec tests using `let` (no mocks/stubs)

### 5.3 Dictionary Command

- [ ] `cli/commands/dict_command.rb`
  - [ ] Implement `Kotoshu::Commands::DictCommand` class (inherits from `Kotoshu::Cli`)
  - [ ] Implement `initialize(options = {})` method
  - [ ] Implement `list` subcommand
  - [ ] Implement `info id` subcommand
  - [ ] Write RSpec tests using `let` (no mocks/stubs)

### 5.4 Version Command

- [ ] `cli/commands/version_command.rb`
  - [ ] Implement `Kotoshu::Commands::VersionCommand` class (inherits from `Kotoshu::Cli`)
  - [ ] Implement `initialize(options = {})` method
  - [ ] Implement `run` method
  - [ ] Write RSpec tests using `let` (no mocks/stubs)

### 5.5 CLI Executable

- [ ] Create `exe/kotoshu` executable
  ```ruby
  #!/usr/bin/env ruby
  require "kotoshu/cli"
  Kotoshu::Cli.start(ARGV)
  ```
  - [ ] Make executable (`chmod +x exe/kotoshu`)
  - [ ] Test manual CLI usage

## Phase 6: Testing & Quality

### 6.1 Unit Tests (Ribose Standards)

- [ ] Complete all RSpec tests from above phases
- [ ] Ensure all tests pass
- [ ] Achieve >90% code coverage

**Important Testing Standards (from Ribose rules):**
- [ ] Use `let` to define variables used in multiple places
- [ ] Do not use any mock or stub methods
- [ ] Tests must be minimal and focused
- [ ] Tests must be MECE (Mutually Exclusive, Collectively Exhaustive)
- [ ] Each test should only test one specific behavior or functionality
- [ ] Place test fixtures in `spec/fixtures/` directory
- [ ] Use `let(:fixture)` to load fixture files

### 6.2 Integration Tests

- [ ] `spec/integration/spellchecker_spec.rb`
  - [ ] Test full spellchecker with real dictionaries
  - [ ] Test configuration loading
  - [ ] Test multiple dictionary types
  - [ ] Use `let` for test data setup

- [ ] `spec/integration/cli_spec.rb`
  - [ ] Test CLI commands end-to-end
  - [ ] Test exit codes
  - [ ] Test output formats
  - [ ] Use `let` for command setup

### 6.3 Fixtures

- [ ] `spec/fixtures/dictionaries/hunspell/`
  - [ ] `test.dic` (10-20 words)
  - [ ] `test.aff` (simple affix rules)

- [ ] `spec/fixtures/dictionaries/cspell/`
  - [ ] `test.txt` (10-20 words)
  - [ ] `test.trie` (if implementing trie format)

- [ ] `spec/fixtures/dictionaries/plain_text/`
  - [ ] `simple.txt` (10-20 words)

- [ ] `spec/fixtures/dictionaries/unix_words/`
  - [ ] `test_words.txt` (10-20 words)

- [ ] `spec/fixtures/documents/`
  - [ ] `simple.txt` (with errors)
  - [ ] `correct.txt` (no errors)
  - [ ] `multi_error.txt` (multiple errors)

### 6.4 Linting

- [ ] Run RuboCop on entire codebase
  ```bash
  bundle exec rubocop
  ```
- [ ] Fix all RuboCop violations
  ```bash
  bundle exec rubocop -A
  ```
- [ ] Ensure no offenses remain

### 6.5 Type Signatures

- [ ] Update `sig/kotoshu.rbs`
  - [ ] Add module definition
  - [ ] Add all public class definitions
  - [ ] Add method signatures for public APIs

- [ ] Create RBS files for:
  - [ ] `sig/kotoshu/core/models/word.rbs`
  - [ ] `sig/kotoshu/core/models/result/word_result.rbs`
  - [ ] `sig/kotoshu/dictionary/base.rbs`
  - [ ] `sig/kotoshu/spellchecker.rbs`

## Phase 7: Documentation

### 7.1 README.adoc (AsciiDoc Format - Ribose Standards)

**AsciiDoc Format Requirements:**
- [ ] Use sentence-case for all headings
- [ ] Separate lists from previous content with blank line
- [ ] Ordered list items start with `. `, second level `.. ` (flush left)
- [ ] Unordered list items start with `* `, second level `** ` (flush left)
- [ ] Examples wrapped with `[example]\n====` and `====`
- [ ] Source code wrapped with `[source,{lang}]\n----` and `----`
- [ ] No hanging paragraphs (use "General" sub-clause if needed)
- [ ] Line wrap at 80 characters (except cross-references and formulas)
- [ ] Be MECE (Mutually Exclusive, Collectively Exhaustive)

**Required Sections:**
- [ ] Badges (RubyGems Version, License, Build, Dependent tests)
- [ ] Purpose section (brief description)
- [ ] Features section (list linking to detailed sections)
- [ ] Architecture diagram (data structure and dataflow)
- [ ] Installation instructions
- [ ] Individual features with:
  - [ ] Heading with anchor link `[[feature-name]]`
  - [ ] Description of purpose and implementation
  - [ ] Code syntax definition with callout annotations
  - [ ] Legend describing syntax elements
  - [ ] Examples with code blocks and explanations
- [ ] Contributing guidelines
- [ ] License information

- [ ] Update README.adoc with:
  - [ ] Purpose section
  - [ ] Features section (link to architecture doc)
  - [ ] Architecture diagram
  - [ ] Installation instructions
  - [ ] Usage examples:
    - [ ] Ruby API examples
    - [ ] CLI examples
  - [ ] Configuration guide
  - [ ] Contributing guidelines
  - [ ] License information

### 7.2 Code Documentation

- [ ] Add YARD comments to all public classes
- [ ] Add YARD comments to all public methods
- [ ] Run `yard doc` to generate documentation
- [ ] Ensure no undocumented warnings

### 7.3 Examples

- [ ] Create `examples/` directory
- [ ] `examples/basic_usage.rb` - Basic spell checking
- [ ] `examples/custom_dictionary.rb` - Using custom dictionary
- [ ] `examples/suggestions.rb` - Getting suggestions
- [ ] `examples/batch_check.rb` - Checking multiple files

## Phase 8: Release Preparation

### 8.1 Version Bump

- [ ] Update `lib/kotoshu/version.rb` to 1.0.0
- [ ] Update gemspec with final details
- [ ] Update CHANGELOG.md

### 8.2 Build & Test

- [ ] Build gem: `gem build kotoshu.gemspec`
- [ ] Install locally: `gem install kotoshu-1.0.0.gem`
- [ ] Test CLI: `kotoshu check "test word"`
- [ ] Test Ruby API in IRB
- [ ] Run full test suite: `bundle exec rake`

### 8.3 Git & Release

- [ ] Review all changes
- [ ] Create git commit: `git add . && git commit`
- [ ] Tag release: `git tag v1.0.0`
- [ ] (Do not push - per your rules)

## Future Phases (Post 1.0)

### HTTP API (kotoshu-server gem)

- [ ] Create separate `kotoshu-server` gem
- [ ] Implement Sinatra application
- [ ] Add endpoints:
  - [ ] `POST /v1/check`
  - [ ] `POST /v1/check/file`
  - [ ] `GET /v1/dictionaries`
  - [ ] `POST /v1/dictionaries/:id/check`
- [ ] Add JSON request/response handling
- [ ] Add error handling with HTTP status codes
- [ ] Add standalone server executable
- [ ] Write tests
- [ ] Add documentation

### Advanced Features

- [ ] Language detection
- [ ] Grammar checking rules (LanguageTool-style)
- [ ] Multi-language support in single document
- [ ] Performance caching
- [ ] Thread safety for concurrent access
- [ ] Configuration file support (.kotoshurc.yml)

---

## Summary Checklist

### Phase 0: Gem Setup
- [x] 0.1 Gem Structure
- [x] 0.2 Gemfile Dependencies
- [x] 0.3 Rakefile
- [x] 0.4 RuboCop Configuration

### Phase 1: Foundation
- [ ] 1.1 Project Structure Setup
- [ ] 1.2 Core Models (Word, AffixRule, Suggestion)
- [ ] 1.3 Result Objects (WordResult, DocumentResult)
- [ ] 1.4 Exception Hierarchy
- [x] 1.5 Trie Data Structure ✅ COMPLETED
- [x] 1.6 IndexedDictionary ✅ COMPLETED

### Phase 2: Dictionary Backends
- [ ] 2.1 Base Dictionary Interface
- [ ] 2.2 UnixWords Dictionary
- [ ] 2.3 PlainText Dictionary
- [ ] 2.4 Custom Dictionary
- [ ] 2.5 Hunspell Dictionary
- [ ] 2.6 CSpell Dictionary
- [ ] 2.7 Dictionary Repository

### Phase 3: Suggestion Algorithms
- [x] 3.1 Context Object ✅ COMPLETED
- [x] 3.2 Suggestion Model ✅ COMPLETED
- [x] 3.3 Suggestion Set ✅ COMPLETED
- [x] 3.4 Base Strategy Pattern ✅ COMPLETED
- [x] 3.5 Composite Strategy (Pipeline) ✅ COMPLETED
- [x] 3.6 Edit Distance Strategy ✅ COMPLETED
- [ ] 3.7 Phonetic Algorithm
- [ ] 3.8 Keyboard Proximity Algorithm (optional)
- [ ] 3.9 N-Gram Algorithm (optional)
- [ ] 3.10 Suggestion Generator

### Phase 4: Application Layer
- [ ] 4.1 Configuration
- [ ] 4.2 Main Spellchecker Facade
- [ ] 4.3 Public Module API
- [ ] 4.4 Registry

### Phase 5: CLI Adapter
- [ ] 5.1 CLI Main Class
- [ ] 5.2 Check Command
- [ ] 5.3 Dictionary Command
- [ ] 5.4 Version Command
- [ ] 5.5 CLI Executable

### Phase 6: Testing & Quality
- [ ] 6.1 Unit Tests (Ribose Standards)
- [ ] 6.2 Integration Tests
- [ ] 6.3 Fixtures
- [ ] 6.4 Linting (RuboCop)
- [ ] 6.5 Type Signatures (RBS)

### Phase 7: Documentation
- [ ] 7.1 README.adoc ✅ COMPLETED
- [ ] 7.2 Code Documentation (YARD)
- [ ] 7.3 Examples

### Phase 8: Release Preparation
- [ ] 8.1 Version Bump
- [ ] 8.2 Build & Test
- [ ] 8.3 Git & Release

---

## Notes

- Each checkbox can be marked with `[x]` when complete
- Use partial checklists like `[~]` for in-progress items
- Update this document as implementation progresses
- Add new items discovered during implementation
- Remove items that are deemed unnecessary

## Current Status

**Phase**: Foundation + Suggestion Algorithms (Phases 1 & 3)
**Last Updated**: 2025-01-29
**Percent Complete**: 25% (Core OOP components implemented, dictionaries and CLI pending)

**Completed:**
- ✅ Gem setup following Ribose standards
- ✅ README.adoc with proper AsciiDoc format
- ✅ Architecture documentation (KOTOSHU_ARCHITECTURE.md)
- ✅ Implementation plan with checklist (KOTOSHU_FULL_PLAN.md)
- ✅ **Trie data structure** (Node, Trie, Builder) - MORE OOP than Spylls
- ✅ **IndexedDictionary** - Domain model with behavior, not just hash wrapper
- ✅ **Suggestion architecture** - Strategy Pattern, not procedural functions
  - ✅ Context object for pipeline state
  - ✅ Suggestion model with behavior methods
  - ✅ SuggestionSet with Enumerable interface
  - ✅ BaseStrategy abstract class
  - ✅ CompositeStrategy for pipelines
  - ✅ EditDistanceStrategy implementation
- ✅ Dictionary files copied to `dictionaries/unix_words/`
- ✅ Gem built and installed locally (kotoshu-0.1.0.gem)

**Next Steps:**
- Complete Phase 1: Core Models (Word, AffixRule, Result objects)
- Complete Phase 2: Dictionary backends (UnixWords, PlainText, Custom, Hunspell, CSpell)
- Complete Phase 3.7-3.10: Remaining suggestion algorithms
- Complete Phase 4: Application Layer (Configuration, Spellchecker, API)
- Complete Phase 5: CLI Adapter
- Complete Phase 6: RSpec tests using `let`, no mocks/stubs

**Key OOP Achievements:**
- Strategy Pattern instead of procedural functions (Spylls uses functions)
- Rich domain models with behavior (Spylls uses dataclasses)
- Composite Pattern for pipelines (Spylls has procedural coordination)
- Enumerable collections instead of iterators (Spylls uses generators)
- Immutable value objects with behavior methods
- Builder pattern for construction
- Configurable strategy objects with state
