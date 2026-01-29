# Kotoshu TDD Iteration Strategy

**Status**: Complete TDD Workflow for Model-Driven Architecture
**Last Updated**: 2025-01-29
**Analysis**: ULTRATHINK Deep Review

## Executive Summary

This document outlines the complete Test-Driven Development (TDD) iteration strategy for building Kotoshu with a model-driven OOP architecture. TDD is integrated with Model-Driven Development (MDD) to ensure both correct implementation AND proper design.

---

## TDD + Model-Driven Development (MDD)

### The Combined Cycle

```
┌─────────────────────────────────────────────────────────────┐
│                  MODELING PHASE (Design)                     │
│  1. Identify domain concept (noun in problem space)        │
│  2. Classify: MODEL, VALUE, SERVICE, or STRATEGY            │
│  3. Define RESPONSIBILITIES (what it SHOULD do)            │
│  4. Define RELATIONSHIPS (composition, inheritance)        │
│  5. Define QUERY METHODS (behavior on objects)             │
│  Output: Model diagram, responsibility list                 │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  TDD PHASE (Implementation)                  │
│  RED:   Write test for ONE behavior/query method           │
│  GREEN: Implement MINIMAL code to pass                      │
│  REFACTOR: Improve while keeping tests green               │
│  Output: Working code with passing tests                    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  REVIEW PHASE (Validation)                   │
│  ✓ Models are RICH (not anemic)                            │
│  ✓ VALUE objects are immutable                             │
│  ✓ POLYMORPHISM over configuration                         │
│  ✓ Separation of concerns maintained                       │
│  ✓ Tests specify BEHAVIOR, not implementation              │
│  Output: Verified OOP architecture                          │
└─────────────────────────────────────────────────────────────┘
```

---

## Phase 0: Walking Skeleton (Week 1)

**Goal**: Validate architecture end-to-end before building features.

### What is a Walking Skeleton?

A minimal but complete system that exercises the entire architecture from input to output.

### Walking Skeleton Requirements

```ruby
# Minimal end-to-end functionality
describe "Kotoshu Walking Skeleton" do
  it "loads dictionary and checks words" do
    # 1. Load dictionary (Hunspell backend)
    dictionary = DictionaryBuilder.new
      .hunspell("spec/fixtures/test.dic", "spec/fixtures/test.aff")
      .build

    # 2. Check word
    spellchecker = Spellchecker.new(dictionary: dictionary)
    result = spellchecker.check_word("hello")

    # 3. Verify result
    expect(result.correct?).to be true
    expect(result.word).to eq("hello")
  end

  it "generates suggestions for incorrect word" do
    dictionary = DictionaryBuilder.new
      .plain_text("spec/fixtures/words.txt")
      .build

    spellchecker = Spellchecker.new(
      dictionary: dictionary,
      suggestion_generator: EditDistanceGenerator.new
    )

    result = spellchecker.check_word("helo")

    expect(result.incorrect?).to be true
    expect(result.suggestions.count).to be > 0
  end
end
```

### Walking Skeleton Implementation Order

**Day 1: Core Models**
```ruby
# Word VALUE object
describe Word do
  it "has text and value equality" do
    word1 = Word.new("hello")
    word2 = Word.new("hello")
    expect(word1).to eq(word2)
  end
end

# Dictionary AGGREGATE
describe Dictionary do
  it "stores and looks up words" do
    dictionary = Dictionary.new
    word = Word.new("hello")
    dictionary.add_word(word)

    expect(dictionary.lookup("hello")).to eq(word)
  end
end
```

**Day 2: Basic Repository**
```ruby
# File system loader
describe FileSystemDictionaryLoader do
  it "loads dictionary from file" do
    loader = FileSystemDictionaryLoader.new("spec/fixtures/words.txt")
    data = loader.load

    expect(data).to include("hello")
  end
end
```

**Day 3: Factory**
```ruby
# Dictionary factory
describe DictionaryBuilder do
  it "builds dictionary from file" do
    dictionary = DictionaryBuilder.new
      .plain_text("spec/fixtures/words.txt")
      .build

    expect(dictionary.lookup("hello")).to be_truthy
  end
end
```

**Day 4: Service Layer**
```ruby
# Spellchecker service
describe Spellchecker do
  it "checks word and returns result" do
    dictionary = instance_double("Dictionary", lookup: true)
    spellchecker = Spellchecker.new(dictionary: dictionary)

    result = spellchecker.check_word("hello")

    expect(result.correct?).to be true
  end
end
```

