# Kotoshu OOP Architecture Improvements

**Status**: Advanced Architectural Analysis
**Last Updated**: 2025-01-29
**Analysis**: ULTRATHINK Deep Review

## Executive Summary

This document outlines 15 advanced OOP and model-driven architecture improvements beyond the initial solidification plan. These patterns address deeper architectural concerns for maximum flexibility, maintainability, and extensibility.

---

## 1. Rich Domain Models (Avoid Anemic Models)

**Problem**: Models with data but no behavior (anemic domain model)

**Solution**: Put behavior ON models, not in services

```ruby
# BAD: Anemic model
class Word
  attr_reader :text, :flags
  # No behavior
end

# GOOD: Rich domain model
class Word
  def noun?
    @flags.include?(NounFlag)
  end

  def verb?
    @flags.include?(VerbFlag)
  end

  def can_stand_alone?
    true
  end

  def forbidden?
    false
  end

  def same_part_of_speech?(other)
    @flags.intersect(other.flags).any? { |f| f.part_of_speech? }
  end
end
```

**Impact**: Review all models to ensure domain logic lives on models, not in services

---

## 2. Double Dispatch Pattern

**Problem**: Type-checking in strategies (procedural)

**Solution**: Use polymorphism on BOTH sides

```ruby
# Word initiates, Dictionary responds
class Word
  def suggestions_from(dictionary)
    dictionary.suggestions_for(self) # Double dispatch
  end
end

class HunspellDictionary
  def suggestions_for(word)
    # Hunspell-specific logic
  end
end

class CSpellDictionary
  def suggestions_for(word)
    # CSpell-specific logic
  end
end
```

**Impact**: Eliminates type-checking, true polymorphism

---

## 3. Aggregate Pattern (DDD)

**Problem**: Client code must maintain consistency across related objects

**Solution**: Aggregate root manages consistency boundary

```ruby
class Dictionary
  def add_word_with_affixes(word_text, affix_flags)
    word = Word.new(word_text, affix_flags)

    # Aggregate root ensures consistency
    @words.add(word)
    @affix_index.update(word)
    @word_count += 1

    word # Returns aggregate member
  end

  def word_variants(word)
    # Aggregate root knows how to generate variants
    @affixes.applicable_to(word).map { |a| a.apply_to(word) }
  end
end
```

**Impact**:
- Dictionary is aggregate root for Word, AffixRule
- RuleSet is aggregate root for Rule objects
- Trie is aggregate root for TrieNode objects

---

## 4. Repository Pattern

**Problem**: Data access mixed with domain logic

**Solution**: Separate repository (data access) from factory (construction)

```ruby
# Repository: Pure data access
class HunspellDictionaryRepository
  def load(dic_path, aff_path)
    { words: load_dic_file(dic_path), affix_data: load_aff_file(aff_path) }
  end
end

# Factory: Constructs domain models
class HunspellDictionaryFactory
  def build(repository_data)
    words = repository_data[:words].map { |w| Word.from_dic_line(w) }
    affixes = parse_affix_data(repository_data[:affix_data])
    Dictionary.new(words: words, affixes: affixes)
  end
end

# Domain Model: Pure business logic
class Dictionary
  def initialize(words:, affixes:)
    @words = words
    @affixes = affixes
  end

  def lookup(word)
    @words.include?(word) || has_affix_variant?(word)
  end
end
```

**Impact**: Clear separation of data access, construction, and business logic

---

## 5. Domain Events Pattern

**Problem**: Tight coupling between components

**Solution**: Publish events, subscribe to changes

```ruby
# Domain event
class WordCheckedEvent
  attr_reader :word, :result, :timestamp

  def initialize(word, result)
    @word = word
    @result = result
    @timestamp = Time.now
  end
end

# Event bus
class EventBus
  def subscribe(event_class, &handler)
    @subscribers[event_class] << handler
  end

  def publish(event)
    @subscribers[event.class].each { |handler| handler.call(event) }
  end
end

# Event publisher
class Spellchecker
  def check_word(word)
    result = perform_check(word)
    @event_bus.publish(WordCheckedEvent.new(word, result))
    result
  end
end

# Event handler
class SuggestionEventHandler
  def subscribe_to(event_bus)
    event_bus.subscribe(WordCheckedEvent) do |event|
      if event.result.incorrect?
        suggestions = generate_suggestions(event.word)
        event.result.update_suggestions(suggestions)
      end
    end
  end
end
```

