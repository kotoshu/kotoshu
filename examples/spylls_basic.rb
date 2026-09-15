#!/usr/bin/env ruby
# frozen_string_literal: true

# Port of Spylls examples/basic.py to Ruby
#
# This example demonstrates basic spell checking with Kotoshu
# using the Hunspell dictionary backend.

require_relative "../lib/kotoshu"

# Create a Hunspell dictionary from en_US files
# Note: Kotoshu uses explicit paths for .dic and .aff files
examples_dir = File.expand_path(__dir__)
dictionary = Kotoshu::Dictionary::Hunspell.new(
  dic_path: File.join(examples_dir, "en_US.dic"),
  aff_path: File.join(examples_dir, "en_US.aff"),
  language_code: "en-US"
)

# Check if words are in the dictionary
puts "Lookup 'spells': #{dictionary.lookup("spells")}"  # => true
puts "Lookup 'spylls': #{dictionary.lookup("spylls")}"  # => false

# Get spelling suggestions for a misspelled word
# Note: Kotoshu's suggest method uses a different algorithm than Spylls
# and may return different results
puts "\nSuggestions for 'spylls':"
suggestions = dictionary.suggest("spylls")
if suggestions.empty?
  puts "  [] (No suggestions - algorithm may differ from Spylls)"
else
  puts suggestions.inspect
end

# Try with a word that's more likely to have suggestions
puts "\nSuggestions for 'helo':"
suggestions = dictionary.suggest("helo")
puts suggestions.inspect
