# Plugin Development Guide

This guide explains how to extend Kotoshu with custom dictionaries, suggestion algorithms, and plugins.

## Overview

Kotoshu is designed for extensibility. You can extend it by:

1. **Custom Dictionaries**: Support new dictionary formats
2. **Custom Suggestion Algorithms**: Implement new suggestion strategies
3. **Plugins**: Add functionality with dependency injection

## Custom Dictionaries

### Dictionary Interface

All dictionaries must implement the `Dictionary::Base` interface:

```ruby
module Kotoshu
  module Dictionary
    class Base
      # Required methods
      def lookup(word)
        raise NotImplementedError
      end

      # Optional methods
      def suggest(word, max_suggestions: 10)
        []
      end

      def add_word(word, flags: [])
        false
      end

      def remove_word(word)
        false
      end

      def words
        @words ||= []
      end
    end
  end
end
```

### Creating a Custom Dictionary

#### Example: JSON Word List

```ruby
require 'json'

module Kotoshu
  module Dictionary
    class Json < Base
      # Register this dictionary type
      register_type :json, self

      def initialize(path, language_code:, locale: nil, case_sensitive: false)
        @path = path
        @language_code = language_code.dup.freeze
        @locale = locale&.dup&.freeze
        @case_sensitive = case_sensitive
        @word_pattern = nil

        load_dictionary!
        register_type(:json) unless Dictionary.registry.key?(:json)
      end

      private

      def load_dictionary!
        data = JSON.parse(File.read(@path))
        @words = data["words"].map do |w|
          @case_sensitive ? w : w.downcase
        end

        @word_set = @words.each_with_index.to_h
        @metadata = { format: "json", version: data["version"] }.freeze
      end
    end
  end
end
```

#### Usage

```ruby
# Create JSON dictionary file
# words.json
# {
#   "words": ["hello", "world", "custom"],
#   "version": "1.0"
# }

# Use it
dict = Kotoshu::Dictionary::Json.new("words.json", language_code: "en")
spellchecker = Kotoshu::Spellchecker.new(dictionary: dict)
```

### Example: Remote API Dictionary

```ruby
require 'net/http'

module Kotoshu
  module Dictionary
    class Remote < Base
      register_type :remote, self

      def initialize(url, language_code:, api_key: nil, cache_ttl: 3600)
        @url = url
        @language_code = language_code
        @api_key = api_key
        @cache_ttl = cache_ttl
        @cache = {}
        @cache_timestamps = {}
      end

      def lookup(word)
        # Check cache first
        if cache_valid?(word)
          return @cache[word]
        end

        # Make API request
        result = api_lookup(word)

        # Cache result
        @cache[word] = result
        @cache_timestamps[word] = Time.now.to_i

        result
      end

      private

      def api_lookup(word)
        uri = URI("#{@url}?word=#{URI.encode_www_form_component(word)}")
        req = Net::HTTP::Get.new(uri)

        if @api_key
          req['Authorization'] = "Bearer #{@api_key}"
        end

        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
          http.request(req)
        end

        JSON.parse(response.body)["found"] || false
      end

      def cache_valid?(word)
        return false unless @cache.key?(word)

        age = Time.now.to_i - @cache_timestamps[word]
        age < @cache_ttl
      end
    end
  end
end
```

### Example: Database Dictionary

```ruby
require 'sequel'

module Kotoshu
  module Dictionary
    class Database < Base
      register_type :database, self

      def initialize(db_config, table:, word_column:, language_code:)
        @db = Sequel.connect(db_config)
        @table = table
        @word_column = word_column
        @language_code = language_code

        # Prepare dataset for efficient queries
        @dataset = @db[@table].select(@word_column)
      end

      def lookup(word)
        !@dataset.where(@word_column => word.downcase).empty?
      end

      def words
        @dataset.map(@word_column)
      end
    end
  end
end
```

## Custom Suggestion Algorithms

### Strategy Interface

