# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Running Tests
```bash
bundle exec rspec                    # Run all tests
bundle exec rspec spec/path/to_spec  # Run a specific test file
```

### Linting
```bash
bundle exec rubocop                  # Run linter
bundle exec rubocop -A               # Auto-fix lint issues
```

### Default Task
```bash
bundle exec rake                     # Run tests and linter (default task)
```

### Console
```bash
bin/console                         # Start IRB with kotoshu loaded
```

### Build and Install Locally
```bash
gem build kotoshu.gemspec
gem install kotoshu-*.gem
```

## Architecture

**Detailed architecture documentation is available in:**
- `KOTOSHU_ARCHITECTURE.md` - Complete architectural design and patterns
- `KOTOSHU_FULL_PLAN.md` - Implementation plan with progress checklist

Kotoshu is a spellchecker library designed with a modular, object-oriented architecture supporting multiple interfaces (CLI, Ruby API) and multiple dictionary backends.

### Architectural Principles

**Hexagonal Architecture (Ports and Adapters):**
- Domain Layer: Core business logic, completely independent of interfaces
- Application Layer: Use cases that orchestrate domain operations
- Interface Layer: Adapters for CLI and Ruby API (HTTP API in future separate gem)

**Key Design Patterns:**
- **Facade Pattern**: `Kotoshu.spellcheck()` provides simple public API
- **Command Pattern**: CLI commands are encapsulated classes
- **Strategy Pattern**: Pluggable dictionary backends and suggestion algorithms
- **Registry Pattern**: Plugin system for custom backends and algorithms
- **Value Objects**: Result objects are immutable and easily serializable

### Quick Reference: Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                        Interface Layer                         │
├──────────────────────────┬────────────────────────────────────┤
│      CLI (Thor)          │          Ruby API                  │
│   lib/kotoshu/cli/       │      Public Facade Methods        │
└──────────────┬───────────┴────────────────┬───────────────────┘
               │                             │
               └─────────────┬───────────────┘
                             │
        ┌────────────────────┴────────────────────┐
        │      Application Layer (Facades)         │
        │  spellchecker.rb | configuration.rb      │
        └────────────────────┬────────────────────┘
                             │
        ┌────────────────────┴────────────────────┐
        │      Domain Layer (Core Logic)           │
        │   Dictionary Backends | Suggestion Algs │
        │   Hunspell | CSpell | UnixWords | Custom│
        └──────────────────────────────────────────┘
```

### Public API (Ruby Interface)

```ruby
# Simple single-word check
Kotoshu.correct?("hello")  # => true
Kotoshu.check("hello")     # => Result object

# With suggestions
Kotoshu.suggest("helo")     # => ["hello", "help", "he'll", ...]

# Document checking
Kotoshu.check_file("README.md")           # => DocumentResult
Kotoshu.check_string("Hello wrold")       # => DocumentResult

# Configuration
Kotoshu.configure do |config|
  config.dictionary_path = "/usr/share/dict/words"
  config.dictionary_type = :unix_words
  config.language = "en-US"
  config.max_suggestions = 10
end
```

### CLI Interface (Thor-based)

```bash
# Check spelling
kotoshu check "Hello wrold"
kotoshu check file.txt
kotoshu check project/

# Options
kotoshu check --dictionary=unix_words --output=json file.txt

# Dictionary management
kotoshu dict list
kotoshu dict info en-US
```

### Class Structure Summary

```
lib/kotoshu/
├── version.rb                          # Version constant
├── spellchecker.rb                     # Main Spellchecker class
├── configuration.rb                    # Configuration management
├── registry.rb                         # Plugin registry
│
├── core/                               # Domain Layer
│   ├── models/                         # Value objects
│   │   ├── word.rb
│   │   ├── affix_rule.rb
│   │   ├── suggestion.rb
│   │   └── result/                     # Result objects
│   ├── trie/                           # Trie data structure
│   └── exceptions.rb                   # Exception hierarchy
│
├── dictionary/                         # Dictionary backends
│   ├── base.rb                         # Abstract interface
│   ├── hunspell.rb                     # Hunspell (.dic/.aff)
│   ├── cspell.rb                       # CSpell (.txt/.trie)
│   ├── unix_words.rb                   # Unix system dictionary
│   ├── plain_text.rb                   # Plain text word lists
│   └── custom.rb                       # Runtime custom dictionary
│
├── suggestions/                        # Suggestion algorithms
│   ├── generator.rb                    # Orchestrates algorithms
│   ├── base.rb                         # Abstract algorithm
│   └── algorithms/
│       ├── edit_distance.rb
│       ├── phonetic.rb
│       └── [other algorithms]
│
└── cli/                                # CLI Adapter
    ├── cli.rb                          # Main Thor class
    └── commands/                       # Command classes
        ├── check_command.rb
        ├── dict_command.rb
        └── version_command.rb
