# Kotoshu Solidification Plan (OOP-Compliant)

**Status**: Draft - OOP Architecture Review Complete
**Last Updated**: 2025-01-29
**Progress**: 0/50 items (0%)

## Architecture Principles

This plan follows these OOP and model-driven architecture principles:

**1. Polymorphism Over Configuration**
- Use inheritance and polymorphism instead of configuration switches
- Create subclasses for different behaviors, not flags to enable/disable
- Example: `CharFlag`, `NumericFlag`, `LongFlag` classes, not `flag_type` config

**2. Models First, Algorithms Second**
- Create domain models that represent the problem space
- Algorithms and strategies operate ON models, not instead of them
- Example: `CharacterMapping` model + `CharacterMappingStrategy` (uses model)

**3. Value Objects for Primitives**
- Wrap primitives (strings, numbers) in value objects with behavior
- Example: `EditCost`, `Token`, `NGram`, `Language`, `CacheEntry` are classes

**4. Separation of Concerns**
- **Models**: Domain entities (Word, AffixRule, CompoundRule, etc.)
- **Value Objects**: Immutable concepts (Token, EditCost, NGram, etc.)
- **Services**: Use cases and workflows (Spellchecker, CompoundValidator, etc.)
- **Strategies**: Interchangeable algorithms (EditDistanceStrategy, etc.)
- **Factories/Builders**: Construction logic (DictionaryBuilder, etc.)

**5. Composition Over Delegation**
- Use composition to combine behaviors
- Example: `AffixRule` composes `CharacterMapping`, not contains mapping logic

**6. Query Methods on Objects**
- Objects have behavior, not just data
- Example: `word.can_stand_alone?` not `check_flag(word, :needaffix)`

---

## Executive Summary

This document outlines all feature gaps and performance gaps between Kotoshu and reference implementations (Hunspell, LanguageTool, CSpell). Each gap uses a fully OOP, model-driven approach.

**Goal**: Feature parity with Hunspell + performance parity with CSpell, using pure OOP.

**Current State**:
- ✅ Basic dictionary backends (UnixWords, PlainText, Custom, Hunspell, CSpell)
- ✅ Core suggestion algorithms (EditDistance, Phonetic, KeyboardProximity, NGram)
- ✅ Trie and IndexedDictionary data structures
- ✅ CLI interface with Thor
- ✅ Configuration system
- ✅ Result objects (WordResult, DocumentResult)

**Reference Implementations**:
- Hunspell: `/Users/mulgogi/src/external/hunspell/`
- CSpell: `/Users/mulgogi/src/external/cspell/`
- LanguageTool: `/Users/mulgogi/src/external/languagetool/`

---

## Legend

**Complexity**:
- **LOW**: 1-2 hours
- **MEDIUM**: 4-8 hours
- **HIGH**: 2-5 days

**Priority**:
- **CRITICAL**: Blocks core functionality
- **HIGH**: Feature parity requirement
- **MEDIUM**: User experience improvement
- **LOW**: Future enhancement

**Architecture Components**:
- **MODEL**: Domain model class
- **VALUE**: Value object (immutable)
- **SERVICE**: Use case/orchestrator
- **STRATEGY**: Pluggable algorithm
- **FACTORY**: Construction logic

---

## Part 1: Hunspell Feature Gaps (Model-Driven)

**Status**: 0/15 items (0%)

### 1.1 Advanced FLAG Modes (Polymorphism)

**OOP Issue**: Current plan uses `flag_type` configuration - should use polymorphism.

**Model-Driven Design**:
```
Flag (abstract MODEL)
├── CharFlag (MODEL): Single character flag
├── NumericFlag (MODEL): Numeric flag (123, 456)
└── LongFlag (MODEL): Multi-character flag (ABC, DEF)
```

- [ ] #1: Flag model hierarchy (COMPLEXITY: MEDIUM, PRIORITY: HIGH)
  - [ ] Analysis: Study Hunspell FLAG types in affixmgr.hxx
  - [ ] Design: Create abstract `Flag` base MODEL
  - [ ] Design: Create `CharFlag`, `NumericFlag`, `LongFlag` MODELs
  - [ ] Implement: `Flag.parse(string)` factory method
  - [ ] Implement: `Flag#matches?(other_flag)` polymorphic method
  - [ ] Implement: `CharFlag#to_char`, `NumericFlag#to_i`, `LongFlag#to_s`
  - [ ] Test: Spec for each Flag subclass
  - [ ] Test: Spec for polymorphic matching
  - [ ] Document: Flag model architecture

- [ ] #2: FlagCollection VALUE object (COMPLEXITY: LOW, PRIORITY: HIGH)
  - [ ] Design: `FlagCollection` VALUE (immutable set of flags)
  - [ ] Implement: `FlagCollection#include?(flag)` uses polymorphic matching
  - [ ] Implement: `FlagCollection#intersection(other)`
  - [ ] Implement: AffixRule uses FlagCollection (not raw array)
  - [ ] Test: Spec for FlagCollection operations
  - [ ] Document: FlagCollection VALUE

### 1.2 Cross-Product Affix Models

**OOP Issue**: Current plan uses "tracking" - should create models for affix combinations.

**Model-Driven Design**:
```
AffixCombination (MODEL): Represents prefix+suffix pair
├── prefix_rule: AffixRule
├── suffix_rule: AffixRule
└── valid_combination?: Boolean

AffixCombinationRegistry (MODEL): Manages valid combinations
AffixApplication (VALUE): Single application result
```

- [ ] #3: Cross-product affix models (COMPLEXITY: HIGH, PRIORITY: HIGH)
  - [ ] Analysis: Study AffixMgr cross_product logic
  - [ ] Design: `AffixCombination` MODEL (prefix_rule + suffix_rule)
  - [ ] Design: `AffixCombinationRegistry` MODEL
  - [ ] Design: `AffixApplication` VALUE (word + applied_rule + result)
  - [ ] Implement: `AffixCombination#apply_to(word)` method
  - [ ] Implement: `AffixCombinationRegistry#valid_combinations_for(rule)`
  - [ ] Implement: Memoization in registry (not in affix rule)
  - [ ] Test: Spec for AffixCombination
  - [ ] Test: Spec for AffixCombinationRegistry
  - [ ] Document: Cross-product model architecture

### 1.3 SuggestMgr Domain Models

**OOP Issue**: Current plan implements strategies directly - should create models FIRST.

**Model-Driven Design**:
```
# Character Mapping (Domain Models)
CharacterMapping (MODEL): Maps "ph" -> "f"
├── from_pattern: String
├── to_char: String
└── apply(word): String

CharacterMappingRegistry (MODEL): Manages all mappings

# Replacement Rules (Domain Models)
ReplacementRule (MODEL): Pattern -> replacement
├── pattern: Regex/String
├── replacement: String
├── context: Proc/lambda
└── apply(word): String?

ReplacementRuleRegistry (MODEL): Manages REP rules

# NGram (Domain Models + reused elsewhere)
NGram (VALUE): N-character sequence
├── chars: String
├── size: Integer
└── similarity_to(other): Float

NGramIndex (MODEL): NGram -> words mapping
```

- [ ] #4: CharacterMapping MODEL (COMPLEXITY: MEDIUM, PRIORITY: HIGH)
  - [ ] Analysis: Study MAP entries in .aff file
  - [ ] Design: `CharacterMapping` MODEL
  - [ ] Design: `CharacterMappingRegistry` MODEL
  - [ ] Implement: Parse MAP from .aff into CharacterMapping MODELs
  - [ ] Implement: `CharacterMapping#apply_to(word)` method
  - [ ] Implement: `CharacterMappingRegistry#applicable_to(word)`
  - [ ] Implement: `CharacterMappingStrategy` uses CharacterMapping MODELs
  - [ ] Test: Spec for CharacterMapping
  - [ ] Test: Spec for CharacterMappingRegistry
  - [ ] Test: Spec for strategy (integration test)
  - [ ] Document: Character mapping architecture

- [ ] #5: ReplacementRule MODEL (COMPLEXITY: MEDIUM, PRIORITY: HIGH)
  - [ ] Analysis: Study REP entries in .aff file
  - [ ] Design: `ReplacementRule` MODEL
  - [ ] Design: `ReplacementRuleRegistry` MODEL
  - [ ] Implement: Parse REP from .aff into ReplacementRule MODELs
  - [ ] Implement: `ReplacementRule#apply_to(word)` method
  - [ ] Implement: `ReplacementRule#matches_context?(word)` method
  - [ ] Implement: `ReplacementStrategy` uses ReplacementRule MODELs
  - [ ] Test: Spec for ReplacementRule
  - [ ] Test: Spec for ReplacementRuleRegistry
  - [ ] Test: Spec for strategy (integration test)
  - [ ] Document: Replacement rule architecture