**Day 5: Integration & CLI**
```ruby
# End-to-end integration test
describe "Kotoshu Integration" do
  it "checks text file and outputs errors" do
    spellchecker = Spellchecker.from_config("config.yml")
    result = spellchecker.check_file("spec/fixtures/document.txt")

    expect(result.errors.count).to eq(2)
  end
end
```

### Walking Skeleton Checklist

- [ ] Word VALUE object with text and equality
- [ ] Dictionary AGGREGATE with add/lookup
- [ ] One dictionary backend (PlainText or UnixWords)
- [ ] One suggestion algorithm (EditDistance)
- [ ] Spellchecker SERVICE orchestrating check
- [ ] CLI command works end-to-end
- [ ] All tests pass
- [ ] CI/CD pipeline runs tests

---

## Daily TDD Workflow

### Morning: Modeling Session (30-60 min)

**Purpose**: Design models before writing code.

**Process**:
1. Review vertical slice for the day
2. Draw model diagrams (pencil and paper)
3. Identify MODELS, VALUES, SERVICES, STRATEGIES
4. Define responsibilities and relationships
5. List query methods for each model

**Example: Modeling Flag Hierarchy**

```
Domain Concept: Affix flags

Classification: VALUE object (immutable, compared by value)

Responsibilities:
- Parse from string (factory)
- Match against other flags
- Convert to appropriate type

Relationships:
Flag (abstract VALUE)
├── CharFlag (VALUE): Single character
├── NumericFlag (VALUE): Numeric (123)
└── LongFlag (VALUE): Multi-character (ABC)

Query Methods:
- matches?(other): Boolean
- to_char: String (CharFlag only)
- to_i: Integer (NumericFlag only)
- to_s: String (LongFlag only)
```

### Mid-Morning: Test Writing (RED Phase)

**Write ONE test at a time**

```ruby
# spec/kotoshu/core/models/flag_spec.rb

describe Flag do
  describe ".parse" do
    context "with single character" do
      it "parses as CharFlag" do
        flag = Flag.parse("A")

        expect(flag).to be_a(CharFlag)
      end
    end

    context "with number" do
      it "parses as NumericFlag" do
        flag = Flag.parse("123")

        expect(flag).to be_a(NumericFlag)
      end
    end
  end

  describe "#matches?" do
    it "returns true for matching CharFlags" do
      flag1 = CharFlag.new("A")
      flag2 = CharFlag.new("A")

      expect(flag1.matches?(flag2)).to be true
    end

    it "returns false for non-matching CharFlags" do
      flag1 = CharFlag.new("A")
      flag2 = CharFlag.new("B")

      expect(flag1.matches?(flag2)).to be false
    end
  end
end
```

**Run test**: Should FAIL (RED)

```bash
bundle exec rspec spec/kotoshu/core/models/flag_spec.rb
# Expected: 6 examples, 0 failures, 6 pending
# Pending tests are those we haven't implemented yet
```

**Commit**: `git commit -m "test: Add Flag parse and match specs"`

### Late Morning: Implementation (GREEN Phase)

**Write MINIMAL code to pass test**

```ruby
# lib/kotoshu/core/models/flag.rb

class Flag
  def self.parse(string)
    case string
    when string.length == 1 && string.match?(/[A-Z]/)
      CharFlag.new(string)
    when string.match?(/^\d+$/)
      NumericFlag.new(string.to_i)
    else
      LongFlag.new(string)
    end
  end
end

class CharFlag < Flag
  attr_reader :char

  def initialize(char)
    @char = char
    freeze
  end

  def matches?(other)
    other.is_a?(CharFlag) && @char == other.char
  end
end

class NumericFlag < Flag
  attr_reader :value

  def initialize(value)
    @value = value
    freeze
  end

  def matches?(other)
    other.is_a?(NumericFlag) && @value == other.value
  end
end

class LongFlag < Flag
  attr_reader :text

  def initialize(text)
    @text = text
    freeze
  end

  def matches?(other)
    other.is_a?(LongFlag) && @text == other.text
  end
end
```

**Run test**: Should PASS (GREEN)

```bash
bundle exec rspec spec/kotoshu/core/models/flag_spec.rb
# Expected: 6 examples, 0 failures
```

**Commit**: `git commit -m "feat: Implement Flag VALUE hierarchy"`

### Afternoon: Refactoring (REFACTOR Phase)

**Improve code while tests stay green**

