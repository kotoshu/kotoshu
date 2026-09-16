# Language Namespace Architecture

## Overview

Kotoshu uses a sidecar directory structure for organizing language-specific code. Each language has its own directory under `lib/kotoshu/languages/` using ISO 639-1 language codes.

## Directory Structure

```
lib/kotoshu/
├── languages/                          # All language-specific code
│   ├── en/                             # English
│   │   ├── spell_checker.rb            # Kotoshu::Languages::English::SpellChecker
│   │   ├── tokenizer.rb                # Kotoshu::Languages::English::Tokenizer
│   │   ├── pos_tagger.rb               # Kotoshu::Languages::English::POSTagger
│   │   ├── grammar_rules.rb            # Kotoshu::Languages::English::GrammarRules
│   │   └── language.rb                 # Kotoshu::Languages::English (main class)
│   │
│   ├── de/                             # German (future)
│   │   ├── spell_checker.rb
│   │   ├── tokenizer.rb
│   │   ├── pos_tagger.rb
│   │   └── language.rb
│   │
│   └── fr/                             # French (future)
│       ├── spell_checker.rb
│       ├── tokenizer.rb
│       ├── pos_tagger.rb
│       └── language.rb
│
├── components/                         # Generic base components
│   ├── spell_checker.rb                # Abstract base class
│   ├── pos_tagger.rb                   # Abstract base class
│   ├── tokenizer.rb                    # Abstract base class
│   ├── whitespace_tokenizer.rb         # Generic whitespace tokenizer
│   └── ...
│
├── readers/                            # Dictionary readers (generic)
│   ├── lookup_builder.rb
│   ├── aff_data.rb
│   └── ...
│
├── language/                           # Language infrastructure
│   ├── base.rb                         # Base language class
│   └── registry.rb                     # Language registration
│
└── kotoshu.rb                          # Main entry point
```

## Namespace Conventions

### Language Module

Each language has its own module under `Kotoshu::Languages`:

```ruby
module Kotoshu
  module Languages
    module English  # or German, French, etc.
      # All language-specific classes go here
    end
  end
end
```

### Component Classes

Language-specific components follow this naming pattern:

| Component | Base Class | Naming Convention |
|-----------|-----------|-------------------|
| Spell Checker | `Components::SpellChecker` | `Languages::English::SpellChecker` |
| Tokenizer | `Components::Tokenizer` | `Languages::English::Tokenizer` |
| POS Tagger | `Components::PosTagger` | `Languages::English::POSTagger` |
| Grammar Rules | (None) | `Languages::English::GrammarRules` |
| Language Class | `Language::Base` | `Languages::English` |

## Adding a New Language

### Step 1: Create Directory Structure

```bash
mkdir -p lib/kotoshu/languages/{lang_code}
mkdir -p spec/kotoshu/languages/{lang_code}
```

Replace `{lang_code}` with the ISO 639-1 code (e.g., `de`, `fr`, `ja`).

### Step 2: Create Language Class

Create `lib/kotoshu/languages/{lang_code}/language.rb`:

```ruby
# frozen_string_literal: true

require_relative '../../language/base'
require_relative 'spell_checker'
require_relative 'tokenizer'
require_relative 'pos_tagger'

module Kotoshu
  module Languages
    module German  # Replace with actual language name
      class Language < Language::Base
        register "de"
        register "de-DE"
        register "de-AT"
        register "de-CH"

        # Dictionary paths
        HUNSPELL_DICTIONARIES = {
          'de-DE' => {
            aff: 'path/to/de_DE.aff',
            dic: 'path/to/de_DE.dic'
          }
          # Add other variants as needed
        }.freeze

        def initialize(code: "de", name: "German", variant: nil)
          variant ||= extract_region_code(code)
          super(code: code, name: name, variant: variant)
          @hunspell_paths = resolve_hunspell_paths(code)
        end

        # Factory methods
        def create_spell_checker
          German::SpellChecker.new(
            aff_path: @hunspell_paths[:aff],
            dic_path: @hunspell_paths[:dic],
            script: :latin,
            encoding: 'UTF-8'
          )
        end

        def create_tokenizer
          German::Tokenizer.new
        end

        def create_pos_tagger
          German::POSTagger.new(
            aff_path: @hunspell_paths[:aff],
            dic_path: @hunspell_paths[:dic],
            script: :latin,
            encoding: 'UTF-8'
          )
        end

        private

        def extract_region_code(code)
          return nil unless code.include?("-")
          code.split("-", 2).last.upcase
        end

        def resolve_hunspell_paths(code)
          HUNSPELL_DICTIONARIES[code] || HUNSPELL_DICTIONARIES['de-DE']
        end
      end
    end
  end
end
```

### Step 3: Implement Components

Create each component file following the template:

#### Spell Checker (`spell_checker.rb`)

