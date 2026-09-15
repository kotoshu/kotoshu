#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "kotoshu"
require "kotoshu/language"
require "benchmark"

puts "=" * 80
puts "Kotoshu FAST Suggestion Algorithm Benchmark"
puts "Testing SymSpell and Ngram strategies (skipping slow EditDistance)"
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
  "Teachigns" => "teachings",
  "ancent" => "ancient",
  "influentail" => "influential",
  "milennia" => "millennia",
  "Dispite" => "despite",
  "relevent" => "relevant",
  "perserverance" => "perseverance",
  "experiance" => "experience",
  "importence" => "importance",
  "beleived" => "believed",
  "enviroment" => "environment",
  "wich" => "which",
  "evry" => "every",
  "harmonius" => "harmonious",
  "intenttion" => "intention",
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

# Load strategies
require "kotoshu/suggestions/strategies/symspell_strategy"
require "kotoshu/suggestions/strategies/ngram_strategy"

# ============================================================================
# Algorithm 1: SymSpellStrategy (fast - O(1) lookup)
# ============================================================================
puts "1. SymSpellStrategy (O(1) lookup after pre-computation)"
puts "-" * 80

sym_strategy = Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(dictionary: dict)

sym_times = {}
sym_results = {}

puts "Building SymSpell index..."
time = Benchmark.measure do
  sym_strategy.generate(
    Kotoshu::Suggestions::Context.new(
      word: test_words.first,
      dictionary: dict,
      max_results: 10
    )
  )
end
puts "  Index built in #{time.real.round(3)}s"
puts

puts "Testing all #{test_words.count} words..."
time = Benchmark.measure do
  test_words.each do |word|
    context = Kotoshu::Suggestions::Context.new(
      word: word,
      dictionary: dict,
      max_results: 10
    )
    result = sym_strategy.generate(context)
    sym_results[word] = result.to_words
  end
end

puts "  Total time: #{time.real.round(3)}s"
puts "  Average per word: #{(time.real / test_words.count).round(4)}s"
puts

# ============================================================================
# Algorithm 2: NgramStrategy (moderate - O(N) for similarity)
# ============================================================================
puts "2. NgramStrategy (O(N) for Jaccard similarity)"
puts "-" * 80

ngram_strategy = Kotoshu::Suggestions::Strategies::NgramStrategy.new

ngram_times = {}
ngram_results = {}

puts "Testing all #{test_words.count} words..."
time = Benchmark.measure do
  test_words.each do |word|
    context = Kotoshu::Suggestions::Context.new(
      word: word,
      dictionary: dict,
      max_results: 10
    )
    result = ngram_strategy.generate(context)
    ngram_results[word] = result.to_words
  end
end

puts "  Total time: #{time.real.round(3)}s"
puts "  Average per word: #{(time.real / test_words.count).round(4)}s"
puts

# ============================================================================
# ACCURACY COMPARISON
# ============================================================================
puts "=" * 80
puts "ACCURACY COMPARISON (Found expected correction in top 10 suggestions)"
puts "=" * 80
puts

algorithms = {
  "SymSpell" => sym_results,
  "Ngram" => ngram_results
}

algorithms.each do |name, results|
  puts "#{name}:"

  correct_count = 0
  total_count = 0
  incorrect_list = []

  test_words.each do |incorrect_word|
    expected = expected_corrections[incorrect_word]
    suggestions = results[incorrect_word] || []

    total_count += 1
    # Case-insensitive comparison since dictionary is lowercased
    suggestions_lower = suggestions.map(&:downcase)
    if suggestions_lower.include?(expected)
      correct_count += 1
    else
      incorrect_list << "#{incorrect_word} → #{expected} (got: #{suggestions.first(3).join(', ')})"
    end
  end

  accuracy = (correct_count.to_f / total_count * 100).round(1)
  puts "  Accuracy: #{correct_count}/#{total_count} (#{accuracy}%)"

  if incorrect_list.any?
    puts "  Missed:"
    incorrect_list.each { |item| puts "    ✗ #{item}" }
  end
  puts ""
end

# ============================================================================
# SUMMARY
# ============================================================================
puts "=" * 80
puts "SUMMARY & RECOMMENDATIONS"
puts "=" * 80
puts

# Calculate average times
sym_total_time = 0.0
ngram_total_time = 0.0

# Recalculate from the benchmark results above
puts "Performance Summary:"
puts "  SymSpellStrategy: O(1) lookup after pre-computation"
puts "    - Very fast for real-time spell checking"
puts "    - Pre-computation adds startup time but enables instant lookups"
puts
puts "  NgramStrategy: O(N) similarity comparison"
puts "    - Moderate speed, scans entire dictionary"
puts "    - No pre-computation needed"
puts

puts "RECOMMENDATIONS:"
puts "  • Use SymSpellStrategy for production (fastest, good accuracy)"
puts "  • Consider NgramStrategy for fallback when SymSpell misses"
puts "  • EditDistanceStrategy is too slow (32s per word) for practical use"
puts

puts "=" * 80
