#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 2: Text and Document Checking
#
# This example demonstrates how to check paragraphs and documents
# for spelling errors and get detailed results.

require_relative "../lib/kotoshu"

puts "=== Example 2: Text and Document Checking ==="
puts

# Check a paragraph of text
text = <<~TEXT
  Hello wrold!

  This is a test document with some misspelled words.
  We want to see if the spellchcker can find them al.

  Teh quick brown fox jumps over the lazy dog.
  Lorem ipsum dolor sit amet, consectetur adipiscing elit.
TEXT

puts "Checking text:"
puts "-" * 40
result = Kotoshu.check(text)

if result.success?
  puts result.to_s
else
  puts result.to_s
  puts
  puts "Errors found:"
  result.each_error do |error|
    suggestions_str = error.has_suggestions? ?
                       " (did you mean #{error.top_suggestions(3).join(', ')}?)" :
                       ""
    puts "  • #{error.word}#{suggestions_str}"
  end
end

puts
puts "=" * 40
puts

# Check a file
file_path = "spec/fixtures/documents/with_errors.txt"
if File.exist?(file_path)
  puts "Checking file: #{file_path}"
  puts "-" * 40

  file_result = Kotoshu.check_file(file_path)

  if file_result.success?
    puts "✓ No errors found (#{file_result.word_count} words checked)"
  else
    puts "✗ #{file_result.error_count} error(s) found:"
    puts
    file_result.each_unique_error do |word, errors|
      puts "  • #{word} (appears #{errors.size}x)"
      first_error = errors.first
      if first_error.has_suggestions?
        puts "    Suggestions: #{first_error.top_suggestions(3).join(', ')}"
      end
    end
  end
end

puts
puts "=" * 40
puts

# Document result statistics
puts "Document Statistics:"
puts "  Word count: #{result.word_count}"
puts "  Error count: #{result.error_count}"
puts "  Unique errors: #{result.unique_error_count}"
puts "  Error summary: #{result.error_summary.inspect}"
