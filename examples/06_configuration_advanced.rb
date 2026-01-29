#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 6: Configuration and Advanced Usage
#
# This example demonstrates how to configure Kotoshu and use
# advanced features like custom words, multiple languages, etc.

require_relative "../lib/kotoshu"

puts "=== Example 6: Configuration and Advanced Usage ==="
puts

# Example 1: Global Configuration
puts "1. Global Configuration"
puts "-" * 40

Kotoshu.configure do |config|
  config.dictionary_type = :plain_text
  config.dictionary_path = "dictionaries/plain_text/en_US/words.txt"
  config.language = "en-US"
  config.max_suggestions = 15
  config.case_sensitive = false
  config.custom_words = %w[Kotoshu spellcheck]
end

puts "Configuration:"
config = Kotoshu.configuration
puts "  Dictionary type: #{config.dictionary_type}"
puts "  Dictionary path: #{config.dictionary_path}"
puts "  Language: #{config.language}"
puts "  Max suggestions: #{config.max_suggestions}"
puts "  Case sensitive: #{config.case_sensitive}"
puts "  Custom words: #{config.custom_words.inspect}"
puts

# Use the configured spellchecker
puts "Using configured spellchecker:"
puts "  Has 'hello': #{Kotoshu.correct?("hello")}"
puts "  Has 'Kotoshu': #{Kotoshu.correct?("Kotoshu")}"
suggestions = Kotoshu.suggest("helo")
puts "  Suggestions for 'helo': #{suggestions.to_words.join(", ").first(50)}..."

puts
puts "=" * 40
puts

# Example 2: Spellchecker Instance with Custom Configuration
puts "2. Custom Spellchecker Instance"
puts "-" * 40

# Create a custom dictionary
custom_dict = Kotoshu::Dictionary::Custom.new(
  words: %w[ruby gem rspec rake bundler],
  language_code: "en"
)

# Create a spellchecker with the custom dictionary
custom_spellchecker = Kotoshu::Spellchecker.new(dictionary: custom_dict)

puts "Custom spellchecker with Ruby-related words:"
puts "  Has 'ruby': #{custom_spellchecker.correct?("ruby")}"
puts "  Has 'gem': #{custom_spellchecker.correct?("gem")}"
puts "  Has 'rake': #{custom_spellchecker.correct?("rake")}"
puts "  Has 'python': #{custom_spellchecker.correct?("python")}"
puts "  Suggestions for 'rke': #{custom_spellchecker.suggest("rke").to_words.join(", ")}"

puts
puts "=" * 40
puts

# Example 3: Dictionary Repository
puts "3. Dictionary Repository"
puts "-" * 40

repo = Kotoshu::Dictionary::Repository.new

# Register multiple dictionaries
repo.register(:en_US, custom_dict)
repo.register(:programming, Kotoshu::Dictionary::PlainText.from_words(
  %w[code function variable class module],
  language_code: "en"
))
repo.register(:tech, Kotoshu::Dictionary::PlainText.from_words(
  %w[computer software hardware internet api],
  language_code: "en"
))

puts "Registered dictionaries:"
repo.keys.each do |key|
  dict = repo.get(key)
  puts "  #{key}: #{dict.size} words (#{dict.type})"
end

puts "\nFind by language 'en':"
found = repo.find_by_language("en")
found.each do |dict|
  puts "  #{dict.type}: #{dict.size} words"
end

puts
puts "=" * 40
puts

# Example 4: IndexedDictionary
puts "4. IndexedDictionary (Rich Query Interface)"
puts "-" * 40

index_dict = Kotoshu.dictionary(%w[
  hello help held heap
  world work word
  test text toast
  run running runner
  code coding coded
])

puts "IndexedDictionary: #{index_dict.size} words"
puts

puts "Query methods:"
puts "  Words starting with 'he': #{index_dict.find_by_prefix('he').inspect}"
puts "  Words ending with 'ld': #{index_dict.find_by_suffix('ld').inspect}"
puts "  Words with length 3: #{index_dict.find_by_length(3).inspect}"
puts "  Words matching pattern 't.*t': #{index_dict.find_by_pattern(/t.*t/).inspect}"
puts

puts "Statistics:"
stats = index_dict.statistics
stats.each do |key, value|
  puts "  #{key}: #{value}"
end

puts
puts "=" * 40
puts

# Example 5: WordResult and DocumentResult
puts "5. Result Objects"
puts "-" * 40

