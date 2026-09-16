# Kotoshu LanguageTool Gaps Analysis and Implementation Plan

> **Status:** Planning Phase
> **Last Updated:** 2026-01-30
> **Target:** Match or exceed LanguageTool CLI capabilities for 12 major languages

## Executive Summary

This document analyzes the gaps between Kotoshu's current implementation and LanguageTool's CLI capabilities, and provides a comprehensive plan to support 12 major languages with proper object-oriented architecture, separation of concerns, and lutaml-model-based serialization.

### Target Languages

1. **English** (en-US, en-GB, en-AU, en-CA, en-NZ, en-ZA)
2. **French** (fr-FR, fr-CA, fr-CH, fr-BE)
3. **German** (de-DE, de-AT, de-CH)
4. **Spanish** (es-ES, es-MX, es-AR, es-CL, es-CO, es-PE)
5. **Russian** (ru-RU)
6. **Arabic** (ar-SA, ar-EG, ar-MA, ar-TN)
7. **Portuguese** (pt-PT, pt-BR)
8. **Chinese Simplified** (zh-CN, zh-SG)
9. **Chinese Traditional** (zh-TW, zh-HK, zh-MO)
10. **Japanese** (ja-JP)
11. **Korean** (ko-KR)

---

## Part 1: Architectural Foundation

### 1.1 Directory Structure

```
lib/kotoshu/
├── language/                           # NEW: Language module
│   ├── registry.rb                     # Language registry
│   ├── detector.rb                     # Language detection
│   │
│   ├── tokenizer/                      # Tokenizer strategies
│   │   ├── base.rb                     # Abstract tokenizer
│   │   ├── latin_tokenizer.rb          # Base for European languages
│   │   ├── cjk_tokenizer.rb            # Base for East Asian languages
│   │   │
│   │   ├── english_tokenizer.rb
│   │   ├── french_tokenizer.rb
│   │   ├── german_tokenizer.rb
│   │   ├── spanish_tokenizer.rb
│   │   ├── portuguese_tokenizer.rb
│   │   ├── russian_tokenizer.rb
│   │   ├── arabic_tokenizer.rb
│   │   ├── chinese_tokenizer.rb
│   │   ├── chinese_simplified_tokenizer.rb
│   │   ├── chinese_traditional_tokenizer.rb
│   │   ├── japanese_tokenizer.rb
│   │   └── korean_tokenizer.rb
│   │
│   ├── normalizer/                     # Normalization strategies
│   │   ├── base.rb
│   │   ├── contraction_normalizer.rb
│   │   ├── accent_normalizer.rb
│   │   ├── compound_normalizer.rb
│   │   ├── pinyin_normalizer.rb
│   │   └── hangul_normalizer.rb
│   │
│   └── languages/                       # Language implementations
│       ├── base.rb
│       ├── english.rb                   # en-US, en-GB, etc.
│       ├── english_american.rb
│       ├── english_british.rb
│       ├── french.rb
│       ├── german.rb
│       ├── spanish.rb
│       ├── russian.rb
│       ├── arabic.rb
│       ├── portuguese.rb
│       ├── chinese_simplified.rb
│       ├── chinese_traditional.rb
│       ├── japanese.rb
│       └── korean.rb
│
├── dictionary/                         # Existing: Dictionary backends
│   ├── base.rb
│   ├── repository.rb
│   ├── plain_text.rb
│   ├── unix_words.rb
│   ├── custom.rb
│   ├── hunspell.rb
│   └── cspell.rb
│
├── output/                             # NEW: Output formatters
│   ├── formatter.rb
│   ├── base_formatter.rb
│   ├── text_formatter.rb
│   ├── json_formatter.rb
│   ├── xml_formatter.rb
│   ├── yaml_formatter.rb
│   └── checkstyle_formatter.rb
│
├── auto_corrector/                      # NEW: Auto-correction
│   ├── base.rb
│   ├── strategies/
│   │   ├── top_strategy.rb
│   │   ├── interactive_strategy.rb
│   │   └── smart_strategy.rb
│   └── context_analyzer.rb
│
├── cli/                                # NEW: CLI commands
│   ├── base_command.rb
│   ├── check_command.rb
│   ├── correct_command.rb
│   ├── analyze_command.rb
│   │   ├── tokenize_command.rb
│   │   ├── unknown_command.rb
│   │   └── suggestions_command.rb
│   ├── words_command.rb
│   │   ├── add_command.rb
│   │   ├── remove_command.rb
│   │   ├── list_command.rb
│   │   └── clear_command.rb
│   ├── dict_command.rb
│   │   ├── list_command.rb
│   │   ├── info_command.rb
│   │   └── install_command.rb
│   ├── config_command.rb
│   │   ├── get_command.rb
│   │   ├── set_command.rb
│   │   └── list_command.rb
│   └── languages_command.rb
│
├── models/                             # Existing: Result models
│   └── result/
│       └── document_result.rb
│
└── cli.rb                              # Main CLI entry point
```

