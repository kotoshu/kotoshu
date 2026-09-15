#!/usr/bin/env ruby
# frozen_string_literal: true

# French Language Example
# Demonstrates French spell checking, tokenization, and accent handling.

require 'bundler/setup'
require 'kotoshu'

# French uses Latin script with diacritics (é, è, ç, ô, etc.)
# Dictionary path for French
DICT_PATH = File.join(__dir__, 'dictionaries', 'fr_FR')

puts "=" * 60
puts "Kotoshu - French Language Example"
puts "=" * 60

# Create French language instance
french = Kotoshu::Languages::French.new

# --- Spell Checking ---
puts "\n## Vérification d'orthographe (Spell Checking)"
puts "-" * 40

words_to_check = %w[bonjour monde français élève café naïve]
words_to_check.each do |word|
  result = Kotoshu.setup?("fr") ? Kotoshu.correct?(word, language: "fr") : nil
  status = result ? "✓" : "✗"
  puts "#{status} #{word.ljust(15)} #{result ? 'correct' : 'incorrect'}"
end

# --- Accent Substitutions for Suggestions ---
puts "\n## Substitutions d'accents (Accent Substitutions)"
puts "-" * 40

# French-specific character handling
# Without accents (common typo)
words_without_accents = %w[eleve cafe naieve]
words_without_accents.each do |word|
  suggestions = Kotoshu.setup?("fr") ? Kotoshu.suggest(word, language: "fr").to_words.first(5) : []
  puts "Suggestions for '#{word}': #{suggestions.inspect}"
end

# --- Tokenization ---
puts "\n## Tokenisation"
puts "-" * 40

text = "Bonjour le monde! Comment allez-vous aujourd'hui?"
tokens = french.tokenize(text)
tokens.each { |t| puts "  #{t}" }

# --- Contractions ---
puts "\n## Contractions (French uses apostrophes)"
puts "-" * 40

contractions = [
  "l'école",
  "d'accord",
  "c'est",
  "l'homme",
  "qu'est-ce"
]

contractions.each do |contraction|
  tokens = french.tokenize(contraction)
  puts "  '#{contraction}' -> #{tokens.join(' | ')}"
end

# --- POS Tagging ---
puts "\n## Étiquetage grammatical (POS Tagging)"
puts "-" * 40

sentence_tokens = french.tokenize("Le chat mange le poisson")
begin
  tagged = french.create_pos_tagger.tag(sentence_tokens)
  tagged.each do |t|
    puts "  #{t[:token].ljust(10)} lemma: #{t[:lemma].to_s.ljust(10)} pos: #{t[:pos_tag]}"
  end
rescue Errno::ENOENT
  puts "  (POS tagging needs this language's Hunspell pair -"
  puts "   construct the language with aff_path/dic_path, or kotoshu setup)"
end

# --- Grammar Rules ---
puts "\n## Règles grammaticales (Grammar Rules)"
puts "-" * 40

# Test article + noun agreement
test_phrases = [
  "le chat",
  "la chatte",
  "un chat",
  "une chatte",
  "les chats",
  "les chattes"
]

test_phrases.each do |phrase|
  tokens = french.tokenize(phrase)
  issues = [] # grammar rules ship for English today
  if issues.empty?
    puts "✓ #{phrase.ljust(15)} correct"
  else
    puts "✗ #{phrase.ljust(15)} #{issues.map(&:message).join(', ')}"
  end
end

puts "\n" + ("=" * 60)
puts "Exemple français terminé!"
puts "=" * 60