```ruby
# Before refactoring
class CharFlag < Flag
  def initialize(char)
    @char = char
    freeze
  end

  def matches?(other)
    other.is_a?(CharFlag) && @char == other.char
  end
end

# After refactoring: Add value equality, hashing
class CharFlag < Flag
  attr_reader :char

  def initialize(char)
    @char = char
    freeze
  end

  def matches?(other)
    other.is_a?(CharFlag) && @char == other.char
  end

  def ==(other)
    matches?(other)
  end

  alias eql? ==

  def hash
    @char.hash
end
```

**Run ALL tests**: Should all pass

```bash
bundle exec rspec
# Expected: All examples, 0 failures
```

**Commit**: `git commit -m "refactor: Add value equality to CharFlag"`

### End of Day: Review

**Run full test suite**
```bash
bundle exec rspec
```

**Run Rubocop**
```bash
bundle exec rubocop -A
```

**Review against OOP checklist**
- [ ] Model has behavior (not just data)?
- [ ] VALUE object is immutable?
- [ ] Polymorphism used instead of configuration?
- [ ] Tests specify behavior, not implementation?
- [ ] No god classes (>200 lines)?
- [ ] Separation of concerns maintained?

**Push to feature branch**
```bash
git push origin feature/flag-value-object
```

---

## Iteration Order: Vertical Slices

### Milestone 1: Core Foundation (Week 2)

**Vertical Slice 1: Word VALUE Object (1 day)**

```ruby
# spec/kotoshu/core/models/word_spec.rb
describe Word do
  describe "creation" do
    it "creates word with text" do
      word = Word.new("hello")
      expect(word.text).to eq("hello")
    end
  end

  describe "value equality" do
    it "two words with same text are equal" do
      word1 = Word.new("hello")
      word2 = Word.new("hello")
      expect(word1).to eq(word2)
    end
  end

  describe "immutability" do
    it "cannot modify text after creation" do
      word = Word.new("hello")
      expect { word.text = "world" }.to raise_error(FrozenError)
    end
  end

  describe "hashing" do
    it "can be used as hash key" do
      word1 = Word.new("hello")
      word2 = Word.new("hello")
      hash = { word1 => "value" }
      expect(hash[word2]).to eq("value")
    end
  end
end
```

**Definition of Done**:
- [ ] All tests pass
- [ ] VALUE object is immutable
- [ ] Has value equality and hashing
- [ ] Used by Dictionary
- [ ] Documented in README

**Vertical Slice 2: Dictionary AGGREGATE (2 days)**

```ruby
# spec/kotoshu/dictionary_spec.rb
describe Dictionary do
  describe "adding words" do
    it "stores words in aggregate" do
      word = Word.new("hello")
      dictionary = Dictionary.new

      dictionary.add_word(word)

      expect(dictionary.word_count).to eq(1)
    end
  end

  describe "lookup" do
    it "finds word by text" do
      word = Word.new("hello")
      dictionary = Dictionary.new
      dictionary.add_word(word)

      found = dictionary.lookup("hello")

      expect(found).to eq(word)
    end

    it "returns nil for word not found" do
      dictionary = Dictionary.new

      found = dictionary.lookup("unknown")

      expect(found).to be_nil
    end
  end

  describe "aggregate boundary" do
    it "maintains consistency when adding words" do
      dictionary = Dictionary.new

      word = dictionary.add_word_with_metadata("hello", flags: [NounFlag.new])

      expect(dictionary.lookup("hello")).to eq(word)
      expect(dictionary.word_count).to eq(1)
    end
  end
end
```

**Vertical Slice 3: UnixWords REPOSITORY (2 days)**

```ruby
# spec/kotoshu/dictionary/unix_words_loader_spec.rb
describe FileSystemDictionaryLoader do
  describe "#load_dic_data" do
    it "loads dictionary data from file" do
      loader = FileSystemDictionaryLoader.new("spec/fixtures/words.txt")
      data = loader.load_dic_data

      expect(data).to include("hello")
      expect(data).to include("world")
    end
  end

  describe "#load" do
    it "returns hash with words and metadata" do
      loader = FileSystemDictionaryLoader.new("spec/fixtures/words.txt")
      data = loader.load

      expect(data).to have_key(:words)
      expect(data).to have_key(:metadata)
      expect(data[:words]).to be_an(Array)
    end
  end
end
```

**Vertical Slice 4: UnixWordsDictionary MODEL (2 days)**