```ruby
# frozen_string_literal: true

require_relative '../../../components/spell_checker'

module Kotoshu
  module Languages
    module German
      class SpellChecker < Components::SpellChecker
        def initialize(aff_path:, dic_path:, script:, encoding: 'UTF-8')
          @lookuper = Readers::LookupBuilder.new(
            aff_path, dic_path,
            encoding: encoding,
            script: script
          ).build
        end

        def check(word)
          first_form = @lookuper.good_forms(word).first
          return { found: false, stem: nil, flags: [] } unless first_form

          {
            found: true,
            stem: first_form.stem,
            flags: first_form.flags&.to_a || []
          }
        end

        def suggest(word, max_suggestions: 10)
          # Implement suggestion logic
          []
        end
      end
    end
  end
end
```

#### Tokenizer (`tokenizer.rb`)

```ruby
# frozen_string_literal: true

require_relative '../../../components/tokenizer'

module Kotoshu
  module Languages
    module German
      class Tokenizer < Components::Tokenizer
        def initialize
          # Initialize tokenizer
        end

        def tokenize(text)
          # Implement tokenization logic
          []
        end
      end
    end
  end
end
```

#### POS Tagger (`pos_tagger.rb`)

```ruby
# frozen_string_literal: true

require_relative '../../../components/pos_tagger'

module Kotoshu
  module Languages
    module German
      class POSTagger < Components::PosTagger
        FLAG_TO_POS = {
          # German-specific flag mappings
        }.freeze

        def initialize(aff_path:, dic_path:, script:, encoding: 'UTF-8', flag_mapping: FLAG_TO_POS)
          @aff_path = aff_path
          @dic_path = dic_path
          @script = script
          @encoding = encoding
          @flag_mapping = flag_mapping

          @lookuper = Readers::LookupBuilder.new(
            aff_path, dic_path,
            encoding: encoding,
            script: script
          ).build

          @lookup_cache = {}
        end

        def tag(tokens)
          # Implement POS tagging logic
          []
        end
      end
    end
  end
end
```

### Step 4: Update Language Loader

Add to `lib/kotoshu/languages.rb`:

```ruby
require_relative 'languages/en/language'
require_relative 'languages/de/language'  # Add new language
```

### Step 5: Create Tests

Create corresponding test files in `spec/kotoshu/languages/{lang_code}/`:

```
spec/kotoshu/languages/{lang_code}/
├── language_spec.rb
├── spell_checker_spec.rb
├── tokenizer_spec.rb
└── pos_tagger_spec.rb
```

## Language-Specific Considerations

### Script Types

Different scripts require different approaches:

| Script Type | Languages | Approach |
|-------------|-----------|----------|
| `:latin` | English, German, French, Spanish | Dictionary lookup with affix rules |
| `:cjk` | Chinese, Japanese, Korean | Confusion rule checking (no dictionary) |
| `:rtl` | Arabic, Hebrew | Dictionary lookup with bidirectional text handling |
| `:syllabic` | Devanagari, Bengali | Dictionary lookup with syllabic normalization |

### Dictionary Sources

1. **Hunspell dictionaries**: https://github.com/LibreOffice/dictionaries
2. **LanguageTool dictionaries**: https://github.com/languagetool-org/languagetool
3. **System dictionaries**: `/usr/share/dict/` on Unix-like systems

### Variant Support

For languages with regional variants (e.g., en-US, en-GB), create separate registrations and dictionary mappings:

```ruby
register "en"      # Base (falls back to en-US)
register "en-US"   # American English
register "en-GB"   # British English
```

## Critical Files for Language Integration

When adding a new language, these files may need updates:

1. **`lib/kotoshu/languages.rb`** - Add require for new language
2. **`lib/kotoshu/language/registry.rb`** - Auto-registration should pick up new language
3. **`lib/kotoshu/language.rb`** - Main loader (if using separate loading)

## Verification Checklist

After adding a new language:

- [ ] All component classes inherit from correct base classes
- [ ] Namespaces follow `Kotoshu::Languages::{LanguageName}::*` pattern
- [ ] Language class registers all supported codes
- [ ] Factory methods (`create_spell_checker`, etc.) return correct types
- [ ] Dictionary paths are correctly configured
- [ ] All tests pass
- [ ] Documentation is updated

## Anti-Patterns to Avoid

1. **DO NOT** put language-specific code in `lib/kotoshu/components/`
2. **DO NOT** use generic names like `SpellChecker` - always namespace under language module
3. **DO NOT** create duplicate files across multiple directories
4. **DO NOT** mix multiple languages in a single directory
5. **DO NOT** hardcode language-specific logic in generic components

## Example: English Reference Implementation

The English language implementation at `lib/kotoshu/languages/en/` serves as the reference for all new language implementations.

Key files:
- `language.rb` - Main language class with factory methods
- `spell_checker.rb` - Lookup-based spell checker
- `tokenizer.rb` - Whitespace tokenizer with contraction handling
- `pos_tagger.rb` - Hunspell flag-based POS tagging
- `grammar_rules.rb` - Grammar/style rule implementations