**Impact**:
- Decouples Spellchecker from SuggestionGenerator
- Enables audit logging, metrics, caching via event handlers
- Natural extension point for new features

---

## 6. Specification Pattern

**Problem**: Business rules scattered across conditionals

**Solution**: Encapsulate rules in composable specifications

```ruby
class Specification
  def and(other)
    AndSpecification.new(self, other)
  end

  def or(other)
    OrSpecification.new(self, other)
  end

  def not
    NotSpecification.new(self)
  end
end

class MinimumPartsSpecification < Specification
  def initialize(min_parts)
    @min_parts = min_parts
  end

  def satisfied_by?(parts)
    parts.size >= @min_parts
  end
end

# Compose complex specifications
class CompoundValidator
  def specification
    MinimumPartsSpecification.new(@config.compound_min)
      .and(MinimumPartLengthSpecification.new(3))
      .and(AllPartsInDictionarySpecification.new(@dictionary))
      .and(CompoundRuleMatchesSpecification.new(@compound_rules))
  end
end
```

**Impact**: Encapsulates business rules, makes them composable and testable

---

## 7. Visitor Pattern

**Problem**: Traversal logic embedded in client code

**Solution**: Separate traversal from element structure

```ruby
# Visitor interface
class TrieVisitor
  def visit_trie(trie)
  end

  def visit_node(node)
  end
end

# Element accepts visitor
class TrieNode
  def accept(visitor)
    visitor.visit_node(self)
    @children.each { |child| child.accept(visitor) }
  end
end

# Concrete visitors
class WordCountVisitor < TrieVisitor
  attr_reader :count

  def initialize
    @count = 0
  end

  def visit_node(node)
    @count += 1 if node.word_end?
  end
end

class SerializationVisitor < TrieVisitor
  attr_reader :serialized_data

  def initialize
    @serialized_data = []
  end

  def visit_node(node)
    @serialized_data << { char: node.character, word_end: node.word_end? }
  end
end
```

**Impact**: Add operations without modifying elements, clean separation of concerns

---

## 8. Command Pattern

**Problem**: Imperative method calls, can't undo/redo/queue

**Solution**: Encapsulate operations as objects

```ruby
class CheckTextCommand < SpellcheckCommand
  def execute
    @spellchecker.check(@text)
  end
end

class CheckAndSuggestCommand < SpellcheckCommand
  def execute
    result = @check_command.execute
    if result.incorrect?
      suggestions = @suggest_command.execute
      result.with_suggestions(suggestions)
    else
      result
    end
  end
end

class SpellcheckInvoker
  def initialize(spellchecker)
    @spellchecker = spellchecker
    @history = []
  end

  def execute(command)
    result = command.execute
    @history << command
    result
  end

  def undo_last
    @history.pop&.undo
  end
end
```

**Impact**: Undo/redo support, operation queuing, audit trail

---

## 9. Fluent Builder Pattern

**Problem**: Constructor clutter with many parameters

**Solution**: Fluent interface for object construction

```ruby
class DictionaryBuilder
  def hunspell(dic_path, aff_path)
    @config[:type] = :hunspell
    @config[:dic_path] = dic_path
    @config[:aff_path] = aff_path
    self
  end

  def language(code)
    @config[:language_code] = code
    self
  end

  def case_sensitive(value = true)
    @config[:case_sensitive] = value
    self
  end

  def with_cache(cache_type)
    @config[:cache] = cache_type
    self
  end

  def build
    validate_config
    DictionaryFactory.create(@config)
  end
end

# Usage
dictionary = DictionaryBuilder.new
  .hunspell("/path/to/file.dic", "/path/to/file.aff")
  .language("en-US")
  .case_sensitive
  .with_cache(:lru)
  .build
```

**Impact**: Readable, flexible construction with validation

---

## 10. Correct Strategy Pattern Usage

**Problem**: "Strategy pattern abuse" - class for every algorithm

**Solution**: Strategy for pluggable BEHAVIORS, not algorithms

```ruby
# True strategies: Pluggable behaviors
class SuggestionTrigger
  def should_generate_suggestions?(word_result)
  end
end

class AlwaysGenerateSuggestions < SuggestionTrigger
  def should_generate_suggestions?(word_result)
    true
  end
end

class OnlyGenerateForRareWords < SuggestionTrigger
  def should_generate_suggestions?(word_result)
    @frequency_dictionary.rare?(word_result.word)
  end
end

# Algorithms are VALUE OBJECT methods, not strategies
class Word
  def edit_distance_to(other)
    EditDistance.calculate(@text, other.text)
  end

  def phonetic_similarity_to(other)
    PhoneticCode.similarity(@text, other.text)
  end
end
```