```ruby
# spec/kotoshu/dictionary/unix_words_spec.rb
describe UnixWordsDictionary do
  describe "initialization" do
    it "loads words from file" do
      dictionary = UnixWordsDictionary.new("spec/fixtures/words.txt")

      expect(dictionary.word_count).to be > 0
    end
  end

  describe "#lookup" do
    it "finds words case-insensitively by default" do
      dictionary = UnixWordsDictionary.new("spec/fixtures/words.txt")

      expect(dictionary.lookup("hello")).to be_truthy
      expect(dictionary.lookup("HELLO")).to be_truthy
      expect(dictionary.lookup("Hello")).to be_truthy
    end

    it "finds words case-sensitively when configured" do
      dictionary = UnixWordsDictionary.new("spec/fixtures/words.txt", case_sensitive: true)

      expect(dictionary.lookup("hello")).to be_truthy
      expect(dictionary.lookup("HELLO")).to be_falsey
    end
  end
end
```

**Vertical Slice 5: Spellchecker SERVICE (2 days)**

```ruby
# spec/kotoshu/spellchecker_spec.rb
describe Spellchecker do
  let(:dictionary) { instance_double("Dictionary", lookup: nil) }
  let(:generator) { instance_double("SuggestionGenerator", generate: []) }
  let(:config) { Configuration.new }
  subject(:spellchecker) { Spellchecker.new(dictionary:, suggestion_generator: generator, config:) }

  describe "#check_word" do
    context "when word is correct" do
      it "returns correct result" do
        allow(dictionary).to receive(:lookup).with("hello").and_return(true)

        result = spellchecker.check_word("hello")

        expect(result.correct?).to be true
        expect(result.word).to eq("hello")
      end
    end

    context "when word is incorrect" do
      it "returns incorrect result with suggestions" do
        allow(dictionary).to receive(:lookup).with("helo").and_return(false)
        suggestions = [Suggestion.new("hello", confidence: 0.9)]
        allow(generator).to receive(:generate).with("helo", dictionary).and_return(suggestions)

        result = spellchecker.check_word("helo")

        expect(result.incorrect?).to be true
        expect(result.suggestions.to_a).to eq(suggestions)
      end
    end
  end

  describe "#check" do
    it "tokenizes text and checks each word" do
      text = "hello wrld"
      allow(dictionary).to receive(:lookup).with("hello").and_return(true)
      allow(dictionary).to receive(:lookup).with("wrld").and_return(false)
      allow(generator).to receive(:generate).with("wrld", dictionary).and_return([])

      result = spellchecker.check(text)

      expect(result.word_count).to eq(2)
      expect(result.errors.count).to eq(1)
    end
  end
end
```

---

## Iteration Schedule (10 Weeks)

### Week 1: Walking Skeleton
- Day 1-2: Core models (Word, Dictionary)
- Day 3: Repository (FileSystemDictionaryLoader)
- Day 4: Factory (DictionaryBuilder)
- Day 5: Integration + CLI

### Week 2: Core Foundation
- Day 1-2: Word VALUE object
- Day 3-4: Dictionary AGGREGATE
- Day 5: UnixWords backend

### Week 3: First Algorithm
- Day 1-2: EditDistance VALUE
- Day 3: Suggestion VALUE
- Day 4: SuggestionSet COMPOSITE
- Day 5: EditDistanceSuggestionGenerator SERVICE

### Week 4: Hunspell Foundation
- Day 1-2: Flag VALUE hierarchy
- Day 3-4: AffixRule MODEL
- Day 5: AffixApplication VALUE

### Week 5: Hunspell Backend
- Day 1-2: Hunspell REPOSITORY
- Day 3-4: HunspellDictionary MODEL
- Day 5: Integration + CLI

### Week 6: Affix Advanced
- Day 1: AffixCombination MODEL
- Day 2: AffixCombinationRegistry MODEL
- Day 3: AffixApplier SERVICE
- Day 4: Cross-product optimization
- Day 5: Integration tests

### Week 7: Phonetic Suggestions
- Day 1-2: PhoneticCode VALUE (Soundex, Metaphone)
- Day 3: NGram VALUE + NGramIndex MODEL
- Day 4: PhoneticSuggestionGenerator SERVICE
- Day 5: Integration tests

### Week 8: Advanced Suggestions
- Day 1-2: KeyboardLayout MODEL + EditCost VALUE
- Day 3: SymSpell MODEL (DeleteHash, DeleteVariant)
- Day 4: SuggestionPipeline CHAIN
- Day 5: Integration tests

### Week 9: Compound Words
- Day 1-2: CompoundRule MODEL
- Day 3: CompoundWord MODEL
- Day 4: CompoundPart VALUE + CompoundValidator SERVICE
- Day 5: Integration tests