### 1.2 Core Classes

#### Language::Registry

Single responsibility: Register and retrieve languages.

```ruby
module Kotoshu
  module Language
    class Registry
      @languages = {}

      class << self
        def register(code, language_class)
          @languages[code] = language_class
        end

        def get(code)
          @languages[code] || @languages[code.split('-').first]
        end

        def supported_codes
          @languages.keys.sort
        end

        def detect(text)
          Detector.detect(text)
        end
      end
    end
  end
end
```

#### Language::Base

Abstract base class following Template Method pattern.

```ruby
module Kotoshu
  module Language
    class Base
      attr_reader :code, :name, :variant, :region

      def initialize(code:, name:, variant: nil)
        @code = code
        @name = name
        @variant = variant
        @region = extract_region(code)
      end

      # Template methods - subclasses must implement
      def tokenizer
        raise NotImplementedError
      end

      def normalizer
        raise NotImplementedError
      end

      def dictionary_class
        raise NotImplementedError
      end

      def encoding
        'UTF-8'
      end

      def rtl?
        false
      end

      def script_type
        :latin
      end

      def default_dictionary_path
        []
      end

      private

      def extract_region(code)
        code.split('-').last.upcase
      end
    end
  end
end
```

#### Language::Tokenizer::Base

Strategy pattern for tokenization.

```ruby
module Kotoshu
  module Language
    module Tokenizer
      class Base
        def tokenize(text)
          raise NotImplementedError
        end

        protected

        def word_boundary_regex
          raise NotImplementedError
        end
      end
    end
  end
end
```

---

## Part 2: Language-Specific Requirements

### 2.1 English (en)

**Dialects:** en-US, en-GB, en-AU, en-CA, en-NZ, en-ZA

