#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 7: Multi-Language Dictionaries
#
# This example demonstrates how to use Kotoshu with multiple languages
# by loading dictionaries from the kotoshu/dictionaries repository.

require_relative "../lib/kotoshu"

puts "=== Example 7: Multi-Language Dictionaries ==="
puts

# Example 1: Load a specific dictionary by code
puts "1. Loading a Dictionary by Code"
puts "-" * 40

catalog = Kotoshu::Dictionaries::Catalog

# Find and load British English dictionary
en_gb_entry = catalog.find("en-GB")
if en_gb_entry
  puts "Found: #{en_gb_entry.description}"
  puts "Source: #{en_gb_entry.source}"
  puts "License: #{en_gb_entry.license}"
  puts "URL: #{en_gb_entry.dic_url}"
  puts

  en_gb_dict = en_gb_entry.load
  puts "Loaded #{en_gb_dict.size} words"
  puts "Has 'colour': #{en_gb_dict.lookup?('colour')}"
  puts "Has 'color': #{en_gb_dict.lookup?('color')}"
else
  puts "Dictionary not found"
end

puts
puts "=" * 40
puts

# Example 2: List all dictionaries for a language
puts "2. All English Dictionaries"
puts "-" * 40

english_dicts = catalog.by_language("en")
puts "Found #{english_dicts.size} English dictionaries:"
english_dicts.each do |entry|
  puts "  #{entry.code}: #{entry.name} (#{entry.word_count} words)"
end

puts
puts "=" * 40
puts

# Example 3: List all available languages
puts "3. All Available Languages"
puts "-" * 40

languages = catalog.languages
puts "Supported languages (#{languages.size}):"
puts languages.join(", ")

puts
puts "=" * 40
puts

# Example 4: Create spellcheckers for different languages
puts "4. Multi-Language Spellcheckers"
puts "-" * 40

# Load dictionaries for multiple languages
languages_to_test = %w[en de es fr]

spellcheckers = {}
languages_to_test.each do |lang|
  entry = catalog.find(lang)
  next unless entry

  begin
    dict = entry.load
    spellcheckers[lang] = Kotoshu::Spellchecker.new(dictionary: dict)
    puts "✓ Loaded #{entry.name}: #{dict.size} words"
  rescue StandardError => e
    puts "✗ Failed to load #{entry.name}: #{e.message}"
  end
end

puts
puts "Testing multi-language spellchecking:"
puts

# Test words in different languages
test_cases = {
  "en" => { correct: "hello", incorrect: "helo" },
  "de" => { correct: "hallo", incorrect: "hllo" },
  "es" => { correct: "hola", incorrect: "hla" },
  "fr" => { correct: "bonjour", incorrect: "bnjour" }
}

test_cases.each do |lang, words|
  checker = spellcheckers[lang]
  next unless checker

  correct_result = checker.correct?(words[:correct])
  incorrect_result = checker.check_word(words[:incorrect])

  status = correct_result ? "✓" : "✗"
  puts "#{status} #{lang.upcase} '#{words[:correct]}': #{correct_result}"

  if incorrect_result.has_suggestions?
    puts "  Suggestions for '#{words[:incorrect]}': #{incorrect_result.top_suggestions(3).join(', ')}"
  end
end

puts
puts "=" * 40
puts

# Example 5: Hunspell vs Plain Text formats
puts "5. Dictionary Formats"
puts "-" * 40

hunspell_dicts = catalog.hunspell
plain_text_dicts = catalog.plain_text

puts "Hunspell dictionaries: #{hunspell_dicts.size}"
puts "Plain text dictionaries: #{plain_text_dicts.size}"
puts

# Show some examples of each
puts "Hunspell examples:"
hunspell_dicts.first(5).each do |entry|
  puts "  #{entry.code}: #{entry.description}"
end

puts
puts "Plain text examples:"
plain_text_dicts.each do |entry|
  puts "  #{entry.code}: #{entry.description}"
end

puts
puts "=" * 40
puts

# Example 6: Filter by license
puts "6. Dictionaries by License"
puts "-" * 40

public_domain = catalog.by_license("Public Domain")
gpl = catalog.by_license("GPL")

puts "Public Domain dictionaries: #{public_domain.size}"
public_domain.each do |entry|
  puts "  #{entry.code}: #{entry.name}"
end

puts
puts "GPL dictionaries: #{gpl.size}"
gpl.first(5).each do |entry|
  puts "  #{entry.code}: #{entry.name}"
end

puts
puts "=" * 40
puts

# Example 7: Catalog statistics
puts "7. Catalog Statistics"
puts "-" * 40

stats = catalog.statistics

puts "Total dictionaries: #{stats[:total]}"
puts "  Hunspell: #{stats[:hunspell]}"
puts "  Plain text: #{stats[:plain_text]}"
puts
puts "Languages: #{stats[:languages]}"
puts "Total words: #{stats[:total_words].round}"
puts
puts "By format:"
stats[:formats].each do |format, count|
  puts "  #{format}: #{count}"
end

puts
puts "By license:"
stats[:licenses].each do |license, count|
  puts "  #{license}: #{count}"
end

puts
puts "=" * 40
puts

# Example 8: Create spellcheckers with regional variants
puts "8. English Regional Variants"
puts "-" * 40

english_variants = %w[en en-GB en-CA en-AU en-ZA]

english_variants.each do |code|
  entry = catalog.find(code)
  next unless entry

  begin
    dict = entry.load
    checker = Kotoshu::Spellchecker.new(dictionary: dict)

    # Test a word with different spellings
    colour_result = checker.correct?("colour")
    color_result = checker.correct?("color")

    puts "#{entry.name}:"
    puts "  'colour': #{colour_result ? '✓' : '✗'}"
    puts "  'color': #{color_result ? '✓' : '✗'}"
  rescue StandardError => e
    puts "#{entry.name}: ✗ Error - #{e.message}"
  end
end

puts
puts "=" * 40
puts

# Example 9: Loading large dictionaries with performance
puts "9. Large Dictionary Performance"
puts "-" * 40

require "benchmark"

large_dicts = %w[en de es fr ru]

large_dicts.each do |lang|
  entry = catalog.find(lang)
  next unless entry

  begin
    load_time = Benchmark.realtime do
      dict = entry.load
      checker = Kotoshu::Spellchecker.new(dictionary: dict)
      checker.correct?("hello")
    end

    puts "#{entry.name}: #{(load_time * 1000).round(1)}ms (load + check)"
  rescue StandardError => e
    puts "#{entry.name}: ✗ Error - #{e.message}"
  end
end

puts
puts "=" * 40
puts

# Example 10: Dictionary metadata
puts "10. Dictionary Metadata"
puts "-" * 40

entry = catalog.find("ru")
if entry
  puts "Code: #{entry.code}"
  puts "Name: #{entry.name}"
  puts "Language: #{entry.language}"
  puts "Region: #{entry.region || 'N/A'}"
  puts "Format: #{entry.format}"
  puts "Source: #{entry.source}"
  puts "License: #{entry.license}"
  puts "Word count: #{entry.word_count}"
  puts "Dictionary URL: #{entry.dic_url}"
  if entry.aff_url
    puts "Affix URL: #{entry.aff_url}"
  end
  puts "Metadata: #{entry.metadata.inspect}"
end

puts
puts "=" * 40
puts

puts "For more information, see:"
puts "  https://github.com/kotoshu/dictionaries"
puts
