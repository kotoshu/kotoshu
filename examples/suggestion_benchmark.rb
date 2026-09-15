#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "kotoshu"
require "kotoshu/language"
require "benchmark"

puts "=" * 80
puts "Kotoshu Suggestion Algorithm Benchmark & Comparison"
puts "Comparing speed and accuracy of different suggestion algorithms"
puts "=" * 80
puts

# Test words from the test file (all spelling errors)
test_words = %w[
  Teachigns ancent influentail milennia Dispite relevent
  perserverance experiance importence beleived enviroment
  wich evry harmonius intenttion obediance accesible remarkebly
  fullfills benevolance intrest wrold
]

# Expected corrections for accuracy testing
expected_corrections = {
  "Teachigns" => "Teachings",
  "ancent" => "ancient",
  "influentail" => "influential",
  "milennia" => "millennia",
  "Dispite" => "Despite",
  "relevent" => "relevant",
  "perserverance" => "perseverance",
  "experiance" => "experience",
  "importence" => "importance",
  "beleived" => "believed",
  "enviroment" => "environment",
  "wich" => "which",
  "evry" => "every",
  "harmonius" => "harmonious",
  "intention" => "intention",
  "obediance" => "obedience",
  "accesible" => "accessible",
  "remarkebly" => "remarkably",
  "fullfills" => "fulfills",
  "benevolance" => "benevolence",
  "intrest" => "interest",
  "wrold" => "world"
}

# Load dictionary once for reuse
puts "Loading dictionary..."
dict = Kotoshu::Dictionary::UnixWords.new("/usr/share/dict/words", language_code: "en")
puts "Dictionary loaded: #{dict.words.count} words"
puts

# ============================================================================
# Algorithm 1: EditDistanceStrategy (baseline - slow)
# ============================================================================
puts "1. EditDistanceStrategy (Baseline - O(N*M) where N=dictionary size)"
puts "-" * 80

require "kotoshu/suggestions/strategies/edit_distance_strategy"

edit_strategy = Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new

edit_times = {}
edit_results = {}

test_words.first(3).each do |word|
  context = Kotoshu::Suggestions::Context.new(
    word: word,
    dictionary: dict,
    max_results: 10
  )

  time = Benchmark.measure do
    result = edit_strategy.generate(context)
    edit_results[word] = result.to_words
  end

  edit_times[word] = time.real
  puts "  #{word}: #{edit_results[word].first(3).join(', ')} (#{time.real.round(2)}s)"
end

puts ""
puts "Full EditDistanceStrategy test..."
time = Benchmark.measure do
  test_words.each do |word|
    context = Kotoshu::Suggestions::Context.new(word: word, dictionary: dict, max_results: 10)
    edit_strategy.generate(context)
  end
end
puts "  Total time for #{test_words.count} words: #{time.real.round(2)}s"
puts "  Average per word: #{(time.real / test_words.count).round(3)}s"
puts

# ============================================================================
# Algorithm 2: SymSpellStrategy (fast - O(1) lookup)
# ============================================================================
puts "2. SymSpellStrategy (Fast - O(1) lookup after pre-computation)"
puts "-" * 80

require "kotoshu/suggestions/strategies/symspell_strategy"

sym_strategy = Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(dictionary: dict)

sym_times = {}
sym_results = {}

test_words.first(3).each do |word|
  context = Kotoshu::Suggestions::Context.new(
    word: word,
    dictionary: dict,
    max_results: 10
  )

  time = Benchmark.measure do
    result = sym_strategy.generate(context)
    sym_results[word] = result.to_words
  end

  sym_times[word] = time.real
  puts "  #{word}: #{sym_results[word].first(3).join(', ')} (#{time.real.round(4)}s)"
end

puts ""
puts "Full SymSpellStrategy test..."
time = Benchmark.measure do
  test_words.each do |word|
    context = Kotoshu::Suggestions::Context.new(word: word, dictionary: dict, max_results: 10)
    sym_strategy.generate(context)
  end
end
puts "  Total time for #{test_words.count} words: #{time.real.round(2)}s"
puts "  Average per word: #{(time.real / test_words.count).round(3)}s"
puts

# ============================================================================
# Algorithm 3: NgramStrategy (moderate - O(N) for similarity)
# ============================================================================
puts "3. NgramStrategy (Moderate - O(N) for Jaccard similarity)"
puts "-" * 80

