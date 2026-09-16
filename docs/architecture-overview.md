# Kotoshu Architecture

## Overview

Kotoshu is a high-performance spellchecker library for Ruby, designed with modular, object-oriented architecture. It supports multiple dictionary backends, suggestion algorithms, and provides both CLI and Ruby API interfaces.

## Design Principles

1. **Hexagonal Architecture**: Core business logic is independent of interfaces
2. **Strategy Pattern**: Pluggable dictionaries and suggestion algorithms
3. **Value Objects**: Immutable result objects for type safety
4. **Performance First**: SymSpell, three-tier caching, Bloom filters
5. **Zero-Copy Operations**: Minimize data duplication

## Core Components

### 1. Spellchecker (`lib/kotoshu/spellchecker.rb`)

The main orchestrator that coordinates dictionary lookups and suggestion generation.

```ruby
Kotoshu::Spellchecker.new(dictionary: dict)
  .correct?("hello")
  .suggest("helo")
  .check("Hello world")
```

**Key Responsibilities:**
- Word validation via dictionary lookup
- Suggestion generation via pluggable strategies
- Document/paragraph text checking
- Integration with caching layer

### 2. Dictionary Layer (`lib/kotoshu/dictionary/`)

Abstract interface for multiple dictionary backends.

```
Dictionary::Base
├── Hunspell - Morphological rules (.dic/.aff)
├── CSpell - Code-aware dictionaries (.txt/.trie)
├── UnixWords - System dictionaries
├── PlainText - Simple word lists
└── Custom - Runtime word lists
```

**Interface:**
```ruby
class Kotoshu::Dictionary::Base
  # Required
  def lookup(word) -> Boolean
  def suggest(word, max_suggestions:) -> Array<String>

  # Optional
  def add_word(word, flags: []) -> Boolean
  def remove_word(word) -> Boolean
  def words -> Array<String>
end
```

### 3. Suggestion System (`lib/kotoshu/suggestions/`)

Pluggable suggestion algorithms with flexible composition.

#### Strategies

```
Suggestions::Strategies::BaseStrategy
├── EditDistanceStrategy - Levenshtein distance
├── SymSpellStrategy - Deletion distance (100x faster)
├── PhoneticStrategy - Soundex/Metaphone
├── NgramStrategy - N-gram similarity
├── KeyboardProximityStrategy - QWERTY adjacency
└── CompositeStrategy - Combine multiple strategies
```

#### Suggestion Generation Flow

```
Input: "helo"
  ↓
Context created (word, dictionary, options)
  ↓
Pipeline.execute(context)
  ↓
┌──────────────────────────────────┐
│ Stage 1: SymSpell (fast path)    │ → SuggestionSet
├──────────────────────────────────┤
│ Stage 2: EditDistance (fallback) │ → SuggestionSet
├──────────────────────────────────┤
│ Stage 3: Phonetic (phonetics)    │ → SuggestionSet
└──────────────────────────────────┘
  ↓
Combined + Ranked + Limited
  ↓
Output: ["hello", "help", ...]
```

#### Suggestion Object

```ruby
Suggestion.new(
  word: "hello",
  distance: 1,
  confidence: 0.95,
  source: :symspell
)
```

### 4. Performance Layer (`lib/kotoshu/cache/`, `lib/kotoshu/data_structures/`)

#### Three-Tier Caching

```
┌─────────────────────────────────────────────────────────┐
│                     L1: LookupCache                     │
│  - 1000-entry LRU cache                                 │
│  - O(1) word existence lookup                           │
│  - Automatic eviction when full                         │
└────────────────────┬────────────────────────────────────┘
                     │ cache miss
                     ↓
┌─────────────────────────────────────────────────────────┐
│                     L2: SuggestionCache                 │
│  - 5000-entry LRU cache                                 │
│  - Word-keyed with max_results parameter                │
│  - Avoids redundant suggestion computation              │
└────────────────────┬────────────────────────────────────┘
                     │ cache miss
                     ↓
┌─────────────────────────────────────────────────────────┐
│                     L3: DiskCache (optional)            │
│  - Persistent cache with TTL                            │
│  - Survives process restarts                            │
│  - Configurable expiration                              │
└─────────────────────────────────────────────────────────┘
```

