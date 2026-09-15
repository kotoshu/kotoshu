#!/usr/bin/env ruby
# frozen_string_literal: true

# Russian Language Example
# Demonstrates Russian spell checking with Cyrillic script.

require 'bundler/setup'
require 'kotoshu'

# Russian uses Cyrillic script with unique character set
# Dictionary path for Russian

puts "=" * 60
puts "Kotoshu - Russian Language Example"
puts "=" * 60

# Create Russian language instance
russian = Kotoshu::Languages::Russian.new

# --- Spell Checking ---
puts "\n## Проверка орфографии (Spell Checking)"
puts "-" * 40

words_to_check = %w[привет мир программирование Россия]
words_to_check.each do |word|
  result = Kotoshu.setup?("ru") ? Kotoshu.correct?(word, language: "ru") : nil
  status = result ? "✓" : "✗"
  puts "#{status} #{word.ljust(20)} #{result ? 'правильно' : 'неправильно'}"
end

# --- Cyrillic Character Substitutions ---
puts "\n## Замены символов (Character Substitutions)"
puts "-" * 40

# Cyrillic has look-alike characters that can be substituted
cyrillic_substitutions = {
  'а' => ['о', 'е', 'я'],  # Common confusions
  'п' => ['н', 'т'],       # п/н confusion
  'с' => ['з', 'ш'],       # с/з/ш confusion
  'о' => ['а', 'е'],       # о/а/е confusion
  'е' => ['ё', 'э', 'о'],  # е/ё/э/о confusion
}

puts "Common Cyrillic character substitutions:"
cyrillic_substitutions.each do |char, subs|
  puts "  #{char} -> #{subs.join(', ')}"
end

# --- Typos with Similar Characters ---
puts "\n## Типичные опечатки (Common Typos)"
puts "-" * 40

typos = %w[привет прывет мир мпр мир] # Intentional typos
typos.each do |typo|
  next if Kotoshu.setup?("ru") ? Kotoshu.correct?(typo, language: "ru") : nil # Skip correct words

  suggestions = Kotoshu.setup?("ru") ? Kotoshu.suggest(typo, language: "ru").to_words.first(5) : []
  puts "  '#{typo}' -> suggestions: #{suggestions.inspect}"
end

# --- Tokenization ---
puts "\n## Токенизация (Tokenization)"
puts "-" * 40

text = "Привет, мир! Как дела сегодня?"
tokens = russian.tokenize(text)
tokens.each { |t| puts "  #{t}" }

# --- POS Tagging ---
puts "\n## Части речи (POS Tagging)"
puts "-" * 40

sentence_tokens = russian.tokenize("Кошка ест рыбу")
begin
  tagged = russian.create_pos_tagger.tag(sentence_tokens)
  tagged.each do |t|
    puts "  #{t[:token].ljust(10)} lemma: #{t[:lemma].to_s.ljust(10)} pos: #{t[:pos_tag]}"
  end
rescue StandardError
  puts "  (POS tagging needs the Russian Hunspell pair - construct"
  puts "   Russian.new with aff_path/dic_path, or use kotoshu setup ru)"
end

# --- Grammar Cases ---
puts "\n## Падежи (Grammar Cases)"
puts "-" * 40

# Russian has 6 cases with different endings
case_examples = {
  "кот" => "nominative (subject)",
  "кота" => "accusative (direct object)",
  "коту" => "dative (indirect object)",
  "кота" => "genitive (possession)",
  "котом" => "instrumental (with/by)",
  "о коте" => "prepositional (about)",
}

case_examples.each do |word, description|
  result = Kotoshu.setup?("ru") ? Kotoshu.correct?(word, language: "ru") : nil
  puts "  #{word.ljust(10)} #{description}"
end

# --- Transliteration ---
puts "\n## Транслитерация (Transliteration)"
puts "-" * 40

# Russian is often transliterated to Latin for international use
transliteration_examples = {
  "привет" => "privet (hello)",
  " мир" => "mir (world)",
  "спасибо" => "spasibo (thank you)",
  "до свидания" => "do svidaniya (goodbye)",
}

puts "Common transliterations:"
transliteration_examples.each do |cyrillic, latin|
  puts "  #{cyrillic.ljust(15)} -> #{latin}"
end

puts "\n" + ("=" * 60)
puts "Русский пример завершён!"
puts "=" * 60