require "kotoshu/suggestions/strategies/ngram_strategy"

ngram_strategy = Kotoshu::Suggestions::Strategies::NgramStrategy.new

ngram_times = {}
ngram_results = {}

test_words.first(3).each do |word|
  context = Kotoshu::Suggestions::Context.new(
    word: word,
    dictionary: dict,
    max_results: 10
  )

  time = Benchmark.measure do
    result = ngram_strategy.generate(context)
    ngram_results[word] = result.to_words
  end

  ngram_times[word] = time.real
  puts "  #{word}: #{ngram_results[word].first(3).join(', ')} (#{time.real.round(4)}s)"
end

puts ""
puts "Full NgramStrategy test..."
time = Benchmark.measure do
  test_words.each do |word|
    context = Kotoshu::Suggestions::Context.new(word: word, dictionary: dict, max_results: 10)
    ngram_strategy.generate(context)
  end
end
puts "  Total time for #{test_words.count} words: #{time.real.round(2)}s"
puts "  Average per word: #{(time.real / test_words.count).round(3)}s"
puts

# ============================================================================
# ACCURACY COMPARISON
# ============================================================================
puts "=" * 80
puts "ACCURACY COMPARISON (Found expected correction in top 10 suggestions)"
puts "=" * 80
puts

algorithms = {
  "EditDistance" => edit_results,
  "SymSpell" => sym_results,
  "Ngram" => ngram_results
}

algorithms.each do |name, results|
  puts "#{name}:"

  correct_count = 0
  total_count = 0

  test_words.each do |incorrect_word|
    expected = expected_corrections[incorrect_word]
    suggestions = results[incorrect_word] || []

    total_count += 1
    if suggestions.include?(expected)
      correct_count += 1
      status = "✓"
    else
      status = "✗"
      puts "  #{status} #{incorrect_word} → #{expected} (got: #{suggestions.first(3).join(', ')})"
    end
  end

  accuracy = (correct_count.to_f / total_count * 100).round(1)
  puts "  Accuracy: #{correct_count}/#{total_count} (#{accuracy}%)"
  puts ""
end

# ============================================================================
# SPEED COMPARISON
# ============================================================================
puts "=" * 80
puts "SPEED COMPARISON"
puts "=" * 80
puts

avg_edit = (edit_times.values.sum / edit_times.count).round(3)
avg_sym = (sym_times.values.sum / sym_times.count).round(3)
avg_ngram = (ngram_times.values.sum / ngram_times.count).round(3)

puts "EditDistanceStrategy:"
puts "  Average: #{avg_edit}s per word"
puts "  For #{test_words.count} words: ~#{(avg_edit * test_words.count / 60).round(1)} minutes"
puts

puts "SymSpellStrategy:"
puts "  Average: #{avg_sym}s per word"
puts "  Speedup: #{(avg_edit / avg_sym).round(1)}x faster than EditDistance"
puts "  For #{test_words.count} words: ~#{(avg_sym * test_words.count / 60).round(1)} seconds"
puts

puts "NgramStrategy:"
puts "  Average: #{avg_ngram}s per word"
puts "  Speedup: #{(avg_edit / avg_ngram).round(1)}x faster than EditDistance"
puts "  For #{test_words.count} words: ~#{(avg_ngram * test_words.count / 60).round(1)} seconds"
puts

# ============================================================================
# SUMMARY
# ============================================================================
puts "=" * 80
puts "SUMMARY & RECOMMENDATIONS"
puts "=" * 80
puts
puts "Performance Ranking (fastest to slowest):"
puts "  1. SymSpellStrategy: ~#{avg_sym}s (O(1) lookup after pre-computation)"
puts "  2. NgramStrategy: ~#{avg_ngram}s (O(N) similarity comparison)"
puts "  3. EditDistanceStrategy: ~#{avg_edit}s (O(N*M) full scan)"
puts

puts ""
puts "RECOMMENDATIONS:"
puts "  • Use SymSpellStrategy for production (fastest, good accuracy)"
puts "  • Use CompositeStrategy to combine multiple algorithms for best results"
puts "  • EditDistanceStrategy is too slow for large dictionaries (>100k words)"
puts

puts "=" * 80
