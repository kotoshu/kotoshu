#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 1: Basic Word Checking
#
# This example demonstrates the simplest way to use Kotoshu
# to check if words are spelled correctly.

require_relative "../lib/kotoshu"

puts "=== Example 1: Basic Word Checking ==="
puts

# Check if words are correct
puts "Is 'hello' correct? #{Kotoshu.correct?("hello")}"
puts "Is 'world' correct? #{Kotoshu.correct?("world")}"
puts "Is 'helo' correct? #{Kotoshu.correct?("helo")}"
puts "Is 'Kotoshu' correct? #{Kotoshu.correct?("Kotoshu")}"
puts

# Get suggestions for misspelled words
puts "Suggestions for 'helo':"
suggestions = Kotoshu.suggest("helo")
puts suggestions.to_words.join(", ")
puts

puts "Suggestions for 'wrold':"
suggestions = Kotoshu.suggest("wrold")
puts suggestions.to_words.join(", ")
puts

# Check multiple words
words = %w[hello world test helo wrold]
puts "Checking multiple words:"
words.each do |word|
  status = Kotoshu.correct?(word) ? "✓" : "✗"
  puts "  #{status} #{word}"
end