- [ ] #6: NGram VALUE and NGramIndex MODEL (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Analysis: Study NGram algorithms in SuggestMgr
  - [ ] Design: `NGram` VALUE (n-character sequence)
  - [ ] Design: `NGramIndex` MODEL (NGram -> word set)
  - [ ] Implement: `NGram#similarity_to(other)` method
  - [ ] Implement: `NGram#jaccard_similarity(other)` method
  - [ ] Implement: `NGramIndexBuilder` SERVICE
  - [ ] Implement: `NGramIndex#lookup(word)` returns similar words
  - [ ] Implement: `NGramStrategy` uses NGram MODELs
  - [ ] Test: Spec for NGram VALUE
  - [ ] Test: Spec for NGramIndex MODEL
  - [ ] Test: Spec for NGramStrategy (integration)
  - [ ] Document: NGram architecture

### 1.4 ForbiddenWord Model (NOSUGGEST)

**OOP Issue**: Current plan uses "nosuggest_words config" - should create model.

**Model-Driven Design**:
```
ForbiddenWord (MODEL, inherits from Word)
├── reason: String
├── category: Symbol (:profanity, :offensive, :deprecated)
└── forbidden?: true (polymorphic)

ForbiddenWordRegistry (MODEL)
ForbiddenWordError (Exception, inherits from SpellcheckError)
```

- [ ] #7: ForbiddenWord MODEL (COMPLEXITY: LOW, PRIORITY: MEDIUM)
  - [ ] Analysis: Study NOSUGGEST flag handling
  - [ ] Design: `ForbiddenWord` MODEL (inherits from Word)
  - [ ] Design: `ForbiddenWordRegistry` MODEL
  - [ ] Design: `ForbiddenWordError` Exception class
  - [ ] Implement: Parse NOSUGGEST from .aff into ForbiddenWord MODELs
  - [ ] Implement: `Word#forbidden?` query method (false in base, true in subclass)
  - [ ] Implement: `ForbiddenWordRegistry#include?(word)`
  - [ ] Implement: Spellchecker checks `word.forbidden?` (polymorphic)
  - [ ] Test: Spec for ForbiddenWord MODEL
  - [ ] Test: Spec for ForbiddenWordRegistry
  - [ ] Test: Spec for ForbiddenWordError
  - [ ] Document: Forbidden word model

### 1.5 CircumfixRule Model

**OOP Issue**: Current plan creates "CircumfixStrategy" - should create model for relationship.

**Model-Driven Design**:
```
CircumfixRule (MODEL): Links prefix_rule + suffix_rule
├── prefix_rule: AffixRule
├── suffix_rule: AffixRule
├── required_pattern: Regex
└── applicable_to?(word): Boolean

CircumfixApplier (SERVICE): Orchestrates circumfix application
```

- [ ] #8: CircumfixRule MODEL (COMPLEXITY: HIGH, PRIORITY: MEDIUM)
  - [ ] Analysis: Study circumfix rules in affixmgr.cxx
  - [ ] Design: `CircumfixRule` MODEL (composition of prefix + suffix rules)
  - [ ] Design: `CircumfixApplier` SERVICE
  - [ ] Implement: Parse circumfix patterns from .aff
  - [ ] Implement: `CircumfixRule#applicable_to?(word)` method
  - [ ] Implement: `CircumfixRule#apply_to(word)` method
  - [ ] Implement: `CircumfixStrategy` uses CircumfixRule MODELs
  - [ ] Test: Spec for CircumfixRule MODEL
  - [ ] Test: Spec for CircumfixApplier SERVICE
  - [ ] Document: Circumfix model architecture

### 1.6 Compound Word Models

**OOP Issue**: Current plan uses "compound_min config" - should encapsulate in models.

**Model-Driven Design**:
```
CompoundRule (MODEL): Defines compound formation rules
├── min_parts: Integer (NOT in config)
├── valid_patterns: Array<Regex>
├── max_parts: Integer
└── valid_compound?(parts): Boolean

CompoundWord (MODEL): Word that exists ONLY in compounds
├── word: String
└── can_stand_alone?: false (polymorphic override)

CompoundPart (VALUE): One segment of a compound
├── text: String
├── position: Integer
└── valid_prefix?: Boolean

CompoundValidator (SERVICE): Validates compound formations
CompoundBuilder (SERVICE): Builds valid compounds from parts
```

- [ ] #9: CompoundRule MODEL (COMPLEXITY: HIGH, PRIORITY: HIGH)
  - [ ] Analysis: Study COMPOUNDRULE format in .aff
  - [ ] Design: `CompoundRule` MODEL with min_parts as instance variable
  - [ ] Implement: Parse COMPOUNDRULE into CompoundRule MODEL
  - [ ] Implement: `CompoundRule#valid_compound?(parts)` method
  - [ ] Implement: `CompoundRule#min_parts` query method (not config lookup)
  - [ ] Test: Spec for CompoundRule MODEL
  - [ ] Test: Spec for compound validation logic
  - [ ] Document: Compound rule model

- [ ] #10: CompoundWord MODEL (COMPLEXITY: MEDIUM, PRIORITY: HIGH)
  - [ ] Analysis: Study ONLYINCOMPOUND flag handling
  - [ ] Design: `CompoundWord` MODEL (inherits from Word)
  - [ ] Implement: Parse ONLYINCOMPOUND from .aff into CompoundWord MODEL
  - [ ] Implement: `Word#can_stand_alone?` (true in base, false in CompoundWord)
  - [ ] Implement: Dictionary checks `word.can_stand_alone?` (polymorphic)
  - [ ] Test: Spec for CompoundWord MODEL
  - [ ] Test: Spec for polymorphic can_stand_alone?
  - [ ] Document: Compound word model

- [ ] #11: CompoundPart VALUE and CompoundValidator SERVICE (COMPLEXITY: MEDIUM, PRIORITY: HIGH)
  - [ ] Analysis: Study compound validation in affixmgr.cxx
  - [ ] Design: `CompoundPart` VALUE (immutable segment)
  - [ ] Design: `CompoundValidator` SERVICE
  - [ ] Design: `CompoundBuilder` SERVICE
  - [ ] Implement: `CompoundPart#text`, `#position`, `#valid_prefix?` methods
  - [ ] Implement: `CompoundValidator#valid_compound?(parts, rule)`
  - [ ] Implement: `CompoundBuilder#build(parts, rule)` returns compound
  - [ ] Test: Spec for CompoundPart VALUE
  - [ ] Test: Spec for CompoundValidator SERVICE
  - [ ] Test: Spec for CompoundBuilder SERVICE
  - [ ] Document: Compound part model and services

### 1.7 Morphological Analysis Models

**OOP Issue**: Current plan focuses on "stem extraction algorithm" - should create models.

**Model-Driven Design**:
```
WordForm (MODEL): Specific form of a word
├── text: String
├── stem: Stem
├── affixes: Array<Affix>
└── complete_form?: Boolean

Stem (MODEL): Base/canonical form of a word
├── text: String
├── canonical?: Boolean
└── forms: Array<WordForm>

AffixApplication (VALUE): Record of applied affix
├── affix: AffixRule
├── position: Integer
└── transformed_to: String

MorphologicalAnalysis (VALUE): Result of morphological analysis
├── stem: Stem
├── applied_affixes: Array<AffixApplication>
├── confidence: Float
└── to_s: String representation

Stemmer (INTERFACE): Strategy for stemming algorithms
├── HunspellStemmer (IMPLEMENTATION)
├── StatisticalStemmer (IMPLEMENTATION)
└── stem(word): MorphologicalAnalysis
```

- [ ] #12: Morphological analysis MODELs (COMPLEXITY: HIGH, PRIORITY: MEDIUM)
  - [ ] Analysis: Study AffixMgr::strip_suffix() and morphological methods
  - [ ] Design: `WordForm` MODEL
  - [ ] Design: `Stem` MODEL
  - [ ] Design: `AffixApplication` VALUE
  - [ ] Design: `MorphologicalAnalysis` VALUE
  - [ ] Design: `Stemmer` INTERFACE
  - [ ] Implement: `WordForm#stem` method returns Stem
  - [ ] Implement: `WordForm#affixes` method returns AffixApplication array
  - [ ] Implement: `HunspellStemmer` implements Stemmer INTERFACE
  - [ ] Implement: `Word#analyze_morphology` returns MorphologicalAnalysis
  - [ ] Test: Spec for WordForm MODEL
  - [ ] Test: Spec for Stem MODEL
  - [ ] Test: Spec for MorphologicalAnalysis VALUE
  - [ ] Test: Spec for HunspellStemmer
  - [ ] Document: Morphological model architecture