All suggestion strategies must implement `Suggestions::Strategies::BaseStrategy`:

```ruby
module Kotoshu
  module Suggestions
    module Strategies
      class BaseStrategy
        def initialize(name:, **config)
          @name = name
          @config = config
          @enabled = config.fetch(:enabled, true)
          @max_results = config.fetch(:max_results, 10)
        end

        def generate(context)
          raise NotImplementedError
        end
      end
    end
  end
end
```

### Creating a Custom Strategy

#### Example: Frequency-Based Suggestions

```ruby
module Kotoshu
  module Suggestions
    module Strategies
      class FrequencyStrategy < BaseStrategy
        register_algorithm :frequency, self

        def initialize(name: :frequency, dictionary:, **config)
          super(name: name, **config)
          @dictionary = dictionary
          @word_frequencies = load_frequencies
        end

        def generate(context)
          word = context.word
          max_dist = get_config(:max_distance, 2)

          candidates = find_candidates(word, max_dist)

          # Sort by frequency
          sorted = candidates.sort_by { |w| @word_frequencies[w] }.reverse

          # Create SuggestionSet
          suggestions = sorted.first(@max_results).map do |candidate|
            Suggestion.new(
              word: candidate,
              distance: edit_distance(word, candidate),
              confidence: calculate_confidence(candidate),
              source: @name
            )
          end

          SuggestionSet.new(suggestions, max_size: @max_results)
        end

        private

        def load_frequencies
          # Load word frequencies from dictionary or external source
          # This example uses a simple hash
          {
            "the" => 10000,
            "and" => 8000,
            "hello" => 100,
            # ...
          }
        end

        def find_candidates(word, max_dist)
          # Find words within edit distance
          @dictionary.words.select do |dict_word|
            edit_distance(word, dict_word) <= max_dist
          end
        end

        def edit_distance(a, b)
          # Standard Levenshtein distance
          # ...
        end

        def calculate_confidence(word)
          freq = @word_frequencies[word] || 0
          # Normalize confidence
          [freq / 10_000.0, 1.0].min
        end
      end
    end
  end
end
```

#### Usage

```ruby
# Use frequency-based strategy
strategy = Kotoshu::Suggestions::Strategies::FrequencyStrategy.new(
  dictionary: dict,
  max_distance: 2,
  max_results: 10
)

# Generate suggestions
context = Kotoshu::Suggestions::Context.new(
  word: "helo",
  dictionary: dict,
  max_results: 10
)

suggestions = strategy.generate(context)
```

#### Example: Context-Aware Suggestions

```ruby
module Kotoshu
  module Suggestions
    module Strategies
      class ContextAwareStrategy < BaseStrategy
        register_algorithm :context_aware, self

        def generate(context)
          word = context.word
          surrounding_words = context.option(:surrounding_words, [])

          # Get base suggestions
          base_suggestions = get_base_suggestions(word)

          # Re-rank based on context
          reranked = rerank_by_context(base_suggestions, surrounding_words)

          SuggestionSet.new(reranked, max_size: @max_results)
        end

        private

        def get_base_suggestions(word)
          # Use edit distance or other algorithm
          # ...
        end

        def rerank_by_context(suggestions, surrounding_words)
          # Re-rank suggestions based on surrounding words
          # For example, if surrounding word is "compile", prefer "code" over "mode"
          suggestions.map do |suggestion|
            confidence = calculate_context_confidence(suggestion.word, surrounding_words)
            Suggestion.new(
              word: suggestion.word,
              distance: suggestion.distance,
              confidence: confidence,
              source: :context_aware
            )
          end.sort_by(&:confidence).reverse
        end

        def calculate_context_confidence(word, surrounding_words)
          # Calculate confidence based on collocation with surrounding words
          # This could use bigram/trigram frequencies
          0.9  # Placeholder
        end
      end
    end
  end
end
```

### Composite Strategies

Combine multiple strategies:

```ruby
# Create composite strategy
composite = Kotoshu::Suggestions::Strategies::CompositeStrategy.new(
  name: :combined,
  strategies: [
    Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(dictionary: dict),
    Kotoshu::Suggestions::Strategies::FrequencyStrategy.new(dictionary: dict),
    Kotoshu::Suggestions::Strategies::ContextAwareStrategy.new(dictionary: dict)
  ]
)

# Use it
suggestions = composite.generate(context)
```

## Plugins

### Plugin Interface

Plugins use dependency injection:

```ruby
module Kotoshu
  module Plugins
    class Plugin
      def self.plugin_name
        raise NotImplementedError
      end

      def self.dependencies
        []
      end

      def self.provides
        []
      end

      def before_start
        # Override in subclass
      end

      def after_stop
        # Override in subclass
      end
    end
  end
end
```

### Creating a Plugin

#### Example: Metrics Plugin

```ruby
module Kotoshu
  module Plugins
    class MetricsPlugin < Plugin
      plugin_name :metrics
      dependencies [:spellchecker]
      provides [:metrics_collection]

      attr_reader :spellchecker, :metrics

      def initialize(spellchecker:)
        @spellchecker = spellchecker
        @metrics = {
          lookups: 0,
          suggestions: 0,
          cache_hits: 0,
          cache_misses: 0
        }
      end

      def before_start
        # Wrap spellchecker methods to track metrics
        wrap_spellchecker
      end

      def after_stop
        # Print metrics report
        print_report
      end

      def get_metrics
        @metrics.dup
      end

      def reset_metrics
        @metrics = @metrics.transform_values { 0 }
      end

      private

      def wrap_spellchecker
        @spellchecker.define_singleton_method(:correct_with_metrics) do |word|
          @metrics[:lookups] += 1
          correct_without_metrics(word)
        end
      end

      def print_report
        puts "=== Metrics Report ==="
        puts "Lookups: #{@metrics[:lookups]}"
        puts "Suggestions: #{@metrics[:suggestions]}"
        puts "Cache hits: #{@metrics[:cache_hits]}"
        puts "Cache misses: #{@metrics[:cache_misses]}"
        hit_rate = @metrics[:lookups] > 0 ?
          @metrics[:cache_hits].to_f / @metrics[:lookups] : 0
        puts "Hit rate: #{(hit_rate * 100).round(2)}%"
      end
    end
  end
end
```

#### Example: Logging Plugin

```ruby
module Kotoshu
  module Plugins
    class LoggingPlugin < Plugin
      plugin_name :logging
      dependencies [:spellchecker]
      provides [:logging]

      LOGGER = Logger.new(STDOUT)

      def initialize(spellchecker:, log_level: :info)
        @spellchecker = spellchecker
        @log_level = log_level
      end

      def before_start
        wrap_spellchecker
        LOGGER.info("Logging plugin started")
      end

      def after_stop
        LOGGER.info("Logging plugin stopped")
      end

      private

      def wrap_spellchecker
        @spellchecker.define_singleton_method(:correct_with_logging) do |word|
          LOGGER.debug("Checking word: #{word}")
          result = correct_without_logging(word)
          LOGGER.debug("Result: #{result}")
          result
        end
      end
    end
  end
end
```

### Plugin Registry

Register and manage plugins:

```ruby
# Create registry
registry = Kotoshu::Plugins::Registry.new

# Register plugins
registry.register(:metrics, Kotoshu::Plugins::MetricsPlugin)
registry.register(:logging, Kotoshu::Plugins::LoggingPlugin)

# Create spellchecker
spellchecker = Kotoshu::Spellchecker.new(dictionary: dict)

# Start plugins
registry.start_all(spellchecker: spellchecker)

# Use plugins
metrics = registry.get_service(:metrics)
puts metrics.get_metrics

# Stop plugins
registry.stop_all
```

## Testing Extensions

### Testing Custom Dictionaries