**Impact**: Remove algorithm-as-strategy classes, use VALUE objects instead

---

## 11. Composite Pattern for Collections

**Problem**: Collections treated uniformly without type-specific behavior

**Solution**: Component interface with leaf and composite

```ruby
# Component interface
class Suggestion
  def add(other)
  end

  def display
  end
end

# Leaf
class SimpleSuggestion < Suggestion
  attr_reader :text, :confidence, :source

  def display
    "#{@text} (#{@confidence.round(2)})"
  end
end

# Composite
class CompositeSuggestion < Suggestion
  def initialize(suggestions = [])
    @suggestions = suggestions
  end

  def add(suggestion)
    @suggestions << suggestion
    self
  end

  def map(&block)
    CompositeSuggestion.new(@suggestions.map(&block))
  end

  def filter(&block)
    CompositeSuggestion.new(@suggestions.select(&block))
  end

  def display
    @suggestions.map(&:display).join(" | ")
  end
end
```

**Impact**: Uniform treatment of single and composite suggestions

---

## 12. Adapter Pattern for External Systems

**Problem**: Tight coupling to file system, HTTP APIs

**Solution**: Adapter interface for external integrations

```ruby
class DictionaryLoader
  def load_dic_data
  end

  def load_aff_data
  end
end

class FileSystemDictionaryLoader < DictionaryLoader
  def initialize(dic_path, aff_path)
    @dic_path = dic_path
    @aff_path = aff_path
  end

  def load_dic_data
    File.read(@dic_path)
  end
end

class HttpDictionaryLoader < DictionaryLoader
  def initialize(dic_url, aff_url, http_client:)
    @dic_url = dic_url
    @aff_url = aff_url
    @http_client = http_client
  end

  def load_dic_data
    @http_client.get(@dic_url).body
  end
end

class MemoryDictionaryLoader < DictionaryLoader
  def initialize(dic_data, aff_data)
    @dic_data = dic_data
    @aff_data = aff_data
  end

  def load_dic_data
    @dic_data
  end
end
```

**Impact**: Testability, flexibility, support multiple data sources

---

## 13. Chain of Responsibility for Pipelines

**Problem**: Monolithic processing, hard to modify

**Solution**: Chain of handlers, each does one thing

```ruby
class ProcessingHandler
  attr_accessor :next_handler

  def handle(context)
    result = process(context)
    @next_handler ? @next_handler.handle(context) : result
  end

  def process(context)
  end
end

class TokenizationHandler < ProcessingHandler
  def process(context)
    context.tokens = Tokenizer.new.tokenize(context.text)
    context
  end
end

class LookupHandler < ProcessingHandler
  def process(context)
    context.results = context.tokens.map { |t| check_word(t) }
    context
  end
end

class SuggestionFilteringHandler < ProcessingHandler
  def process(context)
    context.results.each do |result|
      result.suggestions = @filters.reduce(result.suggestions) { |s, f| f.filter(s, context) }
    end
    context
  end
end
```

**Impact**: Modular, testable, configurable processing pipeline

---

## 14. Decorator Pattern for Cross-Cutting Concerns

**Problem**: Logging, caching, metrics embedded in domain models

**Solution**: Layer decorators transparently

```ruby
class CachedDictionary < Dictionary
  def initialize(dictionary, cache:)
    @dictionary = dictionary
    @cache = cache
  end

  def lookup(word)
    @cache.get_or_set(word) { @dictionary.lookup(word) }
  end
end

class LoggingDictionary < Dictionary
  def initialize(dictionary, logger:)
    @dictionary = dictionary
    @logger = logger
  end

  def lookup(word)
    @logger.debug("Looking up: #{word}")
    result = @dictionary.lookup(word)
    @logger.debug("Result: #{result}")
    result
  end
end

class MetricsDictionary < Dictionary
  def initialize(dictionary, metrics:)
    @dictionary = dictionary
    @metrics = metrics
  end

  def lookup(word)
    start = Time.now
    result = @dictionary.lookup(word)
    @metrics.timing(:lookup_duration, Time.now - start)
    result
  end
end

# Compose decorators
dictionary = HunspellDictionary.new(dic_data, aff_data)
dictionary = CachedDictionary.new(dictionary, cache: LRUCache.new)
dictionary = LoggingDictionary.new(dictionary, logger: Logger.new)
dictionary = MetricsDictionary.new(dictionary, metrics: Metrics.new)
```