### 1.8 Continuation and DependentWord Models

**OOP Issue**: Current plan uses "multi-step affix application" and validation - should create models.

**Model-Driven Design**:
```
AffixSequence (MODEL): Ordered list of affixes to apply
├── affixes: Array<AffixRule>
├── must_apply_in_order: Boolean
└── apply_to(word): String

ContinuationFlag (VALUE): Marks rule as chainable
├── flag: Flag
└── chainable?: true

DependentWord (MODEL, inherits from Word): Requires affixes
├── required_affixes: Array<Flag>
└── can_stand_alone?: false (polymorphic)

AffixApplier (SERVICE): Applies affix sequences (not individual rules)
```

- [ ] #13: Continuation models (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Analysis: Study CONTINUE flag in .aff
  - [ ] Design: `AffixSequence` MODEL
  - [ ] Design: `ContinuationFlag` VALUE
  - [ ] Implement: Parse CONTINUE from .aff
  - [ ] Implement: `AffixRule#continuation?` query method
  - [ ] Implement: `AffixSequence` builds from continuation flags
  - [ ] Implement: `AffixApplier#apply_sequence(word, sequence)`
  - [ ] Test: Spec for AffixSequence MODEL
  - [ ] Test: Spec for ContinuationFlag VALUE
  - [ ] Test: Spec for AffixApplier SERVICE
  - [ ] Document: Continuation model architecture

- [ ] #14: DependentWord MODEL (COMPLEXITY: LOW, PRIORITY: MEDIUM)
  - [ ] Analysis: Study NEEDAFFIX flag in .aff
  - [ ] Design: `DependentWord` MODEL (inherits from Word)
  - [ ] Implement: Parse NEEDAFFIX from .aff into DependentWord MODEL
  - [ ] Implement: `Word#can_stand_alone?` (true in base, false in DependentWord)
  - [ ] Implement: Dictionary checks polymorphic `can_stand_alone?`
  - [ ] Test: Spec for DependentWord MODEL
  - [ ] Test: Spec for polymorphic validation
  - [ ] Document: Dependent word model

- [ ] #15: AffixRule query methods (COMPLEXITY: LOW, PRIORITY: MEDIUM)
  - [ ] Analysis: Review AffixRule MODEL methods
  - [ ] Implement: `AffixRule#continuation?` query method
  - [ ] Implement: `AffixRule#cross_product?` query method
  - [ ] Implement: `AffixRule#first_character` method (for indexing)
  - [ ] Implement: `AffixRule#applicable_to?(word)` method
  - [ ] Test: Spec for all AffixRule query methods
  - [ ] Document: AffixRule MODEL API

---

## Part 2: CSpell Feature Gaps (Model-Driven)

**Status**: 0/6 items (0%)

### 2.1 DAFSA Trie Models (Polymorphism)

**OOP Issue**: Current plan uses "hybrid mode" - should use polymorphism.

**Model-Driven Design**:
```
TrieNode (abstract MODEL)
├── StandardTrieNode (MODEL): Current implementation
└── DAFSANode (MODEL): Compressed/minimized node
    ├── merged_children: Boolean
    └── minimization_id: Integer

Trie (abstract class, uses TrieNode polymorphically)
TrieBuilder (FACTORY): Creates appropriate trie

TrieOptimizer (SERVICE): Converts StandardTrie -> DAFSA
├── minimize(node): DAFSANode
└── find_merge_candidates(node): Array<Node>
```

- [ ] #16: TrieNode polymorphism (COMPLEXITY: HIGH, PRIORITY: HIGH)
  - [ ] Analysis: Study CSpell TrieBuilder and DAFSA algorithm
  - [ ] Design: Abstract `TrieNode` base MODEL
  - [ ] Design: `StandardTrieNode` subclass (current implementation)
  - [ ] Design: `DAFSANode` subclass (compressed)
  - [ ] Implement: Refactor current trie to use StandardTrieNode
  - [ ] Implement: DAFSA minimization algorithm in DAFSANode
  - [ ] Implement: `Trie` accepts any TrieNode subclass (polymorphic)
  - [ ] Implement: `TrieBuilder` FACTORY creates appropriate type
  - [ ] Implement: `TrieOptimizer` SERVICE for conversion
  - [ ] Test: Spec for StandardTrieNode
  - [ ] Test: Spec for DAFSANode
  - [ ] Test: Spec for polymorphic Trie behavior
  - [ ] Test: Benchmark memory usage
  - [ ] Document: Trie node polymorphism architecture

### 2.2 Weighted Edit Distance Models

**OOP Issue**: Current plan uses "weight matrix" - should create models.

**Model-Driven Design**:
```
EditCost (VALUE): Encapsulates cost calculation
├── from_char: String
├── to_char: String
├── cost: Float
└── on_layout(keyboard_layout): EditCost

KeyboardLayout (MODEL): Represents physical keyboard
├── layout_type: Symbol (:qwerty, :azerty, :dvorak)
├── key_position(char): {row, col}
├── distance(char1, char2): Float
└── adjacent_keys(char): Array<String>

SubstitutionCost (MODEL): Cost for substituting chars
├── layout: KeyboardLayout
└── cost(from, to): Float

WeightedEditDistance (SERVICE): Calculator using models
```

- [ ] #17: Weighted edit distance MODELs (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Analysis: Study CSpell weighted distance implementation
  - [ ] Design: `EditCost` VALUE
  - [ ] Design: `KeyboardLayout` MODEL
  - [ ] Design: `SubstitutionCost` MODEL (composes KeyboardLayout)
  - [ ] Design: `WeightedEditDistance` SERVICE
  - [ ] Implement: `KeyboardLayout#key_position(char)` method
  - [ ] Implement: `KeyboardLayout#distance(char1, char2)` method
  - [ ] Implement: `KeyboardLayout#adjacent_keys(char)` method
  - [ ] Implement: `SubstitutionCost#cost(from, to)` uses KeyboardLayout
  - [ ] Implement: `WeightedEditDistance` uses SubstitutionCost MODEL
  - [ ] Test: Spec for EditCost VALUE
  - [ ] Test: Spec for KeyboardLayout MODEL
  - [ ] Test: Spec for SubstitutionCost MODEL
  - [ ] Test: Benchmark suggestion quality
  - [ ] Document: Weighted distance model architecture

### 2.3 CSpell Configuration Models

**OOP Issue**: Current plan uses "adapter" - should create models that map to Kotoshu.

**Model-Driven Design**:
```
CSpellConfiguration (MODEL): Represents .cspell.json structure
├── language: String
├── dictionaries: Array<DictionaryReference>
├── ignore_paths: Array<String>
└── to_kotoshu: Configuration

DictionaryReference (MODEL): External dictionary reference
├── path: String
├── format: Symbol (:cspell, :hunspell, :plain)
└── load: Dictionary

LanguageSetting (MODEL): Language-specific configuration
├── language_code: String
├── enabled: Boolean
└── dictionaries: Array<DictionaryReference>

ConfigurationAdapter (SERVICE): Maps CSpell -> Kotoshu
```

- [ ] #18: CSpell configuration MODELs (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Analysis: Study .cspell.json schema in CSpell
  - [ ] Design: `CSpellConfiguration` MODEL
  - [ ] Design: `DictionaryReference` MODEL
  - [ ] Design: `LanguageSetting` MODEL
  - [ ] Design: `ConfigurationAdapter` SERVICE
  - [ ] Implement: Parse .cspell.json into CSpellConfiguration MODEL
  - [ ] Implement: `CSpellConfiguration#to_kotoshu` method
  - [ ] Implement: `DictionaryReference#load` method
  - [ ] Implement: `ConfigurationAdapter#adapt(config)` service
  - [ ] Test: Spec for CSpellConfiguration MODEL
  - [ ] Test: Spec for DictionaryReference MODEL
  - [ ] Test: Spec for ConfigurationAdapter SERVICE
  - [ ] Document: CSpell configuration model architecture

### 2.4 Lazy Loading Models

**OOP Issue**: Current plan uses "lazy loading" as feature - should be a class.

**Model-Driven Design**:
```
DictionarySection (MODEL): Subset of dictionary
├── name: String
├── words: Array<Word> (lazy loaded)
├── metadata: Hash
└── loaded?: Boolean

LazyDictionary (MODEL, decorator): Proxies to sections
├── sections: Array<DictionarySection>
├── load_section(name): void
└── lookup(word): Boolean (loads section if needed)

SectionLoader (SERVICE): Manages section loading
```

