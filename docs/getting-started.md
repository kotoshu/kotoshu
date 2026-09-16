# Getting Started with Kotoshu

Welcome to Kotoshu, a high-performance spellchecker library for Ruby. This guide will help you get up and running quickly.

## Installation

Add Kotoshu to your Gemfile:

```ruby
gem 'kotoshu'
```

Then run:

```bash
bundle install
```

Or install it manually:

```bash
gem install kotoshu
```

## Quick Start

### Basic Word Checking

```ruby
require 'kotoshu'

# Check if a word is spelled correctly
Kotoshu.correct?("hello")  # => true
Kotoshu.correct?("helo")   # => false

# Check if a word is misspelled
Kotoshu.misspelled?("helo")  # => true
```

### Getting Suggestions

```ruby
# Get spelling suggestions for a misspelled word
suggestions = Kotoshu.suggest("helo")

suggestions.suggestions.each do |s|
  puts "#{s.word} (distance: #{s.distance}, confidence: #{s.confidence})"
end
# Output:
# hello (distance: 1, confidence: 1.0)
# help (distance: 1, confidence: 0.95)
# he'll (distance: 1, confidence: 0.90)
```

### Checking Text

```ruby
# Check a string of text
result = Kotoshu.check("Hello wrold")

result.errors.each do |error|
  puts "Misspelled: #{error.word} at position #{error.position}"
  puts "Suggestions: #{error.suggestions.map(&:word).join(', ')}"
end
# Output:
# Misspelled: wrold at position 6
# Suggestions: world, word, would
```

### Checking Files

```ruby
# Check a single file
result = Kotoshu.check_file("README.md")

puts "Found #{result.errors.size} spelling errors"

# Check multiple files
results = Dir["*.md"].map { |f| Kotoshu.check_file(f) }

results.each do |result|
  puts "#{result.file}: #{result.errors.size} errors"
end
```

## Configuration

### Using Defaults

Kotoshu works out of the box with sensible defaults:

```ruby
# Automatically detects system dictionaries
spellchecker = Kotoshu::Spellchecker.new
```

### Custom Configuration

```ruby
Kotoshu.configure do |config|
  config.dictionary_path = "/path/to/words.txt"
  config.dictionary_type = :plain_text
  config.language = "en"
  config.max_suggestions = 15
  config.case_sensitive = false
  config.verbose = true
end
```

### Builder Pattern (Immutable)

```ruby
config = Kotoshu::Configuration::Builder.build do |b|
  b.dictionary_path = "/usr/share/dict/words"
  b.dictionary_type = :unix_words
  b.max_suggestions = 10
  b.case_sensitive = false
end

# config is frozen - thread-safe
spellchecker = Kotoshu::Spellchecker.new(config: config)
```

## Working with Dictionaries

### Using System Dictionaries

```ruby
# Unix system dictionary
dict = Kotoshu::Dictionary::UnixWords.new("/usr/share/dict/words", language_code: "en")

spellchecker = Kotoshu::Spellchecker.new(dictionary: dict)
```

### Using Plain Text Dictionaries

```ruby
# From array of words
dict = Kotoshu::Dictionary::PlainText.from_words(
  %w[hello world programming ruby],
  language_code: "en"
)

# From file
dict = Kotoshu::Dictionary::PlainText.new("words.txt", language_code: "en")

spellchecker = Kotoshu::Spellchecker.new(dictionary: dict)
```

### Using Hunspell Dictionaries

```ruby
# Hunspell .dic/.aff files
dict = Kotoshu::Dictionary::Hunspell.new(
  "/path/to/dictionary.dic",
  "/path/to/affix.aff",
  language_code: "en-US"
)
```

### Using Custom Dictionaries

```ruby
# Runtime custom dictionary
dict = Kotoshu::Dictionary::Custom.new(language_code: "en")
dict.add_word("Kotoshu")
dict.add_word("GitHub")
dict.add_word("OpenSSL")

spellchecker = Kotoshu::Spellchecker.new(dictionary: dict)
```

## Personal Dictionary

Store user-specific words that persist across sessions:

```ruby
# Add words to personal dictionary
Kotoshu::PersonalDictionary.add_word("companyname")
Kotoshu::PersonalDictionary.add_word("productname")

# Get all personal words
words = Kotoshu::PersonalDictionary.words
# => ["companyname", "productname"]

# Remove a word
Kotoshu::PersonalDictionary.remove_word("productname")

# Check if word exists
Kotoshu::PersonalDictionary.include?("companyname")  # => true
```

Words are stored in `~/.kotoshu/personal.dic` in Hunspell-compatible format.

## Project Configuration

Create a `.kotoshu` file in your project root:

