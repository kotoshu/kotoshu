# Kotoshu Architecture Improvements Plan

## Executive Summary

This document outlines the complete architecture improvement plan for Kotoshu spellchecker library. All improvements follow these core principles:

**Core Principles (Never Violate):**
- ✅ NO test code in production
- ✅ NO mocks/doubles - use real data
- ✅ NO VCR/fake HTTP - use real files or network
- ✅ Clean separation of concerns
- ✅ MECE organization
- ✅ Full test coverage (TDD always)

## Implementation Order

### Phase 1: Performance Foundations (Week 1-2)
- SymSpell algorithm
- Three-tier caching
- Bloom filter
- Performance benchmarks

### Phase 2: Architecture Cleanliness (Week 3-4)
- Immutable Configuration Builder
- Result Pattern for error handling
- Plugin System with DI
- Pipeline System

### Phase 3: User Experience (Week 5)
- Sensible defaults
- Personal Dictionary
- Project Configuration
- Fluent API

### Phase 4: Code Quality (Week 6)
- Complete RBS Type Signatures
- Performance Regression Tests
- Property-Based Tests
- Documentation Suite

### Phase 5: Polish & Monitoring (Week 7)
- Debug Mode
- Metrics/Instrumentation
- Examples Update
- Final Testing

## Detailed Checklist

### PHASE 1: PERFORMANCE FOUNDATIONS (Week 1-2)

#### 1.1 SymSpell Algorithm Implementation
**File:** `lib/kotoshu/suggestions/strategies/symspell_strategy.rb`

**Acceptance Criteria:**
- [ ] SymSpellStrategy class created
- [ ] Pre-computes deletion dictionary
- [ ] `suggest` method finds suggestions in < 1ms for 100K word dict
- [ ] Benchmark: 10-100x faster than EditDistanceStrategy
- [ ] Tests: spec/kotoshu/suggestions/strategies/symspell_strategy_spec.rb
- [ ] Tests: spec/benchmark/symspell_benchmark_spec.rb

**Implementation Details:**
```ruby
class SymSpellStrategy < BaseStrategy
  def initialize(dictionary, max_dictionary_size: 100_000)
    @dictionary = dictionary
    @max_dictionary_size = max_dictionary_size
    @deletes = Hash.new { |h, k| [] }  # word -> [deletion, word]
    @lookup = Set.new
    precompute!
  end

  def precompute!
    # Generate all possible deletions for each word
    # Use frequency-based approach for better suggestions
  end

  def generate(context)
    # Find suggestions using deletion distance
  end
end
```

#### 1.2 Three-Tier Caching System
**Files:**
- `lib/kotoshu/cache/cache.rb` (base cache interface)
- `lib/kotoshu/cache/lookup_cache.rb` (L1: in-memory)
- `lib/kotoshu/cache/suggestion_cache.rb` (L2: suggestions)
- `lib/kotoshu/cache/dictionary_cache.rb` (L3: file cache)