- [ ] #19: Lazy loading MODELs (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Analysis: Study CSpell lazy loading implementation
  - [ ] Design: `DictionarySection` MODEL
  - [ ] Design: `LazyDictionary` MODEL (decorator pattern)
  - [ ] Design: `SectionLoader` SERVICE
  - [ ] Implement: `DictionarySection#load` method
  - [ ] Implement: `DictionarySection#loaded?` query method
  - [ ] Implement: `LazyDictionary#lookup` triggers section load
  - [ ] Implement: `SectionLoader#load_section(dictionary, section)`
  - [ ] Test: Spec for DictionarySection MODEL
  - [ ] Test: Spec for LazyDictionary MODEL
  - [ ] Test: Benchmark memory usage
  - [ ] Document: Lazy loading model architecture

### 2.5 Cache Models

**OOP Issue**: Current plan uses "warming strategy" - cache should be a model.

**Model-Driven Design**:
```
Cache (abstract MODEL)
├── get(key): Value
├── set(key, value): void
├── clear: void
├── warm: void
├── hit_rate: Float
└── size: Integer

WordCache (MODEL, extends Cache): Word lookups
SuggestionCache (MODEL, extends Cache): Suggestions
ResultCache (MODEL, extends Cache): Check results

CacheWarmer (SERVICE): Orchestrates warming (not a strategy)
```

- [ ] #20: Cache MODEL hierarchy (COMPLEXITY: MEDIUM, PRIORITY: LOW)
  - [ ] Analysis: Study CSpell cache implementation
  - [ ] Design: Abstract `Cache` base MODEL
  - [ ] Design: `WordCache` subclass
  - [ ] Design: `SuggestionCache` subclass
  - [ ] Design: `ResultCache` subclass
  - [ ] Design: `CacheWarmer` SERVICE
  - [ ] Implement: `Cache#warm` method (abstract, implemented by subclasses)
  - [ ] Implement: `Cache#hit_rate` calculation
  - [ ] Implement: `CacheWarmer#warm(cache)` service
  - [ ] Test: Spec for Cache MODEL
  - [ ] Test: Spec for each subclass
  - [ ] Test: Benchmark first-check improvement
  - [ ] Document: Cache model architecture

---

## Part 3: LanguageTool Feature Gaps (Model-Driven)

**Status**: 0/7 items (0%)

### 3.1 Rule System Models

**OOP Issue**: Current plan has "Rule class" - need full model hierarchy.

**Model-Driven Design**:
```
Rule (abstract MODEL)
├── PatternRule (MODEL): Text pattern matching
├── GrammarRule (MODEL): Grammar violations
├── StyleRule (MODEL): Style violations
└── ConfusionRule (MODEL): Word confusion (inherits GrammarRule)

RuleMatcher (INTERFACE): Pattern matching strategy
├── RegexMatcher (IMPLEMENTATION)
├── ParserMatcher (IMPLEMENTATION)
└── matches(text, rule): Boolean

RuleViolation (VALUE): Represents rule breach
├── rule: Rule
├── position: Integer
├── message: String
└── suggestions: Array<String>

RuleSuggestion (MODEL): Suggestion for fixing violation
├── text: String
├── explanation: String
└── confidence: Float

RuleSet (MODEL, composite): Applies multiple rules
RuleEngine (SERVICE): Orchestrates rule application
```

- [ ] #21: Rule MODEL hierarchy (COMPLEXITY: HIGH, PRIORITY: MEDIUM)
  - [ ] Analysis: Study LanguageTool rule system architecture
  - [ ] Design: Abstract `Rule` base MODEL
  - [ ] Design: `PatternRule`, `GrammarRule`, `StyleRule` subclasses
  - [ ] Design: `ConfusionRule` (inherits from GrammarRule)
  - [ ] Design: `RuleMatcher` INTERFACE
  - [ ] Design: `RuleViolation` VALUE
  - [ ] Design: `RuleSuggestion` MODEL
  - [ ] Design: `RuleSet` MODEL (composite pattern)
  - [ ] Design: `RuleEngine` SERVICE
  - [ ] Implement: `Rule#check(text)` abstract method
  - [ ] Implement: `Rule#suggest(text)` abstract method
  - [ ] Implement: Subclass-specific check/suggest implementations
  - [ ] Implement: `RuleViolation` VALUE object
  - [ ] Implement: `RuleSet#check(text)` composes rules
  - [ ] Implement: `RuleEngine#apply_rules(text, rules)` service
  - [ ] Test: Spec for each Rule subclass
  - [ ] Test: Spec for RuleViolation VALUE
  - [ ] Test: Spec for RuleEngine SERVICE
  - [ ] Document: Rule system model architecture
  - [ ] NOTE: Consider as separate gem (kotoshu-grammar) or future phase

### 3.2 Language Detection Models

**OOP Issue**: Current plan has "detection strategy" - need models for language itself.

**Model-Driven Design**:
```
Language (VALUE): Represents a language
├── code: String ("en-US")
├── name: String ("English (United States)")
├── region: String ("US")
└── ==(other): Boolean

LanguageDetection (VALUE): Result of detection
├── language: Language
├── confidence: Float
└── alternatives: Array<LanguageDetection>

LanguageDetector (INTERFACE): Strategy for detection
├── FrequencyBasedDetector (MODEL): Uses word frequency
├── DictionaryBasedDetector (MODEL): Uses dictionary matching
├── NgramBasedDetector (MODEL): Uses character n-grams
└── detect(text): LanguageDetection

LanguageProfile (MODEL): Stores language characteristics
├── language: Language
├── common_words: Array<String>
├── character_ngrams: Hash<String, Float>
└── frequency_distribution: Hash<String, Float>
```

- [ ] #22: Language detection MODELs (COMPLEXITY: HIGH, PRIORITY: MEDIUM)
  - [ ] Analysis: Study LanguageTool language detection algorithms
  - [ ] Design: `Language` VALUE
  - [ ] Design: `LanguageDetection` VALUE
  - [ ] Design: `LanguageDetector` INTERFACE
  - [ ] Design: `FrequencyBasedDetector` MODEL
  - [ ] Design: `DictionaryBasedDetector` MODEL
  - [ ] Design: `NgramBasedDetector` MODEL
  - [ ] Design: `LanguageProfile` MODEL
  - [ ] Implement: `Language#==(other)` value equality
  - [ ] Implement: `LanguageDetection#confidence` query method
  - [ ] Implement: Each detector MODEL's `detect(text)` method
  - [ ] Implement: `LanguageProfile#common_words`, `#character_ngrams`
  - [ ] Implement: `Text#detect_language` returns LanguageDetection
  - [ ] Test: Spec for Language VALUE
  - [ ] Test: Spec for LanguageDetection VALUE
  - [ ] Test: Spec for each detector MODEL
  - [ ] Test: Benchmark detection accuracy
  - [ ] Document: Language detection model architecture

### 3.3 Cache Hierarchy Models

**OOP Issue**: Current plan has "three-level cache" - should be polymorphic hierarchy.

**Model-Driven Design**:
```
Cache (abstract MODEL) - see Part 2, Item #20
├── ResultCache (MODEL): Complete check results
├── WordLookupCache (MODEL): Dictionary lookups
├── SuggestionCache (MODEL): Generated suggestions
└── SentenceCache (MODEL): Sentence-level analysis

CacheLayer (MODEL, composite): Combines multiple caches
├── layers: Array<Cache>
├── get(key): Value (checks each layer)
└── set(key, value): void (sets in all layers)

CacheStatistics (MODEL): Tracks cache metrics
├── hits: Integer
├── misses: Integer
├── evictions: Integer
└── hit_rate: Float
```

- [ ] #23: Cache hierarchy MODELs (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Analysis: Study LanguageTool multi-level cache design
  - [ ] Design: `CacheLayer` composite MODEL
  - [ ] Design: `CacheStatistics` MODEL
  - [ ] Implement: Extend Cache MODEL with new subclasses
  - [ ] Implement: `CacheLayer#get` checks layers in order
  - [ ] Implement: `CacheLayer#set` propagates to all layers
  - [ ] Implement: `CacheStatistics#hit_rate` calculation
  - [ ] Implement: Cache composition in Spellchecker
  - [ ] Test: Spec for CacheLayer composite
  - [ ] Test: Spec for CacheStatistics MODEL
  - [ ] Test: Benchmark cache hit rates
  - [ ] Document: Cache hierarchy architecture

### 3.4 Parallel Processing Models

**OOP Issue**: Current plan has "parallel rule runner" - should use polymorphism.

