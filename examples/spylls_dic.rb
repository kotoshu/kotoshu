#!/usr/bin/env ruby
# frozen_string_literal: true

# Port of Spylls examples/dic.rb to Ruby
#
# This example demonstrates dictionary internal access methods
# including accessing the word index and finding homonyms.

require_relative "../lib/kotoshu"

# Create a Hunspell dictionary from en_US files
examples_dir = File.expand_path(__dir__)
dictionary = Kotoshu::Dictionary::Hunspell.new(
  dic_path: File.join(examples_dir, "en_US.dic"),
  aff_path: File.join(examples_dir, "en_US.aff"),
  language_code: "en-US"
)

# Access the internal word index
# Note: In Kotoshu, we use the words method to get all words
puts dictionary.words.first(10).inspect

# Find homonyms - words with the same spelling but different meanings/flags
# Note: Kotoshu stores words with flags in the index
# This method finds all entries for a given word stem
def find_homonyms(dict, word)
  # Get the word index (internal access)
  word_index = dict.instance_variable_get(:@word_index)

  # Find all variants of the word
  word_index.select { |key, _| key.downcase == word.downcase }
end

# Example: find homonyms for "spell"
homonyms = find_homonyms(dictionary, "spell")
puts homonyms.inspect
