#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 4: Trie Data Structure
#
# This example demonstrates how to use the Trie data structure
# for efficient word lookup and prefix-based operations.

require_relative "../lib/kotoshu"

puts "=== Example 4: Trie Data Structure ==="
puts

# Build a trie from an array of words
words = %w[
  hello help held heap
  world work word
  test text toast
  run running runner
]

trie = Kotoshu.trie(words)

puts "Built trie with #{words.size} words"
puts "All words: #{trie.all_words.inspect}"
puts

# Lookup operations
puts "Lookup Operations:"
puts "-" * 20
puts "Has 'hello': #{trie.lookup?("hello")}"
puts "Has 'hell': #{trie.lookup?("hell")}"
puts "Has 'HELLO' (case-sensitive): #{trie.lookup?("HELLO")}"
puts

# Prefix operations
puts "Prefix Operations:"
puts "-" * 20
puts "Has prefix 'hel': #{trie.has_prefix?("hel")}"
puts "Has prefix 'wor': #{trie.has_prefix?("wor")}"
puts "Has prefix 'xyz': #{trie.has_prefix?("xyz")}"
puts

# Words with prefix
puts "Words with prefix 'hel': #{trie.words_with_prefix("hel").inspect}"
puts "Words with prefix 'te': #{trie.words_with_prefix("te").inspect}"
puts

# Suggestions based on prefix
puts "Suggestions for 'hel':"
puts "  #{trie.suggestions("hel", max_results: 10).inspect}"
puts

puts "Suggestions for 'te':"
puts "  #{trie.suggestions("te", max_results: 10).inspect}"
puts

# Traverse the trie
puts "Traversing trie:"
puts "-" * 20
trie.each_word do |word, payload|
  puts "  #{word} (payload: #{payload.inspect})"
end
puts

# Trie builder methods
puts "Building tries from different sources:"
puts "-" * 20

# From string
string_trie = Kotoshu.trie("hello world test")
puts "From string: #{string_trie.all_words.inspect}"

# From file (if exists)
test_file = "dictionaries/plain_text/en_US/words.txt"
if File.exist?(test_file)
  file_trie = Kotoshu.trie(test_file)
  puts "From file: loaded #{file_trie.size} words"
  puts "First 5 words: #{file_trie.all_words.first(5).inspect}"
end

# Trie set operations
puts
puts "Trie Set Operations:"
puts "-" * 20

trie1 = Kotoshu.trie(%w[hello world test])
trie2 = Kotoshu.trie(%w[hello world ruby])

puts "Trie 1: #{trie1.all_words.inspect}"
puts "Trie 2: #{trie2.all_words.inspect}"
puts

# Union (|)
union = trie1 | trie2
puts "Union: #{union.all_words.inspect}"

# Intersection (&)
intersection = trie1 & trie2
puts "Intersection: #{intersection.all_words.inspect}"

# Merge (mutating)
merged = trie1.dup
merged.merge!(trie2)
puts "Merged: #{merged.all_words.inspect}"

# Difference
# Note: Trie doesn't have difference (-) operator, but we can simulate it
all_words = trie1.all_words | trie2.all_words
common = trie1.all_words & trie2.all_words
difference = all_words - common
puts "Words in only one trie: #{difference.inspect}"

puts
puts "Trie Statistics:"
puts "-" * 20
puts "Total words: #{trie.size}"
puts "Unique prefixes: #{trie.count_prefixes}"
puts "Max depth: #{trie.max_depth}"

# Advanced: Payload storage
puts
puts "Advanced: Payload Storage:"
puts "-" * 20

payload_trie = Kotoshu::Core::Trie::Builder.new
payload_trie.add_word("hello", { definition: "a greeting", count: 5 })
payload_trie.add_word("help", { definition: "assistance", count: 3 })
payload_trie.add_word("world", { definition: "earth", count: 1 })

payload_trie_obj = payload_trie.build

puts "Word 'hello' payload: #{payload_trie_obj.search("hello")&.payload.inspect}"
puts "Word 'help' payload: #{payload_trie_obj.search("help")&.payload.inspect}"

# Convert IndexedDictionary to trie
puts
puts "IndexedDictionary to Trie:"
puts "-" * 20

dict = Kotoshu.dictionary(%w[hello world test])
trie_from_dict = dict.to_trie

puts "Dictionary words: #{dict.words.inspect}"
puts "Trie words: #{trie_from_dict.all_words.inspect}"
puts "Trie has 'hello': #{trie_from_dict.lookup?("hello")}"