# Check a word
word_result = Kotoshu.spellchecker.check_word("hello")
puts "WordResult for 'hello':"
puts "  Word: #{word_result.word}"
puts "  Correct: #{word_result.correct?}"
puts "  Has suggestions: #{word_result.has_suggestions?}"
puts

word_result2 = Kotoshu.spellchecker.check_word("helo")
puts "WordResult for 'helo':"
puts "  Word: #{word_result2.word}"
puts "  Correct: #{word_result2.correct?}"
puts "  Suggestion count: #{word_result2.suggestion_count}"
puts "  First suggestion: #{word_result2.first_suggestion}"
puts "  Top 3: #{word_result2.top_suggestions(3).join(", ")}"
puts

# Check text
text_result = Kotoshu.spellchecker.check("Hello wrold! This is a tst.")
puts "DocumentResult:"
puts "  Success: #{text_result.success?}"
puts "  Word count: #{text_result.word_count}"
puts "  Error count: #{text_result.error_count}"
puts "  Unique errors: #{text_result.unique_error_count}"
puts
puts "  Errors:"
text_result.errors.each do |error|
  suggestions_str = error.has_suggestions? ?
                     " (suggestions: #{error.top_suggestions(2).join(", ")})" :
                     ""
  puts "    • #{error.word} at position #{error.position}#{suggestions_str}"
end

puts
puts "=" * 40
puts

# Example 6: Multiple File Checking
puts "6. Batch File Checking"
puts "-" * 40

# Check multiple files
fixtures_dir = "spec/fixtures/documents"
if Dir.exist?(fixtures_dir)
  files = Dir.glob(File.join(fixtures_dir, "*.txt"))
  puts "Checking #{files.size} files..."
  puts

  files.each do |file|
    result = Kotoshu.check_file(file)
    status = result.success? ? "✓" : "✗"
    filename = File.basename(file)
    puts "#{status} #{filename}: #{result.error_count} error(s), #{result.word_count} words"
  end

  puts

  # Get all results at once
  results = Kotoshu.check_files(files)
  total_errors = results.sum(&:error_count)
  total_words = results.sum(&:word_count)
  failed_count = results.count(&:failed?)

  puts "Summary:"
  puts "  Files checked: #{files.size}"
  puts "  Files with errors: #{failed_count}"
  puts "  Total errors: #{total_errors}"
  puts "  Total words: #{total_words}"
end

puts
puts "=" * 40
puts

# Example 7: Error Handling
puts "7. Error Handling"
puts "-" * 40

begin
  # Try to load a non-existent dictionary
  bad_config = Kotoshu::Configuration.new(
    dictionary_type: :plain_text,
    dictionary_path: "/nonexistent/path.txt"
  )
  bad_config.load_dictionary
rescue Kotoshu::DictionaryNotFoundError => e
  puts "Caught DictionaryNotFoundError:"
  puts "  Message: #{e.message}"
  puts "  Path: #{e.path}"
end

puts

begin
  # Try to use an invalid dictionary type
  bad_config2 = Kotoshu::Configuration.new(
    dictionary_type: :invalid_type
  )
  bad_config2.load_dictionary
rescue Kotoshu::ConfigurationError => e
  puts "Caught ConfigurationError:"
  puts "  Message: #{e.message}"
  puts "  Key: #{e.key.inspect}"
end

puts
puts "=" * 40
puts

# Example 8: Thread Safety (each instance is independent)
puts "8. Thread Safety"
puts "-" * 40

# Create two independent spellcheckers
spell1 = Kotoshu::Spellchecker.new(
  dictionary: Kotoshu::Dictionary::Custom.new(
    words: %w[hello world],
    language_code: "en"
  )
)

spell2 = Kotoshu::Spellchecker.new(
  dictionary: Kotoshu::Dictionary::Custom.new(
    words: %w[ruby python],
    language_code: "en"
  )
)

puts "Spellchecker 1 words: #{spell1.dictionary.words.inspect}"
puts "Spellchecker 2 words: #{spell2.dictionary.words.inspect}"
puts
puts "Spellchecker 1 has 'hello': #{spell1.correct?("hello")}"
puts "Spellchecker 1 has 'ruby': #{spell1.correct?("ruby")}"
puts "Spellchecker 2 has 'hello': #{spell2.correct?("hello")}"
puts "Spellchecker 2 has 'ruby': #{spell2.correct?("ruby")}"