```ruby
RSpec.describe MyDictionary do
  let(:dictionary) { described_class.new("test.json", language_code: "en") }

  describe "#lookup" do
    it "returns true for existing words" do
      expect(dictionary.lookup("hello")).to be true
    end

    it "returns false for non-existing words" do
      expect(dictionary.lookup("xyzxyz")).to be false
    end
  end

  describe "#words" do
    it "returns all words in dictionary" do
      expect(dictionary.words).to include("hello", "world")
    end
  end
end
```

### Testing Custom Strategies

```ruby
RSpec.describe MyStrategy do
  let(:dictionary) { Kotoshu::Dictionary::PlainText.from_words(%w[hello world], language_code: "en") }
  let(:strategy) { described_class.new(dictionary: dictionary) }

  describe "#generate" do
    it "returns suggestions for misspelled words" do
      context = Kotoshu::Suggestions::Context.new(
        word: "helo",
        dictionary: dictionary,
        max_results: 10
      )

      suggestions = strategy.generate(context)

      expect(suggestions.suggestions).not_to be_empty
      expect(suggestions.suggestions.first.word).to eq("hello")
    end
  end
end
```

### Testing Plugins

```ruby
RSpec.describe MyPlugin do
  let(:spellchecker) { Kotoshu::Spellchecker.new(dictionary: dict) }
  let(:plugin) { described_class.new(spellchecker: spellchecker) }

  describe "#before_start" do
    it "initializes plugin correctly" do
      plugin.before_start
      expect(plugin).to be_ready
    end
  end

  describe "#after_stop" do
    it "cleans up resources" do
      plugin.before_start
      plugin.after_stop
      expect(plugin.resources).to be_empty
    end
  end
end
```

## Best Practices

### 1. Error Handling

Always handle errors gracefully:

```ruby
def lookup(word)
  return false if word.nil? || word.empty?

  # Your implementation
rescue StandardError => e
  # Log error and return safe default
  warn "Error in #{self.class}#lookup: #{e.message}"
  false
end
```

### 2. Thread Safety

Ensure thread-safety for concurrent access:

```ruby
def initialize
  @cache = {}
  @mutex = Mutex.new
end

def lookup(word)
  @mutex.synchronize do
    @cache[word] ||= compute_lookup(word)
  end
end
```

### 3. Performance

Cache expensive operations:

```ruby
def initialize
  @cache = {}
  @cache_ttl = 3600
end

def expensive_operation(word)
  cached = @cache[word]

  if cached && !expired?(cached)
    return cached[:result]
  end

  result = compute_result(word)
  @cache[word] = { result: result, timestamp: Time.now }
  result
end
```

### 4. Documentation

Document your extension:

```ruby
# My custom dictionary for JSON word lists.
#
# @example Create dictionary
#   dict = Kotoshu::Dictionary::Json.new("words.json", language_code: "en")
#
# @example Check word
#   dict.lookup("hello")  # => true
class Json < Kotoshu::Dictionary::Base
  # ...
end
```

## Publishing Extensions

### Gem Structure

```
my-kotoshu-extension/
├── lib/
│   └── kotoshu/
│       └── extensions/
│           └── my_extension.rb
├── spec/
│   └── kotoshu/
│       └── extensions/
│           └── my_extension_spec.rb
├── Gemfile
├── my-kotoshu-extension.gemspec
└── README.md
```

### Gemspec

```ruby
Gem::Specification.new do |spec|
  spec.name = "my-kotoshu-extension"
  spec.version = "0.1.0"
  spec.authors = ["Your Name"]

  spec.files = Dir["lib/**/*", "README.md"]
  spec.require_paths = ["lib"]

  spec.add_dependency "kotoshu", "~> 1.0"

  spec.add_development_dependency "rspec", "~> 3.0"
end
```

## Further Reading

- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
- [GETTING_STARTED.md](GETTING_STARTED.md) - Quick start guide
- [PERFORMANCE.md](PERFORMANCE.md) - Performance optimization
