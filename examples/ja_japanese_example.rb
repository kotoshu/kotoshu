#!/usr/bin/env ruby
# frozen_string_literal: true

# Japanese Language Example
# Demonstrates Japanese morphological analysis with Suika gem.

require 'bundler/setup'
require 'kotoshu'

# Japanese uses CJK scripts (Kanji, Hiragana, Katakana)
# Tokenization uses Suika morphological analyzer (built-in)

puts "=" * 60
puts "Kotoshu - Japanese Language Example"
puts "=" * 60

# Create Japanese language instance
japanese = Kotoshu::Languages::Japanese.new

# --- Tokenization (Morphological Analysis) ---
puts "\n## 形態素解析 (Morphological Analysis)"
puts "-" * 40

text = "すもももももももものうち"
puts "Text: #{text}"
puts "Meaning: 'The plum of the peach tree' (idiomatic expression)"

tokens = japanese.tokenize(text)
tokens.each { |t| puts "  #{t}" }

# --- More Complex Text ---
puts "\n## Complex Sentence Analysis"
puts "-" * 40

complex_text = "高輪ゲートウェイ駅は港区にあります"
puts "Text: #{complex_text}"
puts "Meaning: 'Takanawa Gateway Station is in Minato Ward'"

tokens = japanese.tokenize(complex_text)
tokens.each do |t|
  puts "  #{t}"
end

# --- POS Tags ---
puts "\n## 品詞タグ (POS Tags)"
puts "-" * 40

# Japanese has unique particle system
particle_examples = [
  "私が買う", # が marks subject
  "これを見る", # を marks object
  "駅に行く", # に marks direction
  "東京は見的地方", # は marks topic
  "友達の本", # の connects nouns
]

particle_examples.each do |example|
  tokens = japanese.tokenize(example)
  puts "\n  '#{example}':"
  tokens.each do |t|
    puts "    #{t}"
  end
end

# --- Proper Noun Detection ---
puts "\n## 固有名詞検出 (Proper Noun Detection)"
puts "-" * 40

proper_nouns = %w[東京 大阪 北海道 京都 日本]
proper_nouns.each do |noun|
  tokens = japanese.tokenize(noun)
  pos = tokens.first
  is_proper = pos == 'NOUN_PROPER_GEOGRAPHIC'
  puts "  #{noun.ljust(8)} #{pos.ljust(25)} #{'✓ geographic' if is_proper}"
end

# --- Dictionary-based Spell Checking ---
puts "\n## スペルチェック (Spell Checking)"
puts "-" * 40

# Note: Japanese spell checking is different - we check against dictionary
words = %w[東京 日本 漢字 ひらがな カタカナ]
words.each do |word|
  result = Kotoshu.setup?("ja") ? Kotoshu.correct?(word, language: "ja") : nil
  puts "  #{word.ljust(10)} #{result ? '✓ in dictionary' : '✗ not found'}"
end

# --- Script Mixing Detection ---
puts "\n##  Script Mixing (Kanji + Hiragana + Katakana)"
puts "-" * 40

mixed_script_texts = [
  "ローマ字", # Katakana + Kanji
  "日本語テスト", # Hiragana + Kanji
  "パーティー", # Katakana
  "日本語のテスト", # Mixed
]

mixed_script_texts.each do |text|
  tokens = japanese.tokenize(text)
  scripts = tokens.group_by { |t| t }
  puts "  #{text.ljust(15)} scripts: #{scripts.keys.join(', ')}"
end

# --- Verb Conjugation ---
puts "\n## 動詞の活用 (Verb Conjugation)"
puts "-" * 40

verbs = %w[買う 行く 来る 食べる 飲む]
verbs.each do |verb|
  # Check base form
  result = Kotoshu.setup?("ja") ? Kotoshu.correct?(verb, language: "ja") : nil
  puts "  #{verb.ljust(8)} #{result ? '✓ valid' : '?'}"
end

puts "\n" + ("=" * 60)
puts "日本語の例が完了しました!"
puts "=" * 60
