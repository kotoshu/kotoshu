#!/usr/bin/env ruby
# frozen_string_literal: true

# Portuguese Language Example
# Demonstrates Portuguese spell checking and accent handling.

require 'bundler/setup'
require 'kotoshu'

# Portuguese uses Latin script with diacritics (á, é, í, ó, ú, ç, â, ê, ô)
# Brazilian Portuguese (pt_BR) and European Portuguese (pt_PT) differ

puts "=" * 60
puts "Kotoshu - Portuguese Language Example"
puts "=" * 60

# Create Portuguese language instance (Brazilian by default)
portuguese = Kotoshu::Languages::Portuguese.new

# --- Spell Checking ---
puts "\n## Verificação Ortográfica (Spell Checking)"
puts "-" * 40

words_to_check = %w[Olá mundo português coraçãoaçãoçãobrasil]
words_to_check.each do |word|
  result = Kotoshu.setup?("pt") ? Kotoshu.correct?(word, language: "pt") : nil
  status = result ? "✓" : "✗"
  puts "#{status} #{word.ljust(15)} #{result ? 'correto' : 'incorreto'}"
end

# --- Accent Handling ---
puts "\n## Acentos (Accents)"
puts "-" * 40

# Portuguese has multiple types of accents
accent_examples = {
  'á' => 'stressed a (fado)',
  'é' => 'stressed e (café)',
  'í' => 'stressed i (ímã)',
  'ó' => 'stressed o (avó)',
  'ú' => 'stressed u (único)',
  'ç' => 'cedilla (ação)',
  'â' => 'circumflex (você)',
  'ê' => 'circumflex (sênior)',
  'ô' => 'circumflex (vôo)',
  'ã' => 'nasal a (maçã)',
  'õ' => 'nasal o (coração)',
}

accent_examples.each do |accent, description|
  puts "  #{accent} : #{description}"
end

# --- Suggestions with Accent Recovery ---
puts "\n## Sugestões com Acentos (Suggestions with Accents)"
puts "-" * 40

words_without_accents = %w[cafe coracao faco]
words_without_accents.each do |word|
  suggestions = Kotoshu.setup?("pt") ? Kotoshu.suggest(word, language: "pt").to_words.first(5) : []
  puts "Suggestions for '#{word}': #{suggestions.inspect}"
end

# --- Tokenization ---
puts "\n## Tokenização"
puts "-" * 40

text = "Olá mundo! Como você está hoje?"
tokens = portuguese.tokenize(text)
tokens.each { |t| puts "  #{t}" }

# --- Contractions ---
puts "\n## Contrações (Contractions)"
puts "-" * 40

# Portuguese has many contractions with articles/prepositions
contractions = [
  "do (de + o)",
  "da (de + a)",
  "no (em + o)",
  "na (em + a)",
  "pelo (por + o)",
  "pela (por + a)",
  "dele (de + ele)",
  "dela (de + ela)"
]

contractions.each do |contraction|
  puts "  #{contraction}"
end

# --- Crase Detection (Preposition + Article) ---
puts "\n## Crase (à vs a)"
puts "-" * 40

# Crase is a uniquely Portuguese phenomenon
crase_examples = [
  ["vou a", "a + city (no article)"],
  ["vou à", "a + the (feminine article)"],
  ["falar a ela", "preposition 'to' her"],
  ["ir a Lua", "to the Moon (celestial body, no article)"],
  ["ir à Lua", "to the Moon (as location, with article)"]
]

puts "(Per-language grammar rules ship for English today; the Portuguese"
puts " module provides tokenization, POS tagging, and spelling.)"
crase_examples.each do |phrase, description|
  puts "  #{phrase.ljust(15)} - #{description}"
end

# --- POS Tagging ---
puts "\n## Marcação POS (POS Tagging)"
puts "-" * 40

sentence_tokens = portuguese.tokenize("O gato comeu o peixe")
begin
  tagged = portuguese.create_pos_tagger.tag(sentence_tokens)
  tagged.each do |t|
    puts "  #{t[:token].ljust(10)} lemma: #{t[:lemma].to_s.ljust(10)} pos: #{t[:pos_tag]}"
  end
rescue Errno::ENOENT
  puts "  (POS tagging needs the Portuguese Hunspell pair - construct"
  puts "   Portuguese.new with aff_path/dic_path, or use kotoshu setup pt)"
end

puts "\n" + ("=" * 60)
puts "Exemplo português concluído!"
puts "=" * 60