```

## Design Principles

**Object-Oriented, Model-Driven Architecture:**
- Use plain Ruby classes (not `lutaml-model`) for performance
- Each component has a single responsibility with a clear API
- Model the domain (words, dictionaries, affix rules, suggestions) as objects
- No serialization concerns in the core library

**Modularity and Extensibility:**
- Dictionary backends are pluggable via the `Register` module
- Suggestion algorithms are separate, composable classes
- Language-specific rules are encapsulated in strategy objects

**Performance:**
- Hash-based lookups for Hunspell dictionaries
- Trie-based lookups for CSpell dictionaries (O(n) word lookup)
- Efficient string operations for edit distance and n-gram calculations
- Lazy loading of dictionaries and affix rules

## Dictionary Backend Comparison

| Feature | Hunspell | CSpell | UnixWords | PlainText |
|---------|----------|--------|-----------|-----------|
| Approach | Morphological rules | Dictionary-based (trie) | System word list | Simple word list |
| File Format | `.dic` + `.aff` | `.txt`, `.trie` | `/usr/share/dict/words*` | `.txt` |
| Best For | Natural language inflection | Code/technical terms | Unix spell integration | Custom word lists |
| Performance | Hash lookup + affix processing | Trie lookup (very fast) | Hash lookup | Hash lookup |
| Suggestion Quality | High (morphological awareness) | Medium | Low | Low |
| Memory Usage | Medium | Low (compressed trie) | Medium (~2.4MB) | Low |
| Compound Words | Yes | Limited | No | No |

\* UnixWords typically uses symlinks to dictionary files like `web2` (Webster's Second International, ~236K words) or language-specific variants.

### Hunspell Dictionary Format

**Dictionary File (.dic):**
```
<word_count>
<word>/<flags>
<word>/<flags>
...
```

**Affix File (.aff):**
- `SET` - Character encoding (UTF-8, ISO-8859-1, etc.)
- `TRY` - Characters to try for suggestions
- `REP` - Character replacement rules
- `PFX/SFX` - Prefix and suffix rules with conditions
- `COMPOUNDRULE` - Compound word formation rules

### CSpell Dictionary Format

**Plain Text Format (.txt):**
```
# Comments start with #
journal
journalism
Big Apple
New York
```

**Compressed Trie Format (.trie):**
```
#!/usr/bin/env cspell-trie reader
TrieXv3
base=10
__DATA__
Big Apple$8races\: \{\}\[\]\(\)$9<5
New York$7umbers \0\1\2\3\4\5\6\7\8\9$9<9
```

CSpell uses DAFSA (Deterministic Acyclic Finite State Automaton) for efficient trie compression.

### UnixWords Dictionary Format

The Unix "spell" command uses system dictionaries typically located at `/usr/share/dict/words`.

**Format:**
```
A
a
aa
aal
aalii
aam
Aani
aardvark
...
```

**Characteristics:**
- Simple line-separated format (one word per line)
- Case-sensitive variants (both "A" and "a" exist)
- Typically symlinked to dictionary files like `web2` (Webster's Second International)
- Common variants include: `web2`, `web2a`, `words`, `american-english`, `british-english`
- File size: ~2.4MB for ~236K words (web2)

**System Paths (in order of precedence):**
- `/usr/share/dict/words` (standard symlink)
- `/usr/share/dict/web2` (Webster's Second International)
- `/usr/dict/words` (legacy path)
- `/usr/share/dict/american-english`
- `/usr/share/dict/british-english`

**Language Variants:**
- `american-english` - US English spellings
- `british-english` - UK English spellings
- `words` - May be locale-specific based on system configuration

## Error Handling Strategy

**Exception Hierarchy:**
```ruby
Kotoshu::Error (base)
├── Kotoshu::DictionaryNotFoundError
├── Kotoshu::InvalidDictionaryFormatError
├── Kotoshu::ConfigurationError
└── Kotoshu::SpellcheckError
```

**Interface-Specific Error Translation:**
- **CLI**: Catches exceptions, displays user-friendly messages, exits with appropriate code
- **Ruby API**: Propagates exceptions for caller to handle
- **HTTP API (future)**: Catches exceptions, returns JSON with appropriate HTTP status codes

## Configuration System

**Configuration Chain** (highest to lowest priority):
1. Runtime parameters (method arguments, CLI flags)
2. Environment variables (`KOTOSHU_*`)
3. Config file (`.kotoshurc.yml`, `~/.kotoshu/config.yml`) - future
4. Defaults

**Example Configuration:**
```ruby
Kotoshu.configure do |config|
  config.dictionary_path = "/usr/share/dict/words"
  config.dictionary_type = :unix_words
  config.language = "en-US"
  config.max_suggestions = 10
  config.suggestion_algorithms = [:edit_distance, :phonetic]
  config.case_sensitive = false
  config.custom_words = ["Kotoshu", "GitHub"]
  config.verbose = true