**Model-Driven Design**:
```
RuleProcessor (INTERFACE): Single-threaded implementation
├── process(rules, text): Array<RuleViolation>
└── validate(rule): Boolean

ParallelRuleProcessor (MODEL, implements RuleProcessor)
├── thread_pool: ThreadPool
├── process(rules, text): Array<RuleViolation>
└── process_parallel(rules, text): Array<RuleViolation>

ProcessingContext (MODEL): Shared state for parallel processing
├── text: String
├── cache: Cache
└── metadata: Hash

ProcessingResult (MODEL): Aggregated results
├── violations: Array<RuleViolation>
├── processing_time: Float
└── processor_count: Integer
```

- [ ] #24: Parallel processing MODELs (COMPLEXITY: HIGH, PRIORITY: MEDIUM)
  - [ ] Analysis: Study LanguageTool parallel processing implementation
  - [ ] Design: `RuleProcessor` INTERFACE
  - [ ] Design: `ParallelRuleProcessor` MODEL
  - [ ] Design: `ProcessingContext` MODEL
  - [ ] Design: `ProcessingResult` MODEL
  - [ ] Implement: Base `RuleProcessor` INTERFACE
  - [ ] Implement: Single-threaded implementation
  - [ ] Implement: `ParallelRuleProcessor` with thread pool
  - [ ] Implement: `ProcessingContext` for shared state
  - [ ] Implement: `ProcessingResult` aggregation
  - [ ] Implement: Dependency injection in Spellchecker
  - [ ] Test: Spec for RuleProcessor INTERFACE
  - [ ] Test: Spec for ParallelRuleProcessor MODEL
  - [ ] Test: Benchmark speedup
  - [ ] Document: Parallel processing model architecture
  - [ ] NOTE: Defer until Rule system (#21) is implemented

### 3.5 HTTP API Models

**OOP Issue**: Current plan has "request/response schemas" - should be models.

**Model-Driven Design**:
```
CheckRequest (MODEL): Spellcheck request
├── text: String
├── language: Language
├── options: Hash
└── validate: void

CheckResponse (MODEL): Spellcheck response
├── results: Array<WordResult>
├── document_result: DocumentResult
├── processing_time: Float
└── to_json: String

SuggestionItem (MODEL): Individual suggestion in response
├── text: String
├── confidence: Float
├── source: String
└── to_h: Hash

ErrorItem (MODEL): Error detail in response
├── code: String
├── message: String
├── context: Hash
└── to_h: Hash

DocumentResultSerializer (SERVICE): Converts domain -> HTTP response
```

- [ ] #25: HTTP API MODELs (COMPLEXITY: HIGH, PRIORITY: HIGH)
  - [ ] Analysis: Study LanguageTool REST API structure
  - [ ] Design: `CheckRequest` MODEL
  - [ ] Design: `CheckResponse` MODEL
  - [ ] Design: `SuggestionItem` MODEL
  - [ ] Design: `ErrorItem` MODEL
  - [ ] Design: `DocumentResultSerializer` SERVICE
  - [ ] Implement: `CheckRequest#validate` method
  - [ ] Implement: `CheckResponse#to_json` method
  - [ ] Implement: `SuggestionItem` fields
  - [ ] Implement: `ErrorItem` fields
  - [ ] Implement: `DocumentResultSerializer#serialize(result)`
  - [ ] Implement: Controllers (thin, delegate to Spellchecker)
  - [ ] Test: Spec for request/response MODELs
  - [ ] Test: Spec for serializer SERVICE
  - [ ] Document: API MODEL architecture
  - [ ] Document: API specification
  - [ ] Document: Deployment guide
  - [ ] NOTE: Create as separate gem (kotoshu-server)

### 3.6 Tokenizer Models

**OOP Issue**: Current plan has "tokenizer interface" - need token VALUE and model hierarchy.

**Model-Driven Design**:
```
Token (VALUE): Single token
├── text: String
├── type: TokenType (enum)
├── position: Integer
├── length: Integer
├── word?: Boolean (polymorphic by type)
├── punctuation?: Boolean
├── url?: Boolean
└── ==(other): Boolean

TokenType (VALUE OBJECT): Token type enum
├── WORD
├── PUNCTUATION
├── WHITESPACE
├── URL
├── EMAIL
└── SYMBOL

Tokenizer (abstract MODEL)
├── tokenize(text): Array<Token>
├── tokens: Array<Token>
├── count: Integer
└── reset: void

WordTokenizer (MODEL): Splits text into words
SentenceTokenizer (MODEL): Splits text into sentences
SpecialTokenRecognizer (MODEL): Recognizes URLs, emails, etc.

TokenizerPipeline (MODEL, composite): Chains tokenizers
```

- [ ] #26: Tokenizer MODEL hierarchy (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Analysis: Study LanguageTool tokenizer implementation
  - [ ] Design: `Token` VALUE
  - [ ] Design: `TokenType` enum (or VALUE object)
  - [ ] Design: Abstract `Tokenizer` base MODEL
  - [ ] Design: `WordTokenizer`, `SentenceTokenizer` subclasses
  - [ ] Design: `SpecialTokenRecognizer` MODEL
  - [ ] Design: `TokenizerPipeline` composite
  - [ ] Implement: `Token` VALUE equality
  - [ ] Implement: `Token#word?`, `#punctuation?`, `#url?` (polymorphic)
  - [ ] Implement: `Tokenizer#tokenize(text)` abstract method
  - [ ] Implement: Subclass tokenization logic
  - [ ] Implement: `TokenizerPipeline#tokenize` composes tokenizers
  - [ ] Implement: `Text#tokens` returns Token array
  - [ ] Test: Spec for Token VALUE
  - [ ] Test: Spec for Tokenizer MODELs
  - [ ] Test: Spec for TokenizerPipeline composite
  - [ ] Document: Tokenizer model architecture

### 3.7 Confusion Words Models

**OOP Issue**: Current plan has "ConfusionRule class" - need models for confusion sets.

**Model-Driven Design**:
```
ConfusionSet (MODEL): Group of confused words
├── words: Array<String>
├── examples: Array<String>
└── includes?(word): Boolean

ConfusionPair (MODEL): Two words that can be confused
├── word1: String
├── word2: String
├── context_pattern: Regex
└── swap_correct?(text, position): Boolean

ConfusionContext (MODEL): Context pattern for confusion
├── pattern: Regex
├── requires_word: String
└── matches?(text, position): Boolean

ConfusionRule (MODEL, extends GrammarRule): Uses ConfusionSet
├── confusion_set: ConfusionSet
├── detect(text): Array<RuleViolation>
└── suggest(violation): Array<RuleSuggestion>
```

- [ ] #27: Confusion words MODELs (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Analysis: Study confusion rules in LanguageTool XML
  - [ ] Design: `ConfusionSet` MODEL
  - [ ] Design: `ConfusionPair` MODEL
  - [ ] Design: `ConfusionContext` MODEL
  - [ ] Design: `ConfusionRule` MODEL (extends GrammarRule from #21)
  - [ ] Implement: `ConfusionSet#include?(word)` method
  - [ ] Implement: `ConfusionPair#swap_correct?` method
  - [ ] Implement: `ConfusionContext#matches?` method
  - [ ] Implement: `ConfusionRule` composes ConfusionSet MODELs
  - [ ] Implement: Parse confusion rules from XML into MODELs
  - [ ] Test: Spec for ConfusionSet MODEL
  - [ ] Test: Spec for ConfusionPair MODEL
  - [ ] Test: Spec for ConfusionRule MODEL
  - [ ] Document: Confusion word model architecture
  - [ ] NOTE: Defer until Rule system (#21) is implemented

---

## Part 4: Performance Optimization Models

**Status**: 0/8 items (0%)

### 4.1 SymSpell Models

**OOP Issue**: Current plan has "SymSpellStrategy" - need domain models.

**Model-Driven Design**:
```
DeleteHash (MODEL): Pre-computed delete variants
├── deletes: Hash<String, Array<String>>
├── lookup(word): Array<String>
└── build(dictionary): void

DeleteVariant (VALUE): Single delete variant
├── original: String
├── deleted: String
├── delete_position: Integer
└── ==(other): Boolean

SymSpellDictionary (MODEL): Wraps dictionary with delete hash
├── dictionary: Dictionary
├── delete_hash: DeleteHash
└── lookup(word): LookupResult

SymSpellLookup (VALUE): Match with distance
├── word: String
├── distance: Integer
├── frequency: Integer
└── confidence: Float
```

- [ ] #28: SymSpell MODELs (COMPLEXITY: HIGH, PRIORITY: HIGH)
  - [ ] Analysis: Study SymSpell algorithm research paper
  - [ ] Design: `DeleteHash` MODEL
  - [ ] Design: `DeleteVariant` VALUE
  - [ ] Design: `SymSpellDictionary` MODEL
  - [ ] Design: `SymSpellLookup` VALUE
  - [ ] Implement: `DeleteHash#build(dictionary)` method
  - [ ] Implement: `DeleteHash#lookup(word)` returns variants
  - [ ] Implement: `DeleteVariant` VALUE equality
  - [ ] Implement: `SymSpellDictionary` composes DeleteHash
  - [ ] Implement: `SymSpellStrategy` uses SymSpellDictionary MODEL
  - [ ] Test: Spec for DeleteHash MODEL
  - [ ] Test: Spec for DeleteVariant VALUE
  - [ ] Test: Benchmark vs edit distance
  - [ ] Document: SymSpell model architecture

### 4.2 Edit Distance Interface

**OOP Issue**: Current plan modifies `edit_distance()` directly - should use polymorphism.

**Model-Driven Design**:
```
EditDistanceCalculator (INTERFACE)
├── calculate(str1, str2): Integer
└── calculate_with_threshold(str1, str2, threshold): Integer?

BoundedEditDistance (MODEL, implements interface)
├── threshold: Integer
├── was_terminated: Boolean
└── calculate_with_threshold(str1, str2, threshold): Integer?

UnboundedEditDistance (MODEL, implements interface)
└── calculate(str1, str2): Integer

EditDistanceResult (VALUE): Distance + metadata
├── distance: Integer
├── path: Array<String>
├── was_terminated: Boolean
└── to_h: Hash
```

- [ ] #29: Edit distance INTERFACE (COMPLEXITY: LOW, PRIORITY: MEDIUM)
  - [ ] Analysis: Study bounded Levenshtein algorithms
  - [ ] Design: `EditDistanceCalculator` INTERFACE
  - [ ] Design: `BoundedEditDistance` MODEL
  - [ ] Design: `UnboundedEditDistance` MODEL
  - [ ] Design: `EditDistanceResult` VALUE
  - [ ] Implement: Extract current logic into `UnboundedEditDistance`
  - [ ] Implement: `BoundedEditDistance` with early termination
  - [ ] Implement: `EditDistanceResult` VALUE
  - [ ] Implement: Strategy depends on INTERFACE, not concrete class
  - [ ] Test: Spec for bounded implementation
  - [ ] Test: Benchmark speedup
  - [ ] Document: Edit distance interface architecture

### 4.3 N-Gram Index Model

**OOP Issue**: Already addressed in Part 1, Item #6 (NGramIndex MODEL).

- [ ] #30: Integrate NGramIndex with suggestion pipeline (COMPLEXITY: LOW, PRIORITY: MEDIUM)
  - [ ] Analysis: Review NGramIndex MODEL from Item #6
  - [ ] Design: `NGramFilter` SERVICE (uses NGramIndex)
  - [ ] Implement: `NGramFilter#candidates(word, dictionary)` filters
  - [ ] Implement: EditDistanceStrategy uses NGramFilter first
  - [ ] Implement: Only calculate edit distance on filtered candidates
  - [ ] Test: Benchmark filter effectiveness (90%+ reduction)
  - [ ] Document: NGram filtering integration

### 4.4 Memory-Mapped Dictionary Models

**OOP Issue**: Current plan creates "MmapDictionary backend" - should use composition.

**Model-Driven Design**:
```
MmapFile (VALUE): Encapsulates mmap operations
├── path: String
├── size: Integer
├── read(offset, length): String
└── close: void

MmapDictionary (MODEL, extends Dictionary::Base)
├── mmap_file: MmapFile (composition)
├── load: void (uses mmap_file)
├── lookup(word): Boolean
└── words: Array<String>
```

- [ ] #31: Mmap models (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Analysis: Study Ruby mmap gem/syscall
  - [ ] Design: `MmapFile` VALUE
  - [ ] Design: `MmapDictionary` MODEL (uses composition)
  - [ ] Implement: `MmapFile#read(offset, length)` method
  - [ ] Implement: `MmapFile#close` method
  - [ ] Implement: `MmapDictionary` composes MmapFile VALUE
  - [ ] Implement: Lazy loading via MmapFile
  - [ ] Test: Spec for MmapFile VALUE
  - [ ] Test: Spec for MmapDictionary MODEL
  - [ ] Benchmark memory reduction
  - [ ] Document: Mmap model architecture

### 4.5 Thread-Safe Dictionary Models

**OOP Issue**: Current plan uses "Mutex protection" - should use decorator pattern.

**Model-Driven Design**:
```
ThreadSafeDictionary (MODEL, decorator): Adds synchronization
├── dictionary: Dictionary::Base (decorated)
├── lock: Mutex
├── lookup(word): Boolean (synchronized)
└── words: Array<String> (synchronized)

ConcurrentHash (MODEL): Thread-safe hash implementation
├── hash: Hash
├── lock: ReadWriteLock
├── get(key): Value
└── set(key, value): void

ReadWriteLock (MODEL): Multiple readers, single writer
├── read_lock: Mutex
├── write_lock: Mutex
├── with_read_lock(&block)
└── with_write_lock(&block)
```

- [ ] #32: Thread-safe MODELs (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Analysis: Identify shared mutable state
  - [ ] Design: `ThreadSafeDictionary` decorator MODEL
  - [ ] Design: `ConcurrentHash` MODEL
  - [ ] Design: `ReadWriteLock` MODEL
  - [ ] Implement: `ThreadSafeDictionary` wraps any Dictionary::Base
  - [ ] Implement: `ConcurrentHash` with read/write locking
  - [ ] Implement: `ReadWriteLock#with_read_lock`, `#with_write_lock`
  - [ ] Keep Dictionary::Base unsynchronized (single-threaded)
  - [ ] Test: Spec for ThreadSafeDictionary decorator
  - [ ] Test: Stress test with threads
  - [ ] Document: Thread-safe model architecture

### 4.6 Cache Eviction Policy Models

**OOP Issue**: Current plan has "WordCache" - should use strategy pattern for eviction.

**OOP Design**:
```
Cache (abstract MODEL) - see Part 2, Item #20

EvictionPolicy (INTERFACE): Strategy for cache eviction
├── evict(cache, key): void
└── should_evict?(cache, key): Boolean

LRUPolicy (MODEL): Least-recently-used eviction
LFUPolicy (MODEL): Least-frequently-used eviction
FIFOPolicy (MODEL): First-in-first-out eviction

CacheEntry (VALUE): Cache item with metadata
├── key: String
├── value: Object
├── timestamp: Time
├── access_count: Integer
└── ==(other): Boolean
```

- [ ] #33: Cache eviction MODELs (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Analysis: Study cache eviction algorithms
  - [ ] Design: `EvictionPolicy` INTERFACE
  - [ ] Design: `LRUPolicy`, `LFUPolicy`, `FIFOPolicy` MODELs
  - [ ] Design: `CacheEntry` VALUE
  - [ ] Implement: `CacheEntry` VALUE with timestamp/access_count
  - [ ] Implement: Each eviction policy MODEL
  - [ ] Implement: `Cache` accepts EvictionPolicy via dependency injection
  - [ ] Test: Spec for each eviction policy
  - [ ] Test: Benchmark cache hit rates
  - [ ] Document: Cache eviction model architecture

### 4.7 String Interning Models

**OOP Issue**: Current plan has "StringInterner class" - should be a VALUE pool.

**Model-Driven Design**:
```
StringPool (MODEL): Manages interned strings
├── pool: Hash<String, String>
├── intern(string): String
├── size: Integer
└── clear: void

InternedString (VALUE): Wrapper around interned string
├── value: String (from pool)
├── interned?: true
└── ==(other): Boolean (pointer equality)

StringInterner (SERVICE): Interns strings into pool
├── pool: StringPool
└── intern(string): InternedString
```

- [ ] #34: String interning MODELs (COMPLEXITY: LOW, PRIORITY: LOW)
  - [ ] Analysis: Identify interning opportunities (words, flags, morphological data)
  - [ ] Design: `StringPool` MODEL
  - [ ] Design: `InternedString` VALUE
  - [ ] Design: `StringInterner` SERVICE
  - [ ] Implement: `StringPool#intern(string)` method
  - [ ] Implement: `InternedString` VALUE (pointer equality)
  - [ ] Implement: Dictionary uses StringPool for word storage
  - [ ] Test: Spec for StringPool MODEL
  - [ ] Test: Benchmark memory reduction (20-40%)
  - [ ] Document: String interning model architecture

### 4.8 Affix Rule Indexing Models

**OOP Issue**: Current plan has "RuleIndex class" - need more complete model.

**Model-Driven Design**:
```
RuleIndex (MODEL): Maps first char -> applicable rules
├── index: Hash<String, Array<AffixRule>>
├── build(rules): void
├── lookup(word): Array<AffixRule>
└── clear: void

RuleLookup (VALUE): Matching rules + metadata
├── rules: Array<AffixRule>
├── match_count: Integer
└── to_a: Array<AffixRule>

RuleIndexBuilder (SERVICE): Builds index from rule collection
├── rules: Array<AffixRule>
├── build: RuleIndex
└── rebuild: RuleIndex
```

- [ ] #35: Rule indexing MODELs (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Analysis: Study Hunspell rule indexing implementation
  - [ ] Design: `RuleIndex` MODEL
  - [ ] Design: `RuleLookup` VALUE
  - [ ] Design: `RuleIndexBuilder` SERVICE
  - [ ] Implement: `RuleIndex#build(rules)` uses `AffixRule#first_character`
  - [ ] Implement: `RuleIndex#lookup(word)` returns RuleLookup
  - [ ] Implement: `RuleLookup` VALUE with match_count
  - [ ] Implement: `RuleIndexBuilder#build` SERVICE
  - [ ] Test: Spec for RuleIndex MODEL
  - [ ] Test: Benchmark rule check reduction (50-90%)
  - [ ] Document: Rule indexing model architecture

---

## Part 5: Infrastructure and Testing

**Status**: 0/7 items (0%)

### 5.1 Test Suite (Behavior-Driven)

**OOP Principles**:
- Test BEHAVIOR, not implementation
- Use doubles/mocks for dependencies
- Test polymorphic behavior with multiple implementations
- Test error cases, not just happy paths

- [ ] #36: Core MODEL specs (COMPLEXITY: MEDIUM, PRIORITY: HIGH)
  - [ ] Test: Word MODEL behavior (not internal state)
  - [ ] Test: AffixRule MODEL behavior
  - [ ] Test: Suggestion MODEL behavior
  - [ ] Test: WordResult VALUE behavior (immutability)
  - [ ] Test: DocumentResult VALUE behavior (aggregation)
  - [ ] Test: Polymorphic methods (e.g., `can_stand_alone?`)

- [ ] #37: Dictionary MODEL specs (COMPLEXITY: MEDIUM, PRIORITY: HIGH)
  - [ ] Test: Dictionary::Base INTERFACE contract
  - [ ] Test: Each subclass MODEL behavior
  - [ ] Test: Subclass-specific methods (not base class)
  - [ ] Use doubles for external dependencies (file system, etc.)

- [ ] #38: Suggestion STRATEGY specs (COMPLEXITY: MEDIUM, PRIORITY: HIGH)
  - [ ] Test: BaseStrategy INTERFACE contract
  - [ ] Test: Each strategy algorithm (with MODEL doubles)
  - [ ] Test: Strategy composition (multiple algorithms)
  - [ ] Test: Context MODEL passing to strategies

- [ ] #39: Application SERVICE specs (COMPLEXITY: MEDIUM, PRIORITY: HIGH)
  - [ ] Test: Spellchecker SERVICE orchestrates correctly
  - [ ] Test: Configuration MODEL validation
  - [ ] Test: CLI thin controller (delegates to Spellchecker)
  - [ ] Use MODEL doubles, not real dictionaries

- [ ] #40: Integration specs (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Test: Full check workflow (MODEL + SERVICE integration)
  - [ ] Test: Suggestion pipeline (STRATEGY + MODEL integration)
  - [ ] Test: Multi-dictionary usage
  - [ ] Test: Error handling paths

### 5.2 Benchmarking Models

**OOP Issue**: Benchmarking should use models, not scripts.

**Model-Driven Design**:
```
Benchmark (MODEL): Represents single benchmark run
├── name: String
├── run: block
├── result: BenchmarkResult
└── run!: BenchmarkResult

BenchmarkResult (VALUE): Metric + value + timestamp
├── metric: String
├── value: Float
├── unit: String
├── timestamp: Time
└── ==(other): Boolean

BenchmarkSuite (MODEL, composite): Runs multiple benchmarks
├── benchmarks: Array<Benchmark>
├── run!: Array<BenchmarkResult>
└── report: String

PerformanceReport (MODEL): Aggregate results
├── results: Array<BenchmarkResult>
├── summary: Hash
└── to_s: String
```

- [ ] #41: Benchmark MODELs (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Design: `Benchmark` MODEL
  - [ ] Design: `BenchmarkResult` VALUE
  - [ ] Design: `BenchmarkSuite` composite
  - [ ] Design: `PerformanceReport` MODEL
  - [ ] Implement: Benchmark MODEL with DSL syntax
  - [ ] Implement: `BenchmarkSuite#run!` composes benchmarks
  - [ ] Implement: `PerformanceReport` aggregation
  - [ ] Set up: Benchmark automation with MODELs
  - [ ] Test: Spec for Benchmark MODEL
  - [ ] Document: Benchmark baseline results
  - [ ] Document: Performance targets

### 5.3 CI/CD (Infrastructure)

- [ ] #42: GitHub Actions CI/CD (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Create: `.github/workflows/test.yml`
  - [ ] Set up: RSpec automated tests (behavior-focused)
  - [ ] Set up: Rubocop automated linting (OOP style checks)
  - [ ] Set up: Ruby version matrix (3.1, 3.2, 3.3)
  - [ ] Create: `.github/workflows/release.yml`
  - [ ] Set up: Automated gem release
  - [ ] Document: CI/CD process

### 5.4 Documentation (Models as Examples)

**OOP Principle**: Documentation should show MODEL usage, not procedural steps.

- [ ] #43: README.adoc with MODEL examples (COMPLEXITY: MEDIUM, PRIORITY: HIGH)
  - [ ] Write: Purpose section (emphasize OOP architecture)
  - [ ] Write: Features section (links to MODEL documentation)
  - [ ] Write: Architecture section with MODEL diagrams
  - [ ] Write: Installation section
  - [ ] Write: MODEL usage examples (not procedural scripts)
  - [ ] Write: Feature documentation (each MODEL/VALUE/SERVICE)
  - [ ] Write: API reference (MODEL APIs)
  - [ ] Write: Contributing guide (OOP principles)

- [ ] #44: Dictionary format guides (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Write: Hunspell MODEL mapping guide
  - [ ] Write: CSpell MODEL mapping guide
  - [ ] Write: Custom MODEL creation guide
  - [ ] Write: Troubleshooting guide

- [ ] #45: RBS type signatures (COMPLEXITY: MEDIUM, PRIORITY: LOW)
  - [ ] Create: Complete `sig/kotoshu.rbs`
  - [ ] Define: MODEL types (abstract classes)
  - [ ] Define: VALUE types (immutable structs)
  - [ ] Define: SERVICE interfaces
  - [ ] Define: STRATEGY interfaces
  - [ ] Document: Type checking workflow

### 5.5 Example Scripts (Model-Driven)

**OOP Principle**: Examples demonstrate MODEL lifecycle, not procedural calls.

- [ ] #46: MODEL-centric example scripts (COMPLEXITY: LOW, PRIORITY: MEDIUM)
  - [ ] Create: `examples/07_hunspell_models.rb` (MODEL creation/usage)
  - [ ] Create: `examples/08_trie_models.rb` (TrieNode polymorphism)
  - [ ] Create: `examples/09_compound_models.rb` (CompoundRule/CompoundWord)
  - [ ] Create: `examples/10_rule_models.rb` (Rule MODEL hierarchy)
  - [ ] Create: `examples/11_strategy_composition.rb` (STRATEGY + MODEL)
  - [ ] Create: `examples/12_service_orchestration.rb` (SERVICE uses MODELs)

### 5.6 Error Models

**OOP Issue**: Errors should be VALUE OBJECTS that capture state.

**Model-Driven Design**:
```
SpellcheckError (Exception, abstract)
├── context: Hash (captured state)
├── message: String (uses context)
└── to_s: String

DictionaryNotFoundError (MODEL, extends SpellcheckError)
InvalidDictionaryFormatError (MODEL, extends SpellcheckError)
ConfigurationError (MODEL, extends SpellcheckError)
ForbiddenWordError (MODEL, extends SpellcheckError)
```

- [ ] #47: Error MODEL hierarchy (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Analysis: Review all exception types
  - [ ] Design: Error MODEL hierarchy
  - [ ] Implement: Each error captures context at creation time
  - [ ] Implement: Custom `#message` uses context
  - [ ] Implement: Custom `#to_s` for useful output
  - [ ] Add: Missing error cases
  - [ ] Test: Spec for each error MODEL
  - [ ] Document: Error MODEL hierarchy and recovery

### 5.7 Configuration Models

**OOP Issue**: Configuration should parse into MODELs, not raw hash access.

**Model-Driven Design**:
```
KotoshuConfigFile (MODEL): Represents .kotoshurc.yml
├── path: String
├── exists?: Boolean
├── load: Configuration
└── validate: void

Configuration (MODEL): Type-safe configuration
├── dictionary_path: String (accessor, not hash access)
├── dictionary_type: Symbol (accessor)
├── language: String (accessor)
└── validate: void (self-validation)
```

- [ ] #48: Configuration MODELs (COMPLEXITY: MEDIUM, PRIORITY: MEDIUM)
  - [ ] Design: `.kotoshurc.yml` schema
  - [ ] Design: `KotoshuConfigFile` MODEL
  - [ ] Design: Configuration MODEL validation
  - [ ] Implement: YAML config parser into MODEL
  - [ ] Implement: Config file discovery logic
  - [ ] Implement: Config merge hierarchy (MODEL composition)
  - [ ] Implement: Configuration MODEL has type-safe accessors
  - [ ] Test: Spec for config MODEL loading
  - [ ] Document: Configuration MODEL architecture

### 5.8 Logging Models

**OOP Issue**: Logging should be MODEL-based, not procedural.

**Model-Driven Design**:
```
Logger (INTERFACE)
├── debug(message, context): void
├── info(message, context): void
├── warn(message, context): void
├── error(message, context): void
└── level: Symbol

StructuredLogger (MODEL, implements Logger)
├── formatter: Proc
└── log(level, message, context): String

ConsoleLogger (MODEL, implements Logger)
└── log(level, message, context): String (console output)

LogEntry (VALUE): level + message + context + timestamp
├── level: Symbol
├── message: String
├── context: Hash
├── timestamp: Time
└── to_s: String
```

- [ ] #49: Logging MODEL hierarchy (COMPLEXITY: LOW, PRIORITY: LOW)
  - [ ] Design: `Logger` INTERFACE
  - [ ] Design: `StructuredLogger` MODEL
  - [ ] Design: `ConsoleLogger` MODEL
  - [ ] Design: `LogEntry` VALUE
  - [ ] Implement: `LogEntry` VALUE with timestamp
  - [ ] Implement: Each logger MODEL's `#log` method
  - [ ] Implement: Dependency injection in classes
  - [ ] Test: Spec for logging MODELs
  - [ ] Document: Logging MODEL architecture

---

## Progress Tracking

### Overall Progress

```
Total Items: 49 (reorganized from 50 for better OOP structure)
Completed: 0
In Progress: 0
Remaining: 49
Progress: 0%
```

### Progress by Category

| Category | Total | Completed | Progress |
|----------|-------|-----------|----------|
| Hunspell Feature MODELs | 15 | 0 | 0% |
| CSpell Feature MODELs | 6 | 0 | 0% |
| LanguageTool Feature MODELs | 7 | 0 | 0% |
| Performance Optimization MODELs | 8 | 0 | 0% |
| Infrastructure & Testing | 7 | 0 | 0% |

### Architecture Compliance

Each item MUST satisfy:
- ✅ **Polymorphism over Configuration**: Use inheritance, not flags
- ✅ **Models First**: Create domain models, then algorithms
- ✅ **Value Objects**: Wrap primitives in immutable classes
- ✅ **Separation of Concerns**: MODEL vs VALUE vs SERVICE vs STRATEGY
- ✅ **Composition**: Combine behaviors via composition
- ✅ **Query Methods**: Objects have behavior, not just data

### Next Milestones

**Milestone 1: Core MODEL Foundation** (Target: 2 months)
- Complete MODELs: Flag, AffixCombination, CharacterMapping, ReplacementRule
- Complete VALUEs: FlagCollection, AffixApplication, NGram
- Focus: Establish MODEL-driven architecture patterns

**Milestone 2: Compound & Morphology MODELs** (Target: 2 months)
- Complete MODELs: CompoundRule, CompoundWord, WordForm, Stem
- Complete VALUEs: CompoundPart, MorphologicalAnalysis
- Focus: Polish OOP patterns for complex domain logic

**Milestone 3: Performance MODELs** (Target: 2 months)
- Complete: TrieNode polymorphism, SymSpell MODELs, Cache MODELs
- Focus: Performance through proper MODEL design, not hacks

**Milestone 4: Rule & Language MODELs** (Target: 2 months)
- Complete: Rule hierarchy, Language detection, Tokenizer MODELs
- Focus: Extensible architecture for grammar checking

**Milestone 5: Testing & Documentation** (Target: 1 month)
- Complete: Behavior-focused tests, MODEL documentation
- Focus: Test behavior, not implementation

---

## Implementation Guidelines

### For Each Item

1. **Design Phase**:
   - Identify MODELs, VALUEs, SERVICEs, STRATEGIEs
   - Draw MODEL relationships (composition, inheritance)
   - Define query methods on MODELs (behavior, not data access)
   - Ensure VALUE immutability

2. **Implementation Phase**:
   - Implement MODELs first (domain)
   - Implement VALUEs (immutable concepts)
   - Implement SERVICEs (use cases)
   - Implement STRATEGIEs (algorithms)
   - Use dependency injection (never instantiate dependencies in MODELs)

3. **Testing Phase**:
   - Test MODEL behavior (not internals)
   - Test VALUE immutability and equality
   - Test SERVICE orchestration with MODEL doubles
   - Test STRATEGY with different MODEL implementations
   - Never test private methods

4. **Documentation Phase**:
   - Document MODEL purpose and responsibilities
   - Document VALUE equality and immutability
   - Document SERVICE use case orchestration
   - Document STRATEGY algorithm and when to use
   - Provide MODEL-centric examples

### Anti-Patterns to Avoid

❌ **Configuration-based behavior**: Use polymorphism instead
❌ **Procedural algorithms**: Create MODELs first
❌ **Primitive obsession**: Wrap in VALUE objects
❌ **God classes**: Separate MODEL, SERVICE, STRATEGY
❌ **Anemic models**: Add behavior to MODELs, not services
❌ **Implementation testing**: Test behavior, not code
❌ **Tight coupling**: Use dependency injection

### Code Review Checklist

For each pull request, verify:
- [ ] MODELs have behavior (query methods), not just data
- [ ] VALUEs are immutable with value equality
- [ ] Polymorphism used instead of configuration switches
- [ ] SERVICEs orchestrate, don't contain domain logic
- [ ] STRATEGIEs implement interfaces, are pluggable
- [ ] Tests verify behavior, not implementation
- [ ] No primitive obsession (use VALUE objects)
- [ ] Dependencies injected, not instantiated
- [ ] Documentation shows MODEL usage

---

## Complexity Estimates

Total estimated effort (fully OOP compliant):
- LOW complexity: ~13 items × 2 hours = 26 hours
- MEDIUM complexity: ~28 items × 8 hours = 224 hours (increased for MODEL design)
- HIGH complexity: ~8 items × 32 hours = 256 hours (increased for architecture)

**Total**: ~506 hours (~12.6 weeks at 40 hours/week)

**Note**: Increased from original estimate due to:
- Additional MODEL design time
- VALUE object creation
- Polymorphic architecture
- Proper separation of concerns
- Behavior-focused testing

This is INVESTMENT in maintainable, extensible architecture.

---

## Reference Implementation Locations

- **Hunspell**: `/Users/mulgogi/src/external/hunspell/`
  - `lib/hunspell/affixmgr.hxx` - Affix MODEL management
  - `lib/hunspell/hashmgr.hxx` - Dictionary word storage
  - `lib/hunspell/suggestmgr.hxx` - Suggestion generation
  - `tests/` - Dictionary file examples

- **CSpell**: `/Users/mulgogi/src/external/cspell/`
  - `packages/cspell-trie-lib/` - Trie NODE MODEL design
  - `packages/cspell-dictionary/` - Dictionary loading
  - `packages/cspell-config-lib/` - Configuration MODELs

- **LanguageTool**: `/Users/mulgogi/src/external/languagetool/`
  - `languagetool-core/` - Rule MODEL engine
  - `languagetool-server/` - HTTP API MODEL design
  - `languagetool-language-modules/` - Language-specific rule MODELs

---

**This plan is a living document. Update checklists as progress is made.**
**All implementations MUST adhere to the OOP principles outlined above.**
