#!/usr/bin/env ruby
# frozen_string_literal: true

# English Language Example
# Demonstrates English spell checking, tokenization, and POS tagging.

require 'bundler/setup'
require 'kotoshu'

# English uses standard Latin script with Hunspell for spell checking.
# Dictionary path for en_US

puts "=" * 60
puts "Kotoshu - English Language Example"
puts "=" * 60

# Create English language instance
english = Kotoshu::Languages::English.new

# --- Spell Checking ---
puts "\n## Spell Checking"
puts "-" * 40

words_to_check = %w[hello world programming correctt spellingg]
words_to_check.each do |word|
  result = Kotoshu.setup?("en") ? Kotoshu.correct?(word, language: "en") : nil
  status = result ? "✓" : "✗"
  puts "#{status} #{word.ljust(15)} #{result ? 'correct' : 'incorrect'}"
end

# --- Suggestions ---
puts "\n## Suggestions"
puts "-" * 40

misspelled = %w[helo wrld programing]
misspelled.each do |word|
  suggestions = Kotoshu.setup?("en") ? Kotoshu.suggest(word, language: "en").to_words.first(5) : []
  puts "Did you mean: #{suggestions.inspect} (for '#{word}')"
end

# --- Tokenization ---
puts "\n## Tokenization"
puts "-" * 40

text = "The quick brown fox jumps over the lazy dog. It's a beautiful day!"
tokens = english.tokenize(text)
tokens.each do |t|
  puts "  #{t[:token].ljust(15)} pos: #{t[:pos_tag].inspect}"
end

# --- POS Tagging ---
puts "\n## POS Tagging"
puts "-" * 40

sentence_tokens = english.tokenize("Programming is fun and challenging")
tagged = english.create_pos_tagger.tag(sentence_tokens)
tagged.each do |t|
  puts "  #{t[:token].ljust(15)} lemma: #{t[:lemma].to_s.ljust(15)} pos: #{t[:pos_tag]}"
end

# --- Grammar Rules ---
puts "\n## Grammar Rules"
puts "-" * 40

# Test article usage (a vs an)
test_phrases = [
  "a apple",
  "a hour",
  "an apple",
  "an elephant",
  "a university",
  "an umbrella"
]

test_phrases.each do |phrase|
  tokens = english.tokenize(phrase)
  rules = english.create_grammar_rules
  issues = rules.check(tokens)
  if issues.empty?
    puts "✓ #{phrase.ljust(20)} no issues"
  else
    puts "✗ #{phrase.ljust(20)} #{issues.map { |i| i[:message] }.join(', ')}"
  end
end

puts "\n" + ("=" * 60)
puts "English example complete!"
puts "=" * 60
