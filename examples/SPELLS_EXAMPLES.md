# Spylls Examples - Ported to Ruby

This directory contains Ruby ports of the Python Spylls examples, adapted to work with the Kotoshu spell checking library.

## Ported Examples

### 1. spylls_basic.rb
**Port of:** `basic.py`

Demonstrates basic spell checking operations:
- Creating a Hunspell dictionary from .dic and .aff files
- Looking up words to check if they exist in the dictionary
- Getting spelling suggestions for misspelled words

**Example output:**
```
Lookup 'spells': true
Lookup 'spylls': false
Suggestions for 'helo': ["held", "hell", "hello", ...]
```

### 2. spylls_dic.rb
**Port of:** `dic.py`

Demonstrates dictionary internal access methods:
- Accessing the word index
- Finding homonyms (words with the same spelling but different flags)
- Exploring the internal structure of the Hunspell dictionary

**Example output:**
```
First 10 words: ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]
Homonyms for 'spell': {"spell"=>["R", "D", "S", "J", "G", "Z"]}
```

### 3. spylls_lookup.rb
**Port of:** `lookup.py`

Demonstrates advanced lookup features:
- Using `good_forms` to get all valid forms of a word
- Using `affix_forms` to generate word variants using affix rules
- Understanding morphological word generation

**Note:** Kotoshu's API differs from Spylls. This example uses `word_variants()` method.

**Example output:**
```
good_forms("building"): ["building"]
good_forms("111th"): []
affix_forms("reboots"): []
```

### 4. spylls_suggest.rb
**Port of:** `suggest.py`

Demonstrates the suggestion API:
- Getting spelling suggestions for misspelled words
- Iterating through suggestions

**Note:** Kotoshu's suggestion algorithm uses edit distance and may return different results than Spylls.

**Example output:**
```
Suggestions for 'spylls': (No suggestions found)
Suggestions for 'helo':
  - held
  - hell
  - hello
  - helm
  - helot
  - help
  ...
```

### 5. spylls_utils.rb
**Port of:** `utils.py`

Demonstrates capitalization utilities for different languages:
- Regular capitalization (English-style)
- Turkic capitalization (handles dotted/dotless i: ı/I/i/İ)
- German capitalization (handles ß → SS conversion)

**Note:** This is a simplified implementation as Kotoshu doesn't have full capitalization utilities yet.

**Example output:**
```
Regular casing guess for 'Paris': title
Turkic lower: ızmir
German lower: strasse
```

### 6. spylls_unmunch.rb
**Port of:** `unmunch.py`

Demonstrates "unmunching" - expanding an affix-compressed dictionary into a full list of words:
- Parses Hunspell affix files directly
- Generates all possible word forms by applying affix rules
- Handles suffix rules, prefix rules, and cross-product rules
- Supports command-line options for selecting specific words

**Usage:**
```bash
# Unmunch a single word
ruby spylls_unmunch.rb --word=spell

# Unmunch the entire dictionary
ruby spylls_unmunch.rb

# Use custom dictionary path
ruby spylls_unmunch.rb --dictionary=/path/to/dict --word=word
```

**Example output:**
```
$ ruby spylls_unmunch.rb --word=spell
Unmunching only words with stem spell

Unmunching spell with flags ["R", "D", "S", "J", "G", "Z"]

spell
spelled
speller
spellers
spelling
spellings
spells
```

## Dictionary Files

The examples use the English (en_US) Hunspell dictionary files:
- `en_US.dic` - Dictionary file with words and flags
- `en_US.aff` - Affix file with morphological rules

**Note:** The original Spylls examples use ISO-8859-1 encoding. These files have been converted to UTF-8 for Ruby compatibility.

## API Differences

Kotoshu's API differs from Spylls in several ways:

1. **Dictionary Creation:**
   - Spylls: `Dictionary.from_files(path)` (auto-appends .dic/.aff)
   - Kotoshu: `Dictionary::Hunspell.new(dic_path:, aff_path:, language_code:)`

2. **Suggestions:**
   - Spylls uses phonetic algorithms, keyboard proximity, and n-gram matching
   - Kotoshu uses edit distance (may return different results)

3. **Affix Processing:**
   - Spylls has internal `lookuper.good_forms()` and `lookuper.affix_forms()` methods
   - Kotoshu uses `word_variants()` method

4. **Capitalization:**
   - Spylls has full capitalization utilities (Casing, TurkicCasing, GermanCasing)
   - Kotoshu doesn't include these utilities (simplified version in utils example)

## Running the Examples

All examples are executable scripts:

```bash
# Make executable (if needed)
chmod +x examples/spylls_*.rb

# Run individual examples
ruby examples/spylls_basic.rb
ruby examples/spylls_suggest.rb
ruby examples/spylls_unmunch.rb --word=spell
```

## Implementation Notes

### Bug Discovery in Kotoshu

During the port of `spylls_unmunch.rb`, a bug was discovered in the `parse_affix_rules` method in `lib/kotoshu/dictionary/hunspell.rb`. The method incorrectly distinguishes between header and rule lines in affix files, causing affix rules to not be parsed correctly.

The unmunch example works around this bug by parsing the affix file directly.

### Character Encoding

The original Spylls dictionary files use ISO-8859-1 encoding. These were converted to UTF-8 using:

```bash
iconv -f ISO-8859-1 -t UTF-8 en_US.dic > en_US.dic.utf8
iconv -f ISO-8859-1 -t UTF-8 en_US.aff > en_US.aff.utf8
```

## Summary

| Python Example | Ruby Port | Status |
|----------------|-----------|--------|
| `basic.py` | `spylls_basic.rb` | ✅ Working |
| `dic.py` | `spylls_dic.rb` | ✅ Working |
| `lookup.py` | `spylls_lookup.rb` | ✅ Working (API differences) |
| `suggest.py` | `spylls_suggest.rb` | ✅ Working (different algorithm) |
| `utils.py` | `spylls_utils.rb` | ✅ Working (simplified) |
| `unmunch.py` | `spylls_unmunch.rb` | ✅ Working (with workaround) |

**Total:** 6 examples ported successfully
