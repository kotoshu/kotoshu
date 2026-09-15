#!/usr/bin/env ruby
# frozen_string_literal: true

# Port of Spylls examples/suggest.py to Ruby
#
# This example demonstrates using the suggester API to get
# spelling suggestions for misspelled words.

require_relative "../lib/kotoshu"

# Create a Hunspell dictionary from en_US files
examples_dir = File.expand_path(__dir__)
dictionary = Kotoshu::Dictionary::Hunspell.new(
  dic_path: File.join(examples_dir, "en_US.dic"),
  aff_path: File.join(examples_dir, "en_US.aff"),
  language_code: "en-US"
)

# Get suggestions for a misspelled word
# Note: Kotoshu's suggest method uses a different algorithm than Spylls
# and may return different results

word = "spylls"
puts "Suggestions for '#{word}':"

suggestions = dictionary.suggest(word)

if suggestions.empty?
  puts "  (No suggestions found - this may be expected for some words)"
else
  suggestions.each do |suggestion|
    puts "  - #{suggestion}"
  end
end

# Try with a word that's more likely to have suggestions
puts "\nSuggestions for 'helo':"
suggestions = dictionary.suggest("helo")
suggestions.each { |s| puts "  - #{s}" }
