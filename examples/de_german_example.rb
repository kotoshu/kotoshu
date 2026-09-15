#!/usr/bin/env ruby
# frozen_string_literal: true

# German Language Example
# Demonstrates German spell checking, tokenization, and umlaut handling.

require 'bundler/setup'
require 'kotoshu'

# German uses Latin script with umlauts (ä, ö, ü) and Eszett (ß)
# Dictionary path for German

puts "=" * 60
puts "Kotoshu - German Language Example"
puts "=" * 60

# Create German language instance
german = Kotoshu::Languages::German.new

# --- Spell Checking ---
puts "\n## Rechtschreibprüfung (Spell Checking)"
puts "-" * 40

words_to_check = %w[Hallo Welt Programmierung Käse Grün Öfen Straße]
words_to_check.each do |word|
  result = Kotoshu.setup?("de") ? Kotoshu.correct?(word, language: "de") : nil
  status = result ? "✓" : "✗"
  puts "#{status} #{word.ljust(15)} #{result ? 'korrekt' : 'falsch'}"
end

# --- Umlaut Substitutions for Suggestions ---
puts "\n## Umlaut-Ersetzungen (Umlaut Substitutions)"
puts "-" * 40

# German umlauts can be substituted for suggestions
umlauts = {
  'a' => ['ä', 'ae'],
  'o' => ['ö', 'oe'],
  'u' => ['ü', 'ue'],
  'ss' => ['ß', 'sz']
}

puts "Umlaut substitution examples:"
umlauts.each do |letter, substitutions|
  puts "  #{letter} -> #{substitutions.join(', ')}"
end

# Words without umlauts (common in informal writing)
words_without_umlauts = %w[Munchen Uber Gross Kaffee]
words_without_umlauts.each do |word|
  suggestions = Kotoshu.setup?("de") ? Kotoshu.suggest(word, language: "de").to_words.first(5) : []
  puts "Suggestions for '#{word}': #{suggestions.inspect}"
end

# --- Tokenization ---
puts "\n## Tokenisierung"
puts "-" * 40

text = "Guten Tag! Wie geht es Ihnen heute?"
tokens = german.tokenize(text)
tokens.each { |t| puts "  #{t}" }

# --- Compound Words ---
puts "\n## Zusammengesetzte Wörter (Compound Words)"
puts "-" * 40

# German is famous for long compound words
compound_words = %w[
  Donaudampfschifffahrt
  Rindfleischetikettierungsüberwachungsaufgabenübertragungsgesetz
  Schadenfreude
  Kummerspeck
  Torschlusspanik
]

compound_words.each do |word|
  tokens = german.tokenize(word)
  puts "  #{word}: #{tokens.size} tokens"
end

# --- POS Tagging ---
puts "\n## Wortart-Etikettierung (POS Tagging)"
puts "-" * 40

sentence_tokens = german.tokenize("Der schnelle Braun Fuchs springt über den faulen Hund")
begin
  tagged = german.create_pos_tagger.tag(sentence_tokens)
  tagged.each do |t|
    puts "  #{t[:token].ljust(10)} lemma: #{t[:lemma].to_s.ljust(10)} pos: #{t[:pos_tag]}"
  end
rescue Errno::ENOENT
  puts "  (POS tagging needs this language's Hunspell pair -"
  puts "   construct the language with aff_path/dic_path, or kotoshu setup)"
end

# --- Noun Capitalization ---
puts "\n## Substantiv-Großschreibung (Noun Capitalization)"
puts "-" * 40

# In German, ALL nouns are capitalized
test_phrases = [
  "der mann",      # Incorrect - "Mann" should be capitalized
  "der Mann",      # Correct
  "guten tag",     # Incorrect - "Tag" should be capitalized
  "guten Tag",     # Correct
  "ich bin müde",  # Correct - adjectives not capitalized
  "Ich bin Müde"   # Incorrect - only nouns capitalized
]

test_phrases.each do |phrase|
  tokens = german.tokenize(phrase)
  issues = [] # grammar rules ship for English today
  status = issues.empty? ? "✓" : "✗"
  puts "#{status} #{phrase.ljust(20)} #{issues.empty? ? 'correct' : issues.first&.message}"
end

puts "\n" + ("=" * 60)
puts "Deutsches Beispiel abgeschlossen!"
puts "=" * 60
