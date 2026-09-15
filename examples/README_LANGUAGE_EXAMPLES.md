# Language Examples

This directory contains example scripts demonstrating how to use Kotoshu's language-specific features for each supported language.

## Quick Start

```ruby
require 'bundler/setup'
require 'kotoshu'

# Create language instance
english = Kotoshu::Languages::English.new

# Spell checking
english.correct?("hello")  # => true
english.correct?("helo")   # => false

# Suggestions
english.suggest("helo")    # => ["hello", "help", ...]

# Tokenization
english.tokenize("Hello world!")  # => [{token: "Hello", ...}, ...]

# POS tagging
tokens = english.tokenize("The cat sleeps")
tagged = english.create_pos_tagger.tag(tokens)

# Grammar rules
tokens = english.tokenize("a apple")
issues = english.create_grammar_rules.check(tokens)
```

## Examples

| File | Language | Script | Key Features |
|------|----------|--------|--------------|
| `en_english_example.rb` | English | Latin | Hunspell, contractions (I'm, don't), a/an rules |
| `fr_french_example.rb` | French | Latin | Accent handling (é, è, ç), apostrophe contractions |
| `de_german_example.rb` | German | Latin | Umlaut handling (ä, ö, ü, ß), noun capitalization |
| `ja_japanese_example.rb` | Japanese | CJK | Suika morphological analyzer, particle system |
| `pt_portuguese_example.rb` | Portuguese | Latin | Accent recovery, crase detection (à vs a) |
| `ru_russian_example.rb` | Russian | Cyrillic | Cyrillic character substitutions, 6 grammatical cases |
| `es_spanish_example.rb` | Spanish | Latin | Inverted punctuation (¿, ¡), accent distinction |

## Running Examples

```bash
# Run all language examples
ruby examples/en_english_example.rb
ruby examples/fr_french_example.rb
ruby examples/de_german_example.rb
ruby examples/ja_japanese_example.rb
ruby examples/pt_portuguese_example.rb
ruby examples/ru_russian_example.rb
ruby examples/es_spanish_example.rb

# Or run with bundler
bundle exec ruby examples/en_english_example.rb
```

## Features by Language

### English (`Kotoshu::Languages::English`)
- Hunspell-based spell checking with en_US dictionary
- Contraction expansion (can't → can not, I'm → I am)
- A/An article rules based on vowel sounds
- POS tagging via Hunspell flag mappings

### French (`Kotoshu::Languages::French`)
- French-specific character substitutions
- Accent recovery in suggestions
- French apostrophe contractions (l'école, d'accord)
- Article + noun gender agreement

### German (`Kotoshu::Languages::German`)
- German umlaut handling (ä→ae, ö→oe, ü→ue, ß→ss)
- Compound word support
- Noun capitalization rules (all nouns capitalized)
- POS tagging for German morphology

### Japanese (`Kotoshu::Languages::Japanese`)
- Suika morphological analyzer for CJK
- Script detection (Kanji, Hiragana, Katakana)
- Japanese particle system (が, を, に, は, の)
- Proper noun detection (geographic names)

### Portuguese (`Kotoshu::Languages::Portuguese`)
- Portuguese accent handling
- Crase detection (preposition + article combination)
- Brazilian/European Portuguese variants
- Contraction rules

### Russian (`Kotoshu::Languages::Russian`)
- Cyrillic script support
- Character substitution for typo correction
- 6 grammatical cases (nominative, genitive, etc.)
- Transliteration support

### Spanish (`Kotoshu::Languages::Spanish`)
- Spanish accent distinction (él/he, tú/you)
- Inverted punctuation rules (¿?, ¡!)
- Gender agreement (el/la, un/una)
- Verb conjugation patterns