end
```

## Plugin System

**Register Custom Dictionary Backend:**
```ruby
class MyCustomDictionary < Kotoshu::Dictionary::Base
  Kotoshu::Dictionary.register_type(:my_custom, self)

  def lookup(word)
    # Custom lookup logic
  end
end
```

**Register Custom Suggestion Algorithm:**
```ruby
class MyCustomAlgorithm < Kotoshu::Suggestions::Base
  Kotoshu::Suggestions.register_algorithm(:my_custom, self)

  def generate(word, max_results: 5)
    # Custom suggestion logic
  end
end
```

## Code Style

- Ruby 3.1+ required
- `frozen_string_literal: true` in all files
- Double quotes for strings (enforced by RuboCop)
- 2-space indentation
- 80-character line limit (where practical)

## Type Signatures

RBS type signatures are defined in `sig/kotoshu.rbs`. Update these when adding or modifying public APIs.

## Reference Implementations

### Hunspell Reference
Location: `/Users/mulgogi/src/external/hunspell/`

The Hunspell library serves as the reference for morphological spell checking. Key concepts:

- **AffixMgr** - Affix rule processing (lib/hunspell/affixmgr.hxx)
- **HashMgr** - Dictionary word lookups (lib/hunspell/hashmgr.hxx)
- **SuggestMgr** - Suggestion generation (lib/hunspell/suggestmgr.hxx)
- **Dictionary format** - .dic and .aff file structure (tests/ directory)
- **Compound words** - Complex compounding rules for languages like German
- **Morphological analysis** - Word stem extraction and generation

### CSpell Reference
Location: `/Users/mulgogi/src/external/cspell/`

CSpell serves as the reference for code-aware spell checking and trie-based dictionaries. Key concepts:

- **Trie structure** - cspell-trie-lib package for compressed trie (DAFSA)
- **Dictionary loading** - cspell-dictionary package for multi-format support
- **Suggestion algorithms** - Edit distance with weighted character costs
- **Configuration** - cspell-config-lib for flexible dictionary management
- **Performance** - cspell-io package for caching and lazy loading
- **Multi-format support** - Both plain text and compressed trie formats

### LanguageTool Reference
Location: `/Users/mulgogi/src/external/languagetool/`

LanguageTool serves as the reference for advanced grammar/style checking and multi-interface design. Key concepts:

- **Rule-based architecture** - XML-defined pattern rules for grammar/style checking
- **Multi-language support** - Pluggable language modules with automatic detection
- **Dual interface design** - Both Java library and HTTP server (pattern for our future HTTP API)
- **Performance optimization** - Multi-level caching (ResultCache, sentence analysis, remote rules)
- **Configuration system** - UserConfig with rule enable/disable, custom words, premium tokens
- **Thread safety** - Per-instance creation, immutable configuration, concurrent collections
- **Pipeline processing** - Parallel processing of different rule types for performance
- **Rule categories** - TYPOS, GRAMMAR, PUNCTUATION, STYLE, CONFUSION_WORDS, etc.

Key patterns from LanguageTool for Kotoshu:
1. **Rule-based system** - Extensible rule interface for future grammar checking
2. **Multi-language detection** - Language detection with confidence scoring
3. **HTTP API design** - RESTful API with versioning (/v2/check), rate limiting, authentication
4. **Performance caching** - Multiple cache layers for expensive operations
5. **Configuration hierarchy** - User preferences → rule configuration → defaults

### Cross-Reference Learning Matrix

| Feature | Hunspell | CSpell | LanguageTool | Kotoshu Approach |
|---------|----------|--------|--------------|------------------|
| Dictionary Format | .dic/.aff (morphological) | .txt/.trie (code-aware) | Multiple formats | All via plugins |
| Lookup Performance | Hash + affix | Trie (DAFSA) | Cached | Repository cache |
| Suggestion Quality | High (morphological) | Medium | High (context) | Pluggable algos |
| Multi-language | Affix rules per lang | Multiple dicts | Lang detection | Via configuration |
| Interface | C++ library | CLI + library | Library + HTTP | CLI + Ruby + HTTP |
| Extensibility | Limited | Plugin system | Rule system | Registry pattern |

When implementing new features, study all three reference implementations:
1. How Hunspell handles morphological rules and affix processing
2. How CSpell achieves fast lookups with compressed tries
3. How LanguageTool designs multi-interface APIs (library + HTTP)
4. How each generates suggestions (different algorithms and strategies)
5. How to balance between accuracy and performance
6. How to design rule-based systems for future grammar checking
