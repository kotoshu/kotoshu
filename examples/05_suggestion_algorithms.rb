#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 5: Suggestion Algorithms
#
# This example demonstrates how to use different suggestion algorithms
# and build custom suggestion pipelines.

require_relative "../lib/kotoshu"

puts "=== Example 5: Suggestion Algorithms ==="
puts

# Create a test dictionary
test_words = %w[
  hello help held heap world
  test text toast tost
  run running runner
  code coding coded
  write writing writer
  speak speaking speaker
  read reading reader
  walk walking walker
  talk talking talker
]

test_dict = Kotoshu::Dictionary::Custom.new(
  words: test_words,
  language_code: "en"
)

puts "Test dictionary: #{test_dict.size} words"
puts

# Example 1: Edit Distance Strategy
puts "1. Edit Distance Strategy"
puts "-" * 40

edit_strategy = Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new
context = Kotoshu::Suggestions::Context.new(
  word: "helo",
  dictionary: test_dict,
  max_results: 5
)

result = edit_strategy.generate(context)
puts "Suggestions for 'helo':"
puts "  #{result.to_words.join(", ")}"
puts "  Details:"
result.each do |sugg|
  puts "    • #{sugg.word} (distance: #{sugg.distance}, confidence: #{sugg.confidence.round(2)})"
end

puts
puts "=" * 40
puts

# Example 2: Phonetic Strategy (Soundex)
puts "2. Phonetic Strategy (Soundex)"
puts "-" * 40

phonetic_strategy = Kotoshu::Suggestions::Strategies::PhoneticStrategy.new(
  algorithm: :soundex
)

context2 = Kotoshu::Suggestions::Context.new(
  word: "hel",
  dictionary: test_dict,
  max_results: 5
)

result2 = phonetic_strategy.generate(context2)
puts "Suggestions for 'hel' (Soundex):"
puts "  #{result2.to_words.join(", ")}"

# Show Soundex codes
puts "\nSoundex codes:"
puts "  'hel' -> #{phonetic_strategy.send(:soundex_code, "hel")}"
test_words.each do |word|
  code = phonetic_strategy.send(:soundex_code, word)
  puts "  '#{word}' -> #{code}"
end

puts
puts "=" * 40
puts

# Example 3: Phonetic Strategy (Metaphone)
puts "3. Phonetic Strategy (Metaphone)"
puts "-" * 40

metaphone_strategy = Kotoshu::Suggestions::Strategies::PhoneticStrategy.new(
  algorithm: :metaphone
)

context3 = Kotoshu::Suggestions::Context.new(
  word: "fnix",  # Should suggest "Phoenix"
  dictionary: test_dict,
  max_results: 5
)

# Add "phoenix" to dictionary for testing
test_dict.add_word("phoenix")

result3 = metaphone_strategy.generate(context3)
puts "Suggestions for 'fnix' (Metaphone):"
puts "  #{result3.to_words.join(", ")}"

puts "\nMetaphone codes:"
puts "  'fnix' -> #{metaphone_strategy.send(:metaphone_code, "fnix")}"
puts "  'phoenix' -> #{metaphone_strategy.send(:metaphone_code, "phoenix")}"
puts "  'finish' -> #{metaphone_strategy.send(:metaphone_code, "finish")}"

puts
puts "=" * 40
puts

# Example 4: N-Gram Strategy
puts "4. N-Gram Strategy"
puts "-" * 40

ngram_strategy = Kotoshu::Suggestions::Strategies::NgramStrategy.new(
  n: 2,
  min_similarity: 0.2
)

context4 = Kotoshu::Suggestions::Context.new(
  word: "tsting",  # Should suggest "testing"
  dictionary: test_dict,
  max_results: 5
)

# Add "testing" to dictionary
test_dict.add_word("testing")

result4 = ngram_strategy.generate(context4)
puts "Suggestions for 'tsting' (N-Gram, n=2):"
puts "  #{result4.to_words.join(", ")}"

puts
puts "=" * 40
puts

# Example 5: Composite Strategy (Pipeline)
puts "5. Composite Strategy (Pipeline)"
puts "-" * 40

# Build a pipeline with multiple strategies
pipeline = Kotoshu.suggestion_pipeline(
  Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new,
  Kotoshu::Suggestions::Strategies::PhoneticStrategy.new,
  Kotoshu::Suggestions::Strategies::NgramStrategy.new(n: 2)
)

context5 = Kotoshu::Suggestions::Context.new(
  word: "wrld",
  dictionary: test_dict,
  max_results: 10
)

result5 = pipeline.generate(context5)
puts "Suggestions for 'wrld' (Composite Pipeline):"
puts "  #{result5.to_words.join(", ")}"

puts
puts "Breakdown by source:"
result5.from_source(:edit_distance).each do |sugg|
  puts "  EditDistance: #{sugg.word} (distance: #{sugg.distance})"
end
result5.from_source(:phonetic).each do |sugg|
  puts "  Phonetic: #{sugg.word}"
end
result5.from_source(:ngram).each do |sugg|
  puts "  N-Gram: #{sugg.word}"
end

puts
puts "=" * 40
puts

# Example 6: Custom Strategy
puts "6. Custom Strategy"
puts "-" * 40

class PrefixStrategy < Kotoshu::Suggestions::Strategies::BaseStrategy
  def generate(context)
    word = context.word
    dict_words = dictionary_words(context)

    # Find words with same prefix
    prefix_len = [word.length - 1, 3].max
    prefix = word[0...prefix_len]

    candidates = dict_words.select { |w| w.start_with?(prefix) && w != word }
    create_suggestion_set(candidates)
  end
end

prefix_strategy = PrefixStrategy.new(name: :prefix)

context6 = Kotoshu::Suggestions::Context.new(
  word: "hel",  # Incomplete word
  dictionary: test_dict,
  max_results: 10
)

result6 = prefix_strategy.generate(context6)
puts "Suggestions for 'hel' (Prefix-based):"
puts "  #{result6.to_words.join(", ")}"

puts
puts "=" * 40
puts

# Example 7: Suggestion Generator
puts "7. Suggestion Generator (High-level API)"
puts "-" * 40

generator = Kotoshu::Suggestions::Generator.new(
  test_dict,
  max_suggestions: 10,
  algorithms: [
    Kotoshu::Suggestions::Strategies::EditDistanceStrategy,
    Kotoshu::Suggestions::Strategies::PhoneticStrategy
  ]
)

puts "Generator configured with:"
puts "  Dictionary: #{test_dict.size} words"
puts "  Max suggestions: 10"
puts "  Algorithms: EditDistanceStrategy, PhoneticStrategy"
puts

test_words = %w[helo wrld tsting fnix]
test_words.each do |word|
  suggestions = generator.suggest(word)
  puts "Suggestions for '#{word}':"
  puts "  #{suggestions.to_words.join(", ")}"
end