**Cache Statistics:**
```ruby
cache.stats
# => { hits: 950, misses: 50, size: 1000, hit_rate: 0.95 }
```

#### Bloom Filter

Probabilistic data structure for O(1) "definitely not in dictionary" responses.

```
Bloom Filter
  ├─ Expected size: 10,000 items
  ├─ False positive rate: 1%
  ├─ Hash functions: ~7
  └─ Memory: ~12KB

Operations:
  add(word) - O(k) where k = hash count
  include?(word) - O(k)
```

**Properties:**
- Zero false negatives
- Configurable false positive rate
- Case-insensitive option

### 5. Parallel Processing (`lib/kotoshu/spellchecker/parallel_checker.rb`)

Thread pool for concurrent file checking.

```
Input: [file1.txt, file2.txt, file3.txt, ...]
  ↓
Queue.populate(files)
  ↓
┌──────────────────────────────────────────┐
│  Worker 1  │  Worker 2  │  Worker 3     │
│  file1.txt │  file2.txt │  file3.txt    │
└────────────┴─────────────┴───────────────┘
  ↓
Mutex-protected results array
  ↓
Output: [Result1, Result2, Result3, ...]
```

**Configuration:**
- Default workers: 4
- Thread-safe with Mutex
- Poison pill pattern for shutdown

### 6. Configuration System (`lib/kotoshu/configuration/`)

Immutable configuration with builder pattern.

```ruby
config = Kotoshu::Configuration::Builder.build do |b|
  b.dictionary_path = "/usr/share/dict/words"
  b.dictionary_type = :unix_words
  b.max_suggestions = 10
  b.case_sensitive = false
end
# config is frozen - thread-safe
```

**Configuration Chain (priority order):**
1. Runtime parameters
2. Environment variables (`KOTOSHU_*`)
3. Config file (`.kotoshu`)
4. Defaults

### 7. Result Pattern (`lib/kotoshu/results/result.rb`)

Functional error handling without exceptions.

```ruby
result = dictionary.lookup_safe("word")

result.success? # => true/false
result.and_then { |v| process(v) }
result.or_else { |err| handle_error(err) }
result.unwrap # raises on failure
```

**Types:**
- `Result::Success(value)` - Successful operation
- `Result::Failure(error)` - Failed operation

### 8. Plugin System (`lib/kotoshu/plugins/`)

Dependency injection for extensibility.

```ruby
class MyPlugin < Kotoshu::Plugins::Plugin
  plugin_name :my_plugin
  dependencies [:spellchecker]
  provides [:custom_algorithm]

  def before_start
    # Initialize plugin
  end
end

registry = Kotoshu::Plugins::Registry.new
registry.register(:my_plugin, MyPlugin)
registry.start_all
```

## Algorithm Details

### SymSpell Algorithm

Deletion-distance based approximate string matching.

**Precomputation:**
```ruby
# For each word in dictionary:
"hello" → ["ello", "hllo", "helo", "helo", "hell"]
# Store deletion → original mapping
@deletes["ello"] = ["hello", "yellow", ...]
```

**Lookup:**
```ruby
# Input: "helo"
1. Check if "helo" exists in @deletes
2. Generate deletions: ["elo", "hlo", "heo", "hel", "hel"]
3. Check each deletion in @deletes
4. Return matches with calculated distance
```

**Complexity:**
- Precomputation: O(N × L) where N = dictionary size, L = avg word length
- Lookup: O(L) for deletion generation + O(1) for hash lookup
- Space: O(N × L) for deletion table

**Performance:** ~100-150x faster than edit distance

### Edit Distance Algorithm

Levenshtein distance with Wagner-Fischer algorithm.

```ruby
def edit_distance(a, b)
  matrix = Array.new(a.length + 1) { Array.new(b.length + 1) }

  (0..a.length).each { |i| matrix[i][0] = i }
  (0..b.length).each { |j| matrix[0][j] = j }

  (1..a.length).each do |i|
    (1..b.length).each do |j|
      cost = a[i-1] == b[j-1] ? 0 : 1
      matrix[i][j] = [
        matrix[i-1][j] + 1,      # deletion
        matrix[i][j-1] + 1,      # insertion
        matrix[i-1][j-1] + cost  # substitution
      ].min
    end
  end

  matrix[a.length][b.length]
end
```