**Acceptance Criteria:**
- [ ] Cache interface defined
- [ ] LookupCache: LRU cache with 1000 entries
- [ ] SuggestionCache: LRU cache with 5000 entries
- [ ] DictionaryCache: Disk cache with TTL
- [ ] Cache statistics: hit_rate, misses, size
- [ ] Tests: spec/kotoshu/cache/*_spec.rb
- [ ] Benchmark: 100x speedup for repeated lookups

**Cache Stats:**
```ruby
Kotoshu.cache.stats
#=> {lookups: 10000, hits: 8500, hit_rate: 0.85}
```

#### 1.3 Bloom Filter for Fast Rejection
**File:** `lib/kotoshu/data_structures/bloom_filter.rb`

**Acceptance Criteria:**
- [ ] BloomFilter class created
- [ ] Configurable false positive rate (default 1%)
- [ ] Instant "definitely not in dictionary" responses
- [ ] 95% of negative lookups become O(1)
- [ ] Tests: spec/kotoshu/data_structures/bloom_filter_spec.rb
- [ ] Integrated into Dictionary::Base lookup

#### 1.4 Parallel File Checking
**File:** `lib/kotoshu/spellchecker/parallel_checker.rb`

**Acceptance Criteria:**
- [ ] ParallelChecker class
- [ ] Configurable worker count (default: 4)
- [ ] Thread-safe file processing
- [ ] `check_files_parallel` method
- [ ] 4x speedup on 4-core machines
- [ ] Tests: spec/kotoshu/spellchecker/parallel_spec.rb

#### 1.5 Performance Benchmark Suite
**Directory:** `spec/benchmark/`

**Acceptance Criteria:**
- [ ] SymSpell benchmark vs EditDistance
- [ ] Cache hit rate benchmarks
- [ ] Bloom filter benchmarks
- [ ] Parallel vs sequential file checking
- [ ] Before/after performance reports
- [ ] All benchmarks have minimum performance assertions

---

### PHASE 2: ARCHITECTURE CLEANELINESS (Week 3-4)

#### 2.1 Immutable Configuration Builder
**Files:**
- `lib/kotoshu/configuration/builder.rb`
- `lib/kotoshu/configuration.rb` (refactor to immutable)

**Acceptance Criteria:**
- [ ] Configuration::Builder class
- [ ] `Configuration.build { |c| ... }` API
- [ ] Configuration objects are frozen
- [ ] Thread-safe concurrent use
- [ ] Backward compatible with existing API
- [ ] Tests: spec/kotoshu/configuration/builder_spec.rb
- [ ] Update examples to use builder

**API:**
```ruby
config = Kotoshu::Configuration.build do |c|
  c.dictionary_path = "words.txt"
  c.language = "en-US"
  c.max_suggestions = 10
end
# config is frozen
```

#### 2.2 Result Pattern for Error Handling
**Files:**
- `lib/kotoshu/results/result.rb` (base Result)
- `lib/kotoshu/results/success.rb`
- `lib/kotoshu/results/failure.rb`
- `lib/kotoshu/results/check_word_result.rb` (refactor)

**Acceptance Criteria:**
- [ ] Result::Success and Result::Failure classes
- [ ] `success?` and `failure?` methods
- [ ] `value` method returns wrapped value or error
- [ ] `map`, `and_then`, `or_else` methods
- [ ] All error paths use Result pattern
- [ ] Tests: spec/kotoshu/results/*_spec.rb
- [ ] No exceptions for expected failures

**API:**
```ruby
result = spellchecker.check_word("word")
result.is_a?(Result::Success) or result.is_a?(Result::Failure)
result.success? # => true/false
result.value # => WordResult or Error

result.and_then { |r| process(r) }
result.or_else { |error| handle_error(error) }
```

#### 2.3 Plugin System with Dependency Injection
**Files:**
- `lib/kotoshu/plugins/plugin.rb` (base plugin)
- `lib/kotoshu/plugins/registry.rb` (plugin registry)
- `lib/kotoshu/plugins/dependency_injection.rb`

**Acceptance Criteria:**
- [ ] Plugin base class with lifecycle hooks
- [ ] `depends_on` for declaring dependencies
- [ ] `provides` for declaring provided services
- [ ] Automatic dependency resolution
- [ ] `Kotoshu::Plugins.register` API
- [ ] Tests: spec/kotoshu/plugins/*_spec.rb
- [ ] Example: Custom suggestion plugin

**API:**
```ruby
class MyAlgorithm < Kotoshu::Plugins::Plugin
  plugin :my_algorithm do
    depends_on :dictionary
    provides :suggestions

    def initialize(dictionary:)
      @dictionary = dictionary
    end

    def suggest(word, **opts)
      # Implementation
    end
  end
end
```

#### 2.4 Pipeline System for Suggestions
**Files:**
- `lib/kotoshu/suggestions/pipeline.rb`
- `lib/kotoshu/suggestions/stages/` (pipeline stages)

**Acceptance Criteria:**
- [ ] Pipeline class with add/remove stages
- [ ] Stages execute in sequence, can early terminate
- [ ] Shared context object for stage communication
- [ ] `Kotoshu.suggestion_pipeline` API
- [ ] Tests: spec/kotoshu/suggestions/pipeline_spec.rb
- [ ] Example: Custom pipeline

**API:**
```ruby
pipeline = Kotoshu::Suggestion::Pipeline.new do |pipe|
  pipe.add :sym_spell
  pipe.add :phonetic
  pipe.add :ngram
end
```

---

### PHASE 3: USER EXPERIENCE (Week 5)

#### 3.1 Sensible Defaults with Auto-Detection
**Files:**
- `lib/kotoshu/defaults.rb`
- `lib/kotoshu/spellchecker.rb` (update)

**Acceptance Criteria:**
- [ ] `Kotoshu.correct?("hello")` works without configuration
- [ ] Auto-detect system dictionary if available
- [ ] Fall back to bundled dictionary
- [ ] Tests: spec/kotoshu/defaults_spec.rb

#### 3.2 Personal Dictionary with Persistence
**Files:**
- `lib/kotoshu/personal_dictionary.rb`
- `lib/kotoshu/personal_dictionary/persistence.rb`

**Acceptance Criteria:**
- [ ] PersonalDictionary class
- [ ] `~/.kotoshu/personal.dic` storage
- [ ] Hunspell-compatible format
- [ ] `Kotoshu.add_personal_word(word)` API
- [ ] `Kotoshu.personal_words` list
- [ ] Thread-safe
- [ ] Tests: spec/kotoshu/personal_dictionary_spec.rb

**API:**
```ruby
Kotoshu.add_personal_word("Kotoshu")
Kotoshu.personal_words # => ["Kotoshu", ...]
Kotoshu.ignore_personal_word("Kotoshu")
```

#### 3.3 Project Configuration
**Files:**
- `lib/kotoshu/project_config.rb`
- `lib/kotoshu/project_config/loader.rb`

**Acceptance Criteria:**
- [ ] `.kotoshu` configuration file format
- [ ] Auto-discovery up directory tree
- [ ] `ignore_words` list support
- [ ] `ignore_patterns` regex support
- [ ] Tests: spec/kotoshu/project_config_spec.rb
- [ ] Test fixtures: spec/fixtures/projects/.kotoshu

**Format:**
```yaml
# .kotoshu
dictionary: en-GB
ignore_words:
  - github
  - api
ignore_patterns:
  - /https?:\/\/\S+/
  - /\w+@\w+\.\w+/
```

#### 3.4 Fluent API for Checking
**File:** `lib/kotoshu/fluent_checker.rb`

**Acceptance Criteria:**
- [ ] FluentChecker class
- [ ] Chainable configuration methods
- [ ] Progress callbacks
- [ - Error handling callbacks
- [ ] Tests: spec/kotoshu/fluent_checker_spec.rb

**API:**
```ruby
Kotoshu.fluent.check(text)
  .ignore_words(/https?:\/\/\S+/)
  .max_suggestions(5)
  .on_error { |err| puts err.word }
  .result
```

---

### PHASE 4: CODE QUALITY (Week 6)

#### 4.1 Complete RBS Type Signatures
**Directory:** `sig/kotoshu/`

**Acceptance Criteria:**
- [ ] Complete RBS for all public classes
- [ ] RBS for all public methods
- [ ] Run `steep` or `typeprof` to verify
- [ ] Fix all type errors
- [ ] IDE autocomplete improved
- [ ] Tests: Test type-checker with type specs

#### 4.2 Performance Regression Tests
**Directory:** `spec/performance/`

**Acceptance Criteria:**
- [ ] Lookup performance tests
- [ ] Suggestion performance tests
- [ ] Cache effectiveness tests
- [ ] `perform_faster_than` assertions
- [ ] CI runs performance tests
- [ ] Alert on performance regression

#### 4.3 Property-Based Tests
**File:** `Gemfile` (add `gem "rspec-parameterized"`)

**Acceptance Criteria:**
- [ ] Property: `lookup(word) == lookup(word.downcase)` for insensitive dicts
- [ ] Property: `lookup?(w) == false` after `add_word(w)`
- [ ] Property: Cache size grows until max, then evicts
- [ ] Properties for suggestion quality
- [ ] CI runs property tests weekly

#### 4.4 Documentation Suite
**Files:**
- `ARCHITECTURE.md` - System design
- `GETTING_STARTED.md` - Tutorial
- `API.md` - API reference (YARD output)
- `CONTRIBUTING.md` - Extension guide
- `PERFORMANCE.md` - Optimization guide
- `PLUGINS.md` - Plugin development
- `README.adoc` - Update with new features

**Acceptance Criteria:**
- [ ] All docs written
- [ ] Architecture diagrams included
- [ ] Code examples in docs
- [ ] API docs complete from YARD
- [ ] Contributing guide has examples
- [ ] All docs pass prose linter

---

### PHASE 5: POLISH & MONITORING (Week 7)

#### 5.1 Debug Mode
**Files:**
- `lib/kotoshu/debug.rb`
- `lib/kotoshu/debug/logger.rb`

**Acceptance Criteria:**
- [ ] `Kotoshu.debug = true` enables debug output
- [ ] Shows lookup times, suggestion scores
- [ ] Shows decision tree for suggestions
- [ ] Tests: spec/kotoshu/debug_spec.rb
- [ ] Example: examples/08_debug_mode.rb

#### 5.2 Metrics/Instrumentation
**Files:**
- `lib/kotoshu/metrics.rb`
- `lib/kotoshu/metrics/collector.rb`

**Acceptance Criteria:**
- [ ] `Kotoshu::Metrics.enable` starts collection
- [ ] Tracks: lookups, cache hits, suggestion counts
- [ ] Thread-safe metrics collection
- [ ] StatsD/Prometheus optional output
- [ ] Tests: spec/kotoshu/metrics_spec.rb
- [ ] Example: examples/09_metrics.rb

#### 5.3 Examples Update
**Files:**
- Update existing examples with new features
- Add examples/08_debug_mode.rb
- Add examples/09_metrics.rb

**Acceptance Criteria:**
- [ ] All examples work with new architecture
- [ ] Show Configuration::Builder usage
- [ ] Show Result pattern usage
- [ ] Show personal dictionary usage
- [ ] Show project config usage

#### 5.4 Final Testing & Validation
**Acceptance Criteria:**
- [ ] All 197 + new tests passing
- [ ] Coverage > 80%
- [ ] All benchmarks meet performance targets
- [ ] CI passes on all Ruby versions
- [ ] Examples run without errors
- [ ] Documentation complete

---

## Success Metrics

### Performance Targets
- Lookup: < 0.001ms for cached lookups
- Suggestions: < 0.01ms for common misspellings
- File checking: 4x faster with parallel mode
- Memory: < 100MB for loaded dictionary

### Quality Targets
- Coverage: > 80%
- All benchmarks meet minimum performance
- Zero test code in production
- Zero production code dependencies on test frameworks

### Usability Targets
- Sensible defaults work without configuration
- Fluent API for complex use cases
- Easy to extend with plugins
- Clear error messages

---

## Implementation Schedule

| Week | Focus | Deliverables | Tests |
|------|-------|-------------|-------|
| 1 | SymSpell | Algorithm + benchmarks | 8 tests + 2 benchmarks |
| 1 | Caching | 3 cache layers + stats | 12 tests + 2 benchmarks |
| 1 | Bloom Filter | Data structure + integration | 10 tests |
| 2 | Parallel | ParallelChecker + thread safety | 8 tests |
| 3 | Config | Immutable builder | 15 tests |
| 3 | Results | Result pattern | 20 tests |
| 3 | Plugins | Plugin system + DI | 25 tests |
| 3 | Pipelines | Pipeline system | 15 tests |
| 4 | Defaults | Auto-detection | 10 tests |
| 4 | Personal Dict | Persistence + API | 12 tests |
| 4 | Project Config | Loader + format | 15 tests |
| 4 | Fluent API | FluentChecker | 12 tests |
| 5 | RBS | Complete signatures | Run type-checker |
| 5 | Benchmarks | Performance regression | 15 tests |
| 5 | Property Tests | RSpec-parameterized | 20 tests |
| 6 | Debug Mode | Debug logging | 10 tests |
| 6 | Metrics | Collection + output | 10 tests |
| 6 | Documentation | All docs written | N/A |
| 7 | Polish | Examples + validation | All pass |

---

## Risk Mitigation

**Risks:**
1. Performance regressions
   - **Mitigation:** Performance regression tests prevent this
2. Breaking changes
   - **Mitigation:** Deprecation warnings, maintain backward compatibility
3. Thread safety issues
   - **Mitigation:** Immutable objects, thread-local caches
4. Test suite becoming too slow
   - **Mitigation:** Tag tests by speed (:fast, :slow), run :slow tests separately

---

## Next Steps

1. Review and approve this plan
2. I will create tasks for Phase 1 (SymSpell, Caching, Bloom Filter)
3. Begin TDD implementation following the checklist
4. Each feature: RED (failing test) → GREEN (minimal impl) → REFACTOR
5. Commit after each working feature
6. Monitor CI after each push