### Week 10: Polish
- Day 1-2: Morphological analysis (WordForm, Stem MODELs)
- Day 3: Documentation (README, examples)
- Day 4: Performance benchmarks
- Day 5: Final integration tests + CI/CD

---

## Handling Dependencies with Test Doubles

### When to Use Test Doubles

**Use doubles when**:
- Dependency not implemented yet
- Testing SERVICE orchestration
- Testing in isolation (fast tests)
- External system (file system, HTTP, database)

**Don't use doubles when**:
- Testing VALUE objects
- Testing MODEL relationships
- Integration testing
- Would test implementation details

### Test Double Examples

**Mocking Dictionary:**
```ruby
let(:dictionary) do
  instance_double("Dictionary",
    lookup: nil,
    words: [],
    word_count: 0
  )
end
```

**Stubbing Responses:**
```ruby
allow(dictionary).to receive(:lookup).with("hello").and_return(true)
allow(dictionary).to receive(:lookup).with("unknown").and_return(false)
```

**Spying on Calls:**
```ruby
allow(dictionary).to receive(:lookup).and_call_original
# ... run code ...
expect(dictionary).to have_received(:lookup).with("hello").once
```

---

## Definition of Done

### For Each Vertical Slice

**Code Quality**:
- [ ] All tests pass (100% GREEN)
- [ ] Rubocop passes with 0 offenses
- [ ] No commented-out code
- [ ] No debugger statements
- [ ] No temporary files

**Testing**:
- [ ] Unit tests for all MODELs
- [ ] Unit tests for all VALUEs
- [ ] Unit tests for all SERVICEs
- [ ] Integration test for feature
- [ ] Edge cases covered

**Architecture**:
- [ ] Follows MODEL/VALUE/SERVICE separation
- [ ] Polymorphism over configuration
- [ ] Rich models (not anemic)
- [ ] VALUE objects immutable
- [ ] No god classes

**Documentation**:
- [ ] Self-documenting code
- [ ] Public API documented
- [ ] README updated if user-visible

**Integration**:
- [ ] Works end-to-end
- [ ] CLI works if applicable
- [ ] Example script created
- [ ] No regressions

---

## Refactoring Guidelines

### When to Refactor

**Refactor during REFACTOR phase when**:
- Code has duplication
- Method is too long (>10 lines)
- Class has too many responsibilities
- Configuration used instead of polymorphism
- Implementation details exposed

### Refactoring Example: From Flags to Polymorphism

**Before (Configuration-based):**
```ruby
class Word
  def can_stand_alone?
    if @flags.include?(:needaffix)
      false
    else
      true
    end
  end
end
```

**After (Polymorphic):**
```ruby
class Word
  def can_stand_alone?
    true
  end
end

class DependentWord < Word
  def can_stand_alone?
    false
  end
end
```

**Refactoring Steps**:
1. Add `can_stand_alone?` to Word (default true)
2. Create DependentWord subclass
3. Override `can_stand_alone?` to false
4. Update tests to use polymorphism
5. Remove flag checking

### Large Refactorings: Strangler Fig Pattern

**For architectural changes that affect many files:**

1. **Add NEW alongside OLD** (no breaking)
2. **Migrate gradually** to NEW
3. **Remove OLD** once everything uses NEW

**Example: Introducing Double Dispatch**

```ruby
# Step 1: Add new interface
class Dictionary
  def suggestions_for(word)
    # Old approach
    generate_suggestions(word)
  end
end

# Step 2: Implement in subclasses
class HunspellDictionary < Dictionary
  def suggestions_for(word)
    # New approach
  end
end

# Step 3: Update clients to use new interface
class Spellchecker
  def suggest(word, dictionary)
    word.suggestions_from(dictionary) # Uses double dispatch
  end
end

# Step 4: Remove old interface
class Dictionary
  def suggestions_for(word)
    raise NotImplementedError
  end
end
```

---

## Test Maintenance

### Test Behavior, Not Implementation

**Brittle test (tests implementation):**
```ruby
# BAD
describe Word do
  it "stores text in instance variable" do
    word = Word.new("hello")
    expect(word.instance_variable_get(:@text)).to eq("hello")
  end
end
```

**Robust test (tests behavior):**
```ruby
# GOOD
describe Word do
  describe "#text" do
    it "returns the word text" do
      word = Word.new("hello")
      expect(word.text).to eq("hello")
    end
  end
end
```