**Impact**: Clean separation of core logic and cross-cutting concerns

---

## 15. Prototype Pattern for Expensive Objects

**Problem**: Expensive objects recreated repeatedly

**Solution**: Clone prototypes instead of recreating

```ruby
class HunspellDictionary < Dictionary
  def initialize(dic_data, aff_data)
    @word_index = build_word_index(dic_data)
    @affix_rules = build_affix_rules(aff_data)
  end

  # Shallow clone: Share expensive structures
  def clone
    cloned = HunspellDictionary.allocate
    cloned.instance_variable_set(:@word_index, @word_index)
    cloned.instance_variable_set(:@affix_rules, @affix_rules)
    cloned
  end
end

class DictionaryPrototypeRegistry
  def register(key, prototype)
    @prototypes[key] = prototype
  end

  def clone(key)
    @prototypes[key].clone
  end
end

# Load once, clone many times
registry = DictionaryPrototypeRegistry.new
registry.register("en_US", HunspellDictionary.load("/path/to/file.dic", "/path/to/file.aff"))

spellchecker1 = Spellchecker.new(dictionary: registry.clone("en_US"))
spellchecker2 = Spellchecker.new(dictionary: registry.clone("en_US"))
```

**Impact**: Performance improvement for expensive objects

---

## Implementation Priority

### High Priority (Implement First)
1. **Double Dispatch** - Eliminates type-checking, core to architecture
2. **Aggregate Pattern** - Ensures consistency boundaries
3. **Repository Pattern** - Separates concerns cleanly
4. **Decorator Pattern** - Addresses cross-cutting concerns

### Medium Priority (Implement After Core Patterns)
5. **Domain Events** - Decoupling, extensibility
6. **Chain of Responsibility** - Pipeline flexibility
7. **Adapter Pattern** - Testability, multiple data sources
8. **Fluent Builders** - API usability

### Lower Priority (Polish)
9. **Specification Pattern** - Business rule clarity
10. **Visitor Pattern** - Traversal flexibility
11. **Command Pattern** - Undo/redo support
12. **Composite Pattern** - Collection handling
13. **Prototype Pattern** - Performance optimization
14. **Rich Domain Models** - Ongoing refactoring
15. **Correct Strategy Usage** - Architectural cleanup

---

## Updated Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                        Application Layer                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │   Command    │  │   Invoker    │  │ Event Bus    │      │
│  │   Objects    │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                        Domain Layer                          │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Aggregates   │  │   Value      │  │   Domain     │      │
│  │ (Dictionary, │  │   Objects    │  │  Events      │      │
│  │  RuleSet)    │  │ (Word, Flag) │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Visitors    │  │ Specifications│  │   Handlers   │      │
│  │              │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Infrastructure Layer                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Repositories │  │   Adapters   │  │   Builders   │      │
│  │              │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                                │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │  Decorators  │  │   Prototypes │  │   Factories  │      │
│  │              │  │              │  │              │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
└─────────────────────────────────────────────────────────────┘
```

---

## Checklist for Solidification Plan Update

- [ ] Add Double Dispatch pattern to Dictionary interface
- [ ] Add Aggregate pattern documentation
- [ ] Add Repository pattern for data access
- [ ] Add Factory pattern for model construction
- [ ] Add Domain Events system
- [ ] Add EventBus interface and implementation
- [ ] Add Chain of Responsibility for processing pipeline
- [ ] Add ProcessingContext model
- [ ] Add Decorator pattern for cross-cutting concerns
- [ ] Add Adapter pattern for external systems
- [ ] Add Fluent Builder pattern
- [ ] Add Specification pattern for business rules
- [ ] Add Visitor pattern for traversals
- [ ] Add Command pattern for operations
- [ ] Add Composite pattern for collections
- [ ] Add Prototype pattern for expensive objects
- [ ] Review and revise Strategy pattern usage
- [ ] Ensure rich domain models (not anemic)

---

**This document is a living supplement to KOTOSHU_SOLIDIFICATION_PLAN.md**
**All 15 improvements should be incorporated for maximum OOP architecture quality**