**Complexity:**
- Time: O(m × n) where m, n are word lengths
- Space: O(m × n) for the matrix
- Optimized: O(min(m, n)) space with two rows

## Data Flow

### Single Word Check

```
"hello" → Spellchecker.correct?("hello")
  ↓
LookupCache.fetch("hello")
  ↓
BloomFilter.include?("hello") [fast reject]
  ↓
Dictionary.lookup("hello")
  ↓
Return: true/false
```

### Suggestion Generation

```
"helo" → Spellchecker.suggest("helo")
  ↓
SuggestionCache.fetch("helo", max_results: 10)
  ↓
SuggestionGenerator.generate("helo")
  ↓
Pipeline.execute(context)
  ├─ SymSpellStrategy → SuggestionSet
  ├─ EditDistanceStrategy → SuggestionSet
  └─ Combined + Ranked
  ↓
Return: SuggestionSet([Suggestion("hello", 1), ...])
```

### Document Check

```
"Hello wrold" → Spellchecker.check("Hello wrold")
  ↓
Tokenizer.split(text) → ["Hello", "wrold"]
  ↓
Each word → correct? or suggest()
  ↓
DocumentResult.new(
  text: "Hello wrold",
  errors: [
    SpellingError.new("wrold", position: 6, suggestions: [...])
  ]
)
```

## Performance Characteristics

### Lookup Performance

| Operation | Time | Notes |
|-----------|------|-------|
| BloomFilter.include? | O(1) | 1% FP rate |
| LookupCache.fetch (hit) | O(1) | LRU cache |
| Dictionary.lookup | O(1) | Hash-based |
| PlainText.from_words | O(N) | N = word count |

### Suggestion Performance

| Algorithm | Time | Quality | Notes |
|-----------|------|---------|-------|
| SymSpell | O(L) | High | 100x+ faster |
| EditDistance | O(N × L²) | High | Baseline |
| Phonetic | O(N) | Medium | For sound-alikes |

**Benchmarks (50K word dictionary):**
- SymSpell: ~11ms for 10 lookups
- EditDistance: ~1500ms for 10 lookups
- **Speedup: 132x**

### Memory Usage

| Component | Memory | Notes |
|-----------|--------|-------|
| Dictionary (50K words) | ~5MB | Plain text |
| SymSpell deletion table | ~50MB | 50K words × deletions |
| BloomFilter (10K items) | ~12KB | 1% FP rate |
| LookupCache (1K entries) | ~100KB | LRU cache |
| SuggestionCache (5K entries) | ~500KB | LRU cache |

## Extension Points

### Custom Dictionary

```ruby
class MyDictionary < Kotoshu::Dictionary::Base
  register_type :my_dict, self

  def initialize(path, language_code:, **options)
    # Initialize
  end

  def lookup(word)
    # Implementation
  end
end
```

### Custom Suggestion Algorithm

```ruby
class MyAlgorithm < Kotoshu::Suggestions::Strategies::BaseStrategy
  register_algorithm :my_algo, self

  def initialize(name: :my_algo, **config)
    super
  end

  def generate(context)
    # Return SuggestionSet
  end
end
```

### Custom Plugin

```ruby
class MyPlugin < Kotoshu::Plugins::Plugin
  plugin_name :my_plugin
  dependencies [:spellchecker]
  provides [:custom_feature]

  def before_start
    # Initialize
  end
end
```

## Thread Safety

- **Configuration**: Immutable after creation (frozen)
- **Cache**: Thread-safe with proper synchronization
- **Dictionary**: Read-only after initialization
- **ParallelChecker**: Mutex-protected results array
- **BloomFilter**: Thread-safe for reads

## Error Handling

Kotoshu uses a hierarchical exception system:

```
Kotoshu::Error
├── DictionaryNotFoundError
├── InvalidDictionaryFormatError
├── ConfigurationError
└── SpellcheckError
```

For business logic errors, Kotoshu uses the Result pattern:

```ruby
result = operation()
result.success? ? handle(result.value) : recover(result.error)
```

## Future Enhancements

1. **L1 Cache**: CPU cache-aware data structures
2. **SIMD**: Vectorized edit distance calculation
3. **Compression**: Dictionary compression (DAFSA)
4. **Incremental**: Dynamic dictionary updates
5. **Distributed**: Redis-backed cache for multi-process
