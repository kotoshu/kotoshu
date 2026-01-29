#!/usr/bin/env ruby
# frozen_string_literal: true

# Example 3: Using Different Dictionary Backends
#
# This example demonstrates how to use different dictionary backends
# including UnixWords, PlainText, Custom, and Hunspell.

require_relative "../lib/kotoshu"

puts "=== Example 3: Dictionary Backends ==="
puts

# Example 1: UnixWords dictionary
puts "1. UnixWords Dictionary (System Dictionary)"
puts "-" * 40

unix_dict = Kotoshu::Dictionary::UnixWords.detect(language_code: "en-US")
if unix_dict
  puts "Loaded: #{unix_dict.path}"
  puts "Words: #{unix_dict.size}"
  puts "Has 'hello': #{unix_dict.lookup?("hello")}"
  puts "Has 'Kotoshu': #{unix_dict.lookup?("Kotoshu")}"
  suggestions = unix_dict.suggest("helo", max_suggestions: 5)
  puts "Suggestions for 'helo': #{suggestions.join(', ')}"
else
  puts "No system dictionary found"
end

puts
puts "=" * 40
puts

# Example 2: PlainText dictionary
puts "2. PlainText Dictionary"
puts "-" * 40

plain_dict = Kotoshu::Dictionary::PlainText.from_words(
  %w[hello world kotoshu ruby spellchecker],
  language_code: "en"
)

puts "Created dictionary with #{plain_dict.size} words"
puts "Has 'hello': #{plain_dict.lookup?("hello")}"
puts "Has 'ruby': #{plain_dict.lookup?("ruby")}"
puts "Has 'python': #{plain_dict.lookup?("python")}"

# Add a word dynamically
plain_dict.add_word("python")
puts "After adding 'python': #{plain_dict.lookup?("python")}"
plain_dict.add_word("Kotoshu")
puts "After adding 'Kotoshu': #{plain_dict.lookup?("Kotoshu")}"

puts
puts "=" * 40
puts

# Example 3: Custom dictionary
puts "3. Custom Dictionary (In-Memory)"
puts "-" * 40

custom_dict = Kotoshu::Dictionary::Custom.new(
  words: %w[Kotoshu spellchecker ruby],
  language_code: "en"
)

puts "Created custom dictionary"
puts "Words: #{custom_dict.words.inspect}"
puts "Size: #{custom_dict.size}"
puts "Has 'Kotoshu': #{custom_dict.lookup?("Kotoshu")}"

# Merge with another array
custom_dict.merge(%w[gem library code])
puts "After merging: #{custom_dict.words.inspect}"

puts
puts "=" * 40
puts

# Example 4: Hunspell dictionary (if available)
puts "4. Hunspell Dictionary"
puts "-" * 40

hunspell_dic = "dictionaries/hunspell/test/en_US_test.dic"
hunspell_aff = "dictionaries/hunspell/test/en_US_test.aff"

if File.exist?(hunspell_dic) && File.exist?(hunspell_aff)
  hunspell_dict = Kotoshu::Dictionary::Hunspell.new(
    dic_path: hunspell_dic,
    aff_path: hunspell_aff,
    language_code: "en-US"
  )

  puts "Loaded Hunspell dictionary"
  puts "Words: #{hunspell_dict.size}"
  puts "Has 'hello': #{hunspell_dict.lookup?("hello")}"
  puts "Has 'hello' (case-insensitive): #{hunspell_dict.lookup?("HELLO")}"
  puts "Has 'runs': #{hunspell_dict.lookup?("runs")}"
  puts "Has 'running': #{hunspell_dict.lookup?("running")}"

  # Show word variants using affix rules
  puts "\nWord variants for 'run':"
  variants = hunspell_dict.word_variants("run")
  puts "  #{variants.inspect}"
else
  puts "Hunspell test dictionary not found at:"
  puts "  #{hunspell_dic}"
  puts "  #{hunspell_aff}"
end

puts
puts "=" * 40
puts

# Example 5: CSpell dictionary
puts "5. CSpell Dictionary (Trie-based)"
puts "-" * 40

cspell_dict = Kotoshu::Dictionary::CSpell.from_words(
  %w[hello world kotoshu ruby gem],
  language_code: "en"
)

puts "Created CSpell dictionary with trie"
puts "Words: #{cspell_dict.words.inspect}"
puts "Size: #{cspell_dict.size}"
puts "Has 'hello': #{cspell_dict.lookup?("hello")}"
puts "Has prefix 'hel': #{cspell_dict.has_prefix?("hel")}"
puts "Words with prefix 'hel': #{cspell_dict.words_with_prefix("hel").inspect}"

# Convert to trie
trie = cspell_dict.trie
puts "\nTrie structure:"
puts "  Has 'hello': #{trie.lookup?("hello")}"
puts "  Has prefix 'wo': #{trie.has_prefix?("wo")}"
puts "  Words with prefix 'wo': #{trie.words_with_prefix("wo").inspect}"
puts "  Suggestions for 'he': #{trie.suggestions("he").inspect}"
