# frozen_string_literal: true

require "bundler/setup"
require_relative "lib/kotoshu"

# Test IndexedDictionary
puts "=== Testing IndexedDictionary ==="
dict = Kotoshu::Core::IndexedDictionary.new(%w[hello world help held heap])
puts "Has 'hello': #{dict.has_word?('hello')}"
puts "Has 'HELLO' (ignorecase): #{dict.has_word_ignorecase?('HELLO')}"
puts "Words starting with 'he': #{dict.find_by_prefix('he').inspect}"
puts "Words ending with 'ld': #{dict.find_by_suffix('ld').inspect}"
puts "Words with length 5: #{dict.find_by_length(5).inspect}"
puts "Statistics: #{dict.statistics.inspect}"
puts

# Test Trie
puts "=== Testing Trie ==="
trie = Kotoshu::Core::Trie::Builder.from_array(%w[hello help held heap world])
puts "Has 'hello': #{trie.lookup('hello')}"
puts "Has prefix 'he': #{trie.has_prefix?('he')}"
puts "Words with prefix 'he': #{trie.words_with_prefix('he').inspect}"
puts "Suggestions for 'hel': #{trie.suggestions('hel').inspect}"
puts "All words: #{trie.all_words.inspect}"
puts

# Test Suggestion
puts "=== Testing Suggestion ==="
suggestion = Kotoshu::Suggestions::Suggestion.new(
  word: "hello",
  distance: 1,
  confidence: 0.9,
  source: :test
)
puts "High confidence: #{suggestion.high_confidence?}"
puts "Combined score: #{suggestion.combined_score}"
puts "Same word as 'HELLO': #{suggestion.same_word?('HELLO')}"
puts

# Test SuggestionSet
puts "=== Testing SuggestionSet ==="
suggestions = Kotoshu::Suggestions::SuggestionSet.from_words(
  %w[hello help held],
  source: :test
)
puts "Size: #{suggestions.size}"
puts "First: #{suggestions.first.inspect}"
puts "Has word 'help': #{suggestions.has_word?('help')}"
puts "Top 2: #{suggestions.top(2).map(&:word).inspect}"
puts

# Test Context
puts "=== Testing Context ==="
context = Kotoshu::Suggestions::Context.new(
  word: "helo",
  dictionary: dict,
  max_results: 5
)
puts "Word: #{context.word}"
puts "Max results: #{context.max_results}"
puts

# Test EditDistanceStrategy
puts "=== Testing EditDistanceStrategy ==="
strategy = Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new
result = strategy.generate(context)
puts "Suggestions for 'helo': #{result.to_words.inspect}"
puts

# Test CompositeStrategy (Pipeline)
puts "=== Testing CompositeStrategy ==="
pipeline = Kotoshu.suggestion_pipeline(
  Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new
)
result = pipeline.generate(context)
puts "Pipeline suggestions: #{result.to_words.inspect}"
puts

puts "All tests passed!"