```yaml
# .kotoshu
dictionary_type: plain_text
language: en
max_suggestions: 10
case_sensitive: false

# Words to ignore
ignore_words:
  - API
  - CLI
  - HTTP
  - JSON

# Patterns to ignore (regex)
ignore_patterns:
  - "https?://\\S+"
  - "\\S+@\\S+\\.\\S+"
```

Kotoshu will automatically discover and use this configuration.

## Fluent API

For complex spell checking operations, use the fluent API:

```ruby
result = Kotoshu.fluent
  .ignore_words(/https?:\/\/\S+/)  # Ignore URLs
  .ignore_words(/\S+@\S+\.\S+/)     # Ignore emails
  .max_suggestions(5)
  .on_progress { |p| puts "Progress: #{p}%" }
  .check("Check https://example.com for info")

# Returns DocumentResult with URLs ignored
```

## Advanced Features

### Parallel File Checking

Check multiple files concurrently for better performance:

```ruby
checker = Kotoshu::Spellchecker::ParallelChecker.new(
  spellchecker: spellchecker,
  worker_count: 4  # Number of threads
)

results = checker.check_files_parallel(Dir["**/*.md"])
```

### Performance Monitoring

```ruby
# Enable verbose mode for performance insights
Kotoshu.configure do |config|
  config.verbose = true
end

# Or check cache statistics
cache = Kotoshu::Cache::LookupCache.new
stats = cache.stats
# => { hits: 950, misses: 50, size: 1000, hit_rate: 0.95 }
```

### Custom Suggestion Algorithms

```ruby
# Create a custom suggestion strategy
class MyStrategy < Kotoshu::Suggestions::Strategies::BaseStrategy
  def initialize(name: :my_strategy, **config)
    super
  end

  def generate(context)
    # Return SuggestionSet with your suggestions
    Kotoshu::Suggestions::SuggestionSet.new([
      Kotoshu::Suggestions::Suggestion.new(
        word: "suggestion",
        distance: 1,
        confidence: 0.9,
        source: :my_strategy
      )
    ])
  end
end

# Use it
strategy = MyStrategy.new(dictionary: dict)
suggestions = strategy.generate(Kotoshu::Suggestions::Context.new(
  word: "misspeling",
  dictionary: dict
))
```

## CLI Usage

Kotoshu also provides a command-line interface:

```bash
# Check spelling in a file
kotoshu check README.md

# Check multiple files
kotoshu check **/*.md

# Use custom dictionary
kotoshu check --dictionary=/path/to/words.txt file.txt

# JSON output
kotoshu check --format=json file.txt

# Limit suggestions
kotoshu check --max-suggestions=5 file.txt
```

## Performance Tips

1. **Use SymSpell**: Enable SymSpell for 100x faster suggestions
   ```ruby
   Kotoshu.configure do |config|
     config.suggestion_algorithms = [:symspell, :edit_distance]
   end
   ```

2. **Enable Caching**: Caching is enabled by default
   ```ruby
   # Adjust cache size for your use case
   Kotoshu::Cache::LookupCache.new(max_size: 10_000)
   ```

3. **Use Bloom Filter**: For large dictionaries, Bloom filter provides O(1) rejection
   ```ruby
   bloom = Kotoshu::DataStructures::BloomFilter.new(
     expected_size: 100_000,
     false_positive_rate: 0.01
   )
   ```

4. **Parallel Processing**: For batch operations, use parallel checker
   ```ruby
   checker = Kotoshu::Spellchecker::ParallelChecker.new(
     spellchecker: spellchecker,
     worker_count: 8  # Match your CPU cores
   )
   ```

## Troubleshooting

### Dictionary Not Found

```ruby
# Error: DictionaryNotFoundError
# Solution: Use absolute path or ensure file exists
Kotoshu.configure do |config|
  config.dictionary_path = File.expand_path("../words.txt", __dir__)
end
```

### Slow Performance

```ruby
# Enable SymSpell (100x faster than edit distance)
Kotoshu.configure do |config|
  config.suggestion_algorithms = [:symspell]
end

# Increase cache size
cache = Kotoshu::Cache::LookupCache.new(max_size: 10_000)
```

### Too Many Suggestions

```ruby
# Limit suggestions globally
Kotoshu.configure do |config|
  config.max_suggestions = 5
end

# Or per call
suggestions = Kotoshu.suggest("word", max_suggestions: 3)
```

## Next Steps

- Read [ARCHITECTURE.md](ARCHITECTURE.md) for deep dive into system design
- Read [PERFORMANCE.md](PERFORMANCE.md) for optimization guide
- Read [PLUGINS.md](PLUGINS.md) for creating custom extensions
- Run `examples/` for more code examples

## Support

- GitHub Issues: https://github.com/riboseinc/kotoshu/issues
- Documentation: https://www.rubydoc.info/gems/kotoshu
