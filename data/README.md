# Kelly Frequency Lists for Kotoshu

This directory contains frequency lists derived from the Kelly Project (University of Leeds & University of Gothenburg) for use with the Kotoshu spell checker.

## Files

| Language | File | Word Count | CEFR Levels |
|----------|------|------------|-------------|
| English  | `en.json` | 7,549 | A1, A2, B1, B2, C1, C2 |
| Russian  | `ru.json` | 8,958 | A1, A2, B1, B2, C1, C2 |

## Data Format

Each JSON file contains:

```json
{
  "metadata": {
    "language": "Language code (ISO 639-1)",
    "language_name": "Full language name",
    "source": "Kelly Project - University of Leeds & University of Gothenburg",
    "source_url": "https://spraakbanken.gu.se/eng/kelly",
    "citation": "Full citation information",
    "doi": "https://doi.org/10.1015/lre-2014-0012",
    "total_words": "Total word count",
    "cefr_levels": ["A1", "A2", "B1", "B2", "C1", "C2"],
    "license": "Research use - see Kelly project terms",
    "processed_date": "ISO 8601 timestamp",
    "kotoshu_version": "1.0.0",
    "note": "Generated from Kelly Project frequency lists. See ATTRIBUTION.md for details."
  },
  "tiers": {
    "top_50": {
      "words": ["word1", "word2", ...],
      "description": "Top 50 most frequent words",
      "bonus_score": 200
    },
    "top_200": {
      "words": ["word1", "word2", ...],
      "description": "Top 200 most frequent words",
      "bonus_score": 100
    },
    "top_1000": {
      "words": ["word1", "word2", ...],
      "description": "Top 1000 most frequent words",
      "bonus_score": 50
    },
    "a1": {
      "words": ["word1", "word2", ...],
      "description": "CEFR A1 level words",
      "bonus_score": 150
    },
    "a2": { "words": [...], "description": "CEFR A2 level words", "bonus_score": 120 },
    "b1": { "words": [...], "description": "CEFR B1 level words", "bonus_score": 90 },
    "b2": { "words": [...], "description": "CEFR B2 level words", "bonus_score": 60 },
    "c1": { "words": [...], "description": "CEFR C1 level words", "bonus_score": 30 },
    "c2": { "words": [...], "description": "CEFR C2 level words", "bonus_score": 20 }
  },
  "full_list": [
    {
      "word": "example",
      "ipm": 1000.0,
      "cefr": "A1",
      "rank": 1,
      "pos": "noun"
    },
    ...
  }
}
```

## Usage with Kotoshu

The frequency data is used by Kotoshu's `EditDistanceStrategy` to improve suggestion quality by prioritizing common words:

```ruby
# Load frequency data
strategy = Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new(
  language_code: 'en',
  frequency_data_path: 'data/en.json'
)

# Generate suggestions with frequency-based scoring
suggestions = strategy.generate("helo")
# Common words like "hello" will receive bonus points
```

## CEFR Level Mapping

The CEFR (Common European Framework of Reference for Languages) levels are used for both proficiency classification and bonus scoring:

| Level | Description | Bonus Score |
|-------|-------------|-------------|
| A1    | Beginner    | 150         |
| A2    | Elementary  | 120         |
| B1    | Intermediate| 90          |
| B2    | Upper Intermediate | 60   |
| C1    | Advanced    | 30          |
| C2    | Proficiency | 20          |

## Processing

The JSON files are generated from the original Kelly Excel files using the `scripts/parse_kelly.rb` script.

### Requirements
- Ruby 3.1+
- `roo` gem (2.10.1+)
- `roo-xls` gem (for XLS support)

### Usage
```bash
ruby scripts/parse_kelly.rb
```

## Attribution

Please see [ATTRIBUTION.md](ATTRIBUTION.md) for full citation and license information for the Kelly Project data.

## Limitations

- **Language Coverage**: The Kelly Project only provides frequency lists for a subset of languages. Kotoshu supports de, en, es, fr, pt, ru, but Kelly only provides en and ru.
- **German, Spanish, French, Portuguese**: These languages require alternative frequency sources, which are not yet included in this repository.

## Future Work

- [ ] Add Italian (it) frequency list from Kelly
- [ ] Add Arabic (ar) frequency list from Kelly
- [ ] Add Chinese (zh) frequency list from Kelly
- [ ] Source and integrate frequency data for German, Spanish, French, Portuguese
- [ ] Add CEFR-based frequency tiers for non-Kelly languages

## References

- Kilgarriff, A., et al. (2014). Corpus-based vocabulary lists for language learners for nine languages. *Language Resources and Evaluation*, 48(2), 121-163. DOI: https://doi.org/10.1015/lre-2014-0012
- Kelly Project: https://spraakbanken.gu.se/eng/kelly