**Tokenization:**
- Contractions: ~50 common contractions (don't, won't, can't, I'm, you're, etc.)
- Smart quotes: Convert " and ' to typographic quotes
- Word boundary: Whitespace + punctuation

**Dictionary Sources:**
- `/usr/share/dict/words`
- `/usr/share/dict/american-english`
- `/usr/share/dict/british-english`

**Spelling Variants:**
- US: color, center, analyze
- GB: colour, centre, analyse

### 2.2 French (fr)

**Dialects:** fr-FR, fr-CA, fr-CH, fr-BE

**Tokenization:**
- Elision: l', d', s', c', j', m', n', qu', jusque, puisque
- Exception: la (does NOT elide)
- Apostrophe as word-internal: "j'ai" is ONE token
- Non-breaking spaces before: ; ? ! »
- Non-breaking space after: «
- Accents: é, è, ê, ë, à, â, ä, ç, ï, î, ô, ö, ù, û, ü

**Dictionary Sources:**
- `hunspell-french` gem
- `/usr/share/dict/french`

### 2.3 German (de)

**Dialects:** de-DE, de-AT, de-CH

**Tokenization:**
- Compound word splitting: Donaudampfschifffahrt → Donau + Dampf + Schiff + Fahrt
- Noun capitalization: All nouns capitalized
- Umlauts: ä, ö, ü, ß (eszett)
- CamelCase compounds: autoSplit

**Dictionary Sources:**
- `hunspell-de-de` gem
- `/usr/share/dict/ngerman`

### 2.4 Spanish (es)

**Dialects:** es-ES, es-MX, es-AR, es-CL, es-CO, es-PE

**Tokenization:**
- Inverted punctuation: ¡ ! at sentence start
- Apostrophe handling: n's, t's, s', etc.
- Accents: á, é, í, ó, ú, ñ, ü

**Dictionary Sources:**
- `hunspell-es` gem
- `/usr/share/dict/spanish`

### 2.5 Russian (ru)

**Dialects:** ru-RU, uk-UA, be-BY

**Tokenization:**
- Cyrillic alphabet: 33 letters
- Diacritics: ё vs е
- Word boundary: Whitespace + punctuation

**Dictionary Sources:**
- `hunspell-ru` gem
- `ispell` dictionaries

### 2.6 Arabic (ar)

**Dialects:** ar-SA, ar-EG, ar-MA, ar-TN

**Tokenization:**
- Script direction: Right-to-left (RTL)
- Character set: Arabic letters (28 consonants + 3 vowels)
- Diacritics (Tashkeel): Fatha, Kasra, Damma, Sukun, Shadda, Tanwin
- Ligatures: lam-alif (لا)
- Hamza variants
- Word boundary: Different from Latin scripts

**Dictionary Sources:**
- `hunspell-ar` gem
- Custom word lists

### 2.7 Portuguese (pt)

**Dialects:** pt-PT, pt-BR

**Tokenization:**
- Accents: á, à, â, ã, é, ê, í, ó, ô, õ, ú, ç
- Circumflex: â, ê, ô
- Tilde: ã, õ
- Contractions: do, da, dum, dele, dele

**Dictionary Sources:**
- `hunspell-pt-PT` gem (Portugal)
- `hunspell-pt-BR` gem (Brazil)
- `/usr/share/dict/portuguese`

### 2.8 Chinese Simplified (zh-CN)

**Script:** No spaces between words (character-based)

**Tokenization:**
- Character-based: Each character is a potential word
- Segmentation: Required for multi-character words
- Pinyin: Romanization for input/output
- Characters: ~7,000 commonly used

**Dictionary Sources:**
- CC-CEDICT
- libtabe

### 2.9 Chinese Traditional (zh-TW)

**Script:** No spaces between words (character-based)

**Tokenization:**
- Character-based with segmentation
- Regional variants: TW vs HK
- Characters: ~13,000 commonly used

**Dictionary Sources:**
- CC-CEDICT
- libtabe

### 2.10 Japanese (ja)

**Writing Systems:**
- Kanji (Chinese characters): ~2,000 commonly used
- Hiragana (46 base characters)
- Katakana (46 base characters)
- Romaji (Latin alphabet)

**Tokenization:**
- Mixed script detection
- Spaces: Sometimes used between phrases
- Segmentation: MeCab-based

**Dictionary Sources:**
- MeCab with ipadic dictionary
- SudachiDict (optional)

### 2.11 Korean (ko)

**Script:** Hangul (alphabet) + Hanja (Chinese characters)

**Tokenization:**
- Hangul syllables: ~11,172 possible combinations
- Spaces: Used between words
- Segmentation: mecab-ko-dic

**Dictionary Sources:**
- mecab-ko-dic

---

## Part 3: CLI Command Structure

### 3.1 Current Kotoshu Commands

```bash
kotoshu check [TARGET]           # Check text/file/stdin
kotoshu dict list                # List dictionaries
kotoshu dict info TYPE            # Dictionary info
kotoshu version                  # Version info
```

### 3.2 Proposed Enhanced Commands

#### Core Commands

```bash
# Checking
kotoshu check [TARGET]           # Check text/file/dir/stdin
kotoshu check -r src/             # Recursive directory check
kotoshu check --apply input.txt  # Auto-correct and output
kotoshu correct [TARGET]         # Alias for check --apply

# Dictionary
kotoshu dict list                # List available dictionaries
kotoshu dict info en-US           # Dictionary/language info
kotoshu dict install fr           # Install French dictionary

# Words (personal dictionary)
kotoshu words add WORD           # Add to personal dict
kotoshu words remove WORD        # Remove from personal dict
kotoshu words list               # List personal words
kotoshu words clear              # Clear personal dict

# Analysis
kotoshu analyze tokenize FILE    # Show tokenization
kotoshu analyze unknown FILE     # List unknown words
kotoshu analyze suggestions FILE # Detailed suggestions

# Configuration
kotoshu config get KEY           # Get config value
kotoshu config set KEY VALUE     # Set config value
kotoshu config list              # List all config

# Info
kotoshu languages                # List supported languages
kotoshu version                  # Version info
```

#### Command Options

```bash
# Core options
-v, --verbose                    # Verbose output
-q, --quiet                      # Quiet mode
-h, --help                       # Show help
--version                       # Show version

# Language options
-l, --language LANG              # Language code (en-US, de-DE, etc.)
-a, --auto-detect                # Auto-detect language

# Dictionary options
-d, --dictionary TYPE            # Dictionary backend
-p, --dictionary-path PATH       # Dictionary file path
--personal-dict PATH            # Personal dictionary path

# Processing options
-r, --recursive                  # Process directories recursively
--line-by-line                  # Process line by line (large files)
-b, --single-line-breaks         # Single newline = paragraph break
--encoding ENC                  # Character encoding

# Filter options
--include PATTERN               # File pattern to include
--exclude PATTERN               # File pattern to exclude
--ignore-pattern REGEX          # Ignore words matching pattern
--ignore-file PATH              # File with ignore patterns

# Output options
-o, --output FORMAT              # Output format (text, json, xml, yaml)
-c, --color                      # Colorize output
--no-color                      # Disable color
-u, --list-unknown               # List unknown words

# Suggestion options
-m, -n, --max-suggestions N      # Maximum suggestions
--distance N                    # Max edit distance

# Advanced options
--threads N                     # Thread count for parallel processing
--profile                       # Show performance profile
--debug                         # Debug mode
```

---

## Part 4: Output Formats (lutaml-model)

### 4.1 Output Models

All output models use lutaml-model for proper serialization.

```ruby
module Kotoshu
  module Output
    module Model
      class CheckResult < Lutaml::Model::Serializable
        attribute :source, String
        attribute :language, String
        attribute :language_code, String
        attribute :success, Boolean, default: true
        attribute :word_count, Integer, default: 0
        attribute :char_count, Integer, default: 0
        attribute :line_count, Integer, default: 0
        attribute :error_count, Integer, default: 0
        attribute :warning_count, Integer, default: 0
        attribute :info_count, Integer, default: 0
        attribute :errors, Array[Error], default: []
        attribute :warnings, Array[Warning], default: []
        attribute :infos, Array[Info], default: []
        attribute :timestamp, String
        attribute :duration_ms, Integer
      end

      class Error < Lutaml::Model::Serializable
        attribute :id, String
        attribute :word, String
        attribute :position, Position
        attribute :suggestions, Array[Suggestion], default: []
        attribute :severity, String, default: 'error'
        attribute :category, String, default: 'spelling'
        attribute :message, String
        attribute :rule_id, String
        attribute :url, String
        attribute :context, String
        attribute :context_before, String
        attribute :context_after, String
      end

      class Suggestion < Lutaml::Model::Serializable
        attribute :word, String
        attribute :distance, Integer, default: 0
        attribute :confidence, Float, default: 1.0
        attribute :source, String, default: 'spelling'
      end

      class Position < Lutaml::Model::Serializable
        attribute :line, Integer
        attribute :column, Integer
        attribute :offset, Integer
        attribute :length, Integer
      end
    end
  end
end
```

### 4.2 Output Formats

| Format | Purpose | Usage |
|--------|---------|------|
| **text** | Human-readable terminal output | Default terminal output |
| **json** | Machine-readable, API compatible | CI/CD pipelines, web APIs |
| **xml** | IDE integration | Checkstyle format for IDEs |
| **yaml** | Human-readable config | Configuration files, reports |
| **checkstyle** | IDE integration | Jenkins, SonarQube |

---

## Part 5: Implementation Roadmap

### Phase 1: Core Infrastructure (Weeks 1-2)

**Tasks:**
1. Create language module directory structure
2. Implement Language::Registry
3. Implement Language::Base
4. Implement Language::Detector
5. Implement Tokenizer::Base
6. Implement LatinTokenizer (base for European languages)
7. Implement Normalizer::Base
8. Update main kotoshu.rb with new modules
9. Write unit tests for core infrastructure

### Phase 2: English and German (Weeks 3-4)

**Tasks:**
1. Implement English language class
2. Implement EnglishTokenizer (contractions, smart quotes)
3. Implement ContractionNormalizer
4. Add spelling variant support (color/colour)
5. Implement German language class
6. Implement GermanTokenizer (compound words)
7. Implement CompoundNormalizer
8. Add jWordSplitter integration
9. Register both with Language::Registry
10. Write comprehensive tests

### Phase 3: French and Spanish (Weeks 5-6)

**Tasks:**
1. Implement French language class
2. Implement FrenchTokenizer (apostrophes, elision)
3. Implement Spanish language class
4. Implement SpanishTokenizer (inverted punctuation)
5. Implement accent normalization for both
6. Register both with Language::Registry
7. Write tests

### Phase 4: Portuguese and Russian (Weeks 7-8)

**Tasks:**
1. Implement Portuguese language class
2. Implement PortugueseTokenizer (accents)
3. Implement Russian language class
4. Implement CyrillicTokenizer (base)
5. Implement RussianTokenizer
6. Register both with Language::Registry
7. Write tests

### Phase 5: Arabic and Chinese (Weeks 9-10)

**Tasks:**
1. Implement Arabic language class
2. Implement ArabicTokenizer (RTL support)
3. Implement ChineseSimplified language class
4. Implement ChineseTokenizer (character-based)
5. Implement ChineseTraditional language class
6. Add segmentation support
7. Register all with Language::Registry
8. Write tests

### Phase 6: Japanese and Korean (Weeks 11-12)

**Tasks:**
1. Implement Japanese language class
2. Implement JapaneseTokenizer (mixed script)
3. Add MeCab integration
4. Implement Korean language class
5. Implement KoreanTokenizer (Hangul)
6. Add mecab-ko integration
7. Register both with Language::Registry
8. Write tests

### Phase 7: CLI Enhancement (Weeks 13-14)

**Tasks:**
1. Implement new CLI command structure
2. Create CheckCommand with all options
3. Create CorrectCommand (alias for check --apply)
4. Create AnalyzeCommand (tokenize, unknown, suggestions)
5. Create WordsCommand (add, remove, list, clear)
6. Create DictCommand (list, info, install)
7. Create ConfigCommand (get, set, list)
8. Create LanguagesCommand
9. Write integration tests

### Phase 8: Output Formatters (Weeks 15-16)

**Tasks:**
1. Implement output models using lutaml-model
2. Create JsonFormatter
3. Create XmlFormatter (Nokogiri-based)
4. Create YamlFormatter
5. Create CheckstyleFormatter (IDE integration)
6. Update text formatter with context display
7. Write tests for all formatters

### Phase 9: Auto-Correction (Weeks 17-18)

**Tasks:**
1. Implement AutoCorrector base class
2. Implement TopCorrectionStrategy
3. Implement InteractiveCorrectionStrategy
4. Implement SmartCorrectionStrategy
5. Implement ContextAnalyzer
6. Add CLI integration
7. Write tests

### Phase 10: Advanced Features (Weeks 19-20)

**Tasks:**
1. Implement recursive directory processing
2. Implement file pattern filtering
3. Implement ignore patterns
4. Implement language auto-detection
5. Implement parallel processing
6. Add performance profiling
7. Write integration tests
8. Update documentation

**Total Timeline: 20 weeks (~5 months)**

---

## Part 6: Dependencies

### 6.1 Required Gems

```ruby
# Existing
gem 'thor', '~> 1.0'                  # CLI framework
gem 'moxml', '~> 1.0'                  # XML parsing
gem 'lutaml-model', '~> 0.7'         # Serialization
gem 'parallel', '~> 1.20'             # Parallel processing

# New dependencies
gem 'nokogiri', '~> 1.15'              # XML generation
gem 'json', '~> 2.6'                   # JSON (built-in)

# Optional (for language-specific features)
gem 'mecab', '~> 0.99'                 # Japanese tokenization
gem 'ffi'                             # For jWordSplitter (German)
```

### 6.2 External Dictionary Sources

| Language | System Path | Gem |
|----------|-------------|-----|
| English (en-US) | `/usr/share/dict/words`, `/usr/share/dict/american-english` | - |
| English (en-GB) | `/usr/share/dict/british-english` | - |
| French | `/usr/share/dict/french` | `hunspell-french` |
| German | `/usr/share/dict/ngerman` | `hunspell-de-de` |
| Spanish | `/usr/share/dict/spanish` | `hunspell-es` |
| Russian | `/usr/share/dict/russian` | `hunspell-ru` |
| Portuguese (pt-BR) | `/usr/share/dict/portuguese` | `hunspell-pt-BR` |
| Portuguese (pt-PT) | - | `hunspell-pt-PT` |
| Arabic | - | `hunspell-ar` |
| Chinese | - | CC-CEDICT, libtabe |
| Japanese | `/usr/share/mecab/dic/ipadic` | `mecab`, `mecab-ruby` |
| Korean | `/usr/share/mecab/dic/mecab-ko-dic` | `mecab-ko` |

---

## Part 7: Key Architectural Decisions

### 7.1 Modularity Over Monolith

Each language is a separate module with its own:
- Tokenizer (handles language-specific word boundaries)
- Normalizer (handles contractions, accents, etc.)
- Dictionary configuration
- Language-specific rules

### 7.2 Strategy Pattern

Tokenizers, normalizers, and formatters use pluggable strategies:
- Different languages can use different tokenization strategies
- New languages can be added without modifying existing code
- Output formats are extensible

### 7.3 Registry Pattern

Languages are registered in a central registry:
- Auto-discovery of supported languages
- Query by language code
- Language auto-detection

### 7.4 Separation of Concerns

Each module has a single responsibility:
- **Registry**: Registration only
- **Detector**: Detection only
- **Tokenizer**: Tokenization only
- **Normalizer**: Normalization only
- **Formatter**: Formatting only
- **Command**: Execution only

### 7.5 lutaml-model Serialization

All output models use proper OOP serialization:
- JSON (machine-readable, API compatible)
- XML (IDE integration, Checkstyle format)
- YAML (human-readable configuration)
- Plain text (terminal output)
- **NO CSV** (replaced by structured formats)

---

## Part 8: Comparison with LanguageTool

| Feature | LanguageTool | Kotoshu (Planned) |
|---------|--------------|-------------------|
| **Architecture** | Java monolithic | Ruby modular OOP |
| **CLI Parser** | Custom (hand-rolled) | Thor (standard) |
| **Tokenization** | Per-language classes | Strategy pattern |
| **Output Formats** | JSON, XML, Plain | JSON, XML, YAML, Checkstyle |
| **Auto-correction** | Yes | Yes (3 strategies) |
| **Language Detection** | FastText + n-gram | Character set + patterns |
| **Languages** | 30+ | 12 major languages |
| **Rule System** | XML rules | Dictionary + future rules |
| **Dictionary Backends** | Hunspell only | 5+ backends |
| **CLI Options** | 40+ options | Comprehensive coverage |
| **Modularity** | Monolithic jar | Modular gem |

### Kotoshu Advantages

1. **Cleaner, more maintainable Ruby code**
2. **Modular architecture** (easier to extend)
3. **Better CLI experience** (Thor vs custom parser)
4. **More output formats** (includes YAML and Checkstyle)
5. **Multiple dictionary backends** (not just Hunspell)
6. **Auto-correction with multiple strategies**
7. **Language-specific tokenization** from the start
8. **Proper OOP design** (inheritance, polymorphism, composition)

---

## Part 9: Success Criteria

Implementation success will be measured by:

- [ ] All 12 languages working with proper tokenization
- [ ] Auto-detection accuracy > 90% for text samples
- [ ] All output formats producing valid serialization
- [ ] Recursive directory processing scales to 1000+ files
- [ ] Auto-correction produces valid output
- [ ] Test coverage > 80% for new modules
- [ ] Performance: < 100ms for single file check
- [ ] Performance: < 10s for 1000 files in parallel
- [ ] Zero breaking changes to existing API
- [ ] Backward compatible with current kotoshu.rb interface

---

## Part 10: Testing Strategy

### 10.1 Unit Tests

- Language Registry tests
- Language Detector tests
- Tokenizer tests for each language
- Normalizer tests
- Output formatter tests
- CLI command tests

### 10.2 Integration Tests

- Multi-language check tests
- Auto-correction tests
- Recursive directory tests
- Output format validation tests

### 10.3 Performance Tests

- Tokenization performance per language
- Language detection performance
- Large file processing
- Parallel directory processing

### 10.4 Test Fixtures

```
spec/fixtures/texts/
├── en/ sample_en_us.txt
├── fr/ sample_fr.txt
├── de/ sample_de.txt
├── es/ sample_es.txt
├── ru/ sample_ru.txt
├── ar/ sample_ar.txt
├── pt/ sample_pt_br.txt
├── zh-CN/ sample_zh_cn.txt
├── zh-TW/ sample_zh_tw.txt
├── ja/ sample_ja.txt
└── ko/ sample_ko.txt
```

---

## Appendix: Character Encoding Reference

### Character Sets by Language

| Language | Character Range | Notes |
|----------|----------------|-------|
| **Arabic** | U+0600-U+06FF | RTL script |
| **Cyrillic** | U+0400-U+04FF | Russian, Ukrainian |
| **CJK Unified** | U+4E00-U+9FFF | Common CJK |
| **CJK Ext A** | U+3400-U+4DBF | Rare CJK |
| **CJK Ext B** | U+20000-U+2A6DF | Rare CJK |
| **Hangul** | U+AC00-U+D7AF | Korean |
| **Hiragana** | U+3040-U+309F | Japanese |
| **Katakana** | U+30A0-U+30FF | Japanese |
| **Latin** | U+0000-U+007F + extensions | European languages |

### Unicode Blocks for Language Detection

```ruby
CHARACTER_SETS = {
  arabic: /[\u0600-\u06FF]/,
  cyrillic: /[\u0400-\u04FF]/,
  cjk: /[\u4E00-\u9FFF]/,
  hiragana: /[\u3040-\u309F]/,
  katakana: /[\u30A0-\u30FF]/,
  hangul: /[\uAC00-\uD7AF]/,
  latin: /[a-zA-Zà-ÿ]/,
}.freeze
```

---

*End of Document*