### Testing Service Orchestration

**Brittle (tests order):**
```ruby
# BAD
describe Spellchecker do
  it "calls lookup then generate" do
    expect(dictionary).to have_received(:lookup).ordered
    expect(generator).to have_received(:generate).ordered
  end
end
```

**Robust (tests result):**
```ruby
# GOOD
describe Spellchecker do
  it "returns incorrect result with suggestions when word not found" do
    allow(dictionary).to receive(:lookup).and_return(false)
    suggestions = [Suggestion.new("hello")]
    allow(generator).to receive(:generate).and_return(suggestions)

    result = spellchecker.check_word("helo")

    expect(result.incorrect?).to be true
    expect(result.suggestions.to_a).to eq(suggestions)
  end
end
```

---

## Git Workflow

### Branch Strategy

```bash
# Main branch (always stable)
main

# Feature branches (one per vertical slice)
feature/word-value-object
feature/dictionary-aggregate
feature/unix-words-backend
feature/edit-distance-suggestions
feature/hunspell-backend
```

### Commit Strategy

**Small, focused commits:**

```bash
# Each behavior in its own commit
git add spec/word_spec.rb
git commit -m "test: Word VALUE has text"

git add lib/word.rb
git commit -m "feat: Implement Word VALUE"

git add lib/word.rb spec/word_spec.rb
git commit -m "refactor: Add value equality to Word"

# End of day
git push origin feature/word-value-object
```

**Commit message format:**
- `test:` - Adding tests
- `feat:` - Adding features
- `refactor:` - Improving design (no behavior change)
- `fix:` - Bug fixes
- `docs:` - Documentation changes

### Pull Request Process

```bash
# 1. Create feature branch
git checkout -b feature/word-value-object

# 2. Work with TDD cycle (test, code, refactor, commit)

# 3. Push to remote
git push origin feature/word-value-object

# 4. Create pull request
# Title: "feat: Add Word VALUE object with text and equality"
# Description: Implements Word VALUE object per OOP architecture
# Tests: 10/10 passing
# Checklist:
# - [ ] All tests pass
# - [ ] Rubocop clean
# - [ ] Code reviewed
# - [ ] Documentation updated

# 5. Code review
# - Peer reviews for OOP principles
# - Approve or request changes

# 6. Merge to main
# squash merge to keep history clean
```

---

## Continuous Integration

### CI/CD Pipeline

**Every push triggers:**
```yaml
# .github/workflows/test.yml
name: Test
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    strategy:
      matrix:
        ruby-version: ['3.1', '3.2', '3.3']

    steps:
      - uses: actions/checkout@v3

      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: ${{ matrix.ruby-version }}
          bundler-cache: true

      - name: Install dependencies
        run: bundle install

      - name: Run tests
        run: bundle exec rspec

      - name: Run Rubocop
        run: bundle exec rubocop -A

      - name: Check coverage
        run: bundle exec rake coverage
```

**No merge if tests fail**

---

## Tools and Setup

### Required Gems

```ruby
# Gemfile
group :development, :test do
  gem 'rspec', '~> 3.12'
  gem 'rspec-mocks', '~> 3.12'
  gem 'rubocop', '~> 1.50'
  gem 'rubocop-rspec', '~> 2.20'
  gem 'simplecov', '~> 0.22'
  gem 'benchmark-ips', '~> 2.12'
end
```

### RSpec Configuration

```ruby
# spec/spec_helper.rb
require 'simplecov'
SimpleCov.start

RSpec.configure do |config|
  # Use expect syntax
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Run specs in random order
  config.order = :random

  # Enable monkey patching for mocks
  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  # Allow focusing on specific tests
  config.filter_run_when_focusing = true

  # Run all tests when not focusing
  config.run_all_when_everything_filtered = true
end
```

---

## Summary

**TDD + MDA Workflow**:
1. Model domain concepts (MODEL/VALUE/SERVICE)
2. Test behavior (RED)
3. Implement (GREEN)
4. Refactor for OOP (REFACTOR)

**Iteration Strategy**:
- Week 1: Walking Skeleton
- Weeks 2-10: Vertical slices (one feature per week)
- Each slice: Models → Repositories → Services → Integration

**Key Principles**:
- Test BEHAVIOR, not implementation
- Small commits, frequent pushes
- Continuous integration
- Code review for OOP principles
- Definition of Done for each slice

**This ensures Kotoshu is built incrementally with constant validation of both correctness (tests) and design (OOP principles).**

---

**This is a living document. Update as we learn from the development process.**
