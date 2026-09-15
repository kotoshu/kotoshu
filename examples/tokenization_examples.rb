#!/usr/bin/env ruby
# frozen_string_literal: true

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "kotoshu"
require "kotoshu/language"

puts "=" * 80
puts "Kotoshu Language Tokenization Examples"
puts "Demonstrating LanguageTool-ported tokenizers for 7 languages"
puts "=" * 80
puts

# ============================================================================
# 1. ENGLISH (en) - Contractions, Hyphens, Apostrophes
# ============================================================================
puts "1. ENGLISH - Contractions, Hyphens, Apostrophes"
puts "-" * 80

en = Kotoshu::Language.get("en").instance
examples_en = {
  "Contractions" => "I'm don't think we've won't",
  "Hyphens" => "state-of-the-art technology and well-known authors",
  "Apostrophes" => "John's book and Mary's car",
  "Mixed" => "I can't believe it's not butter! It's a margarine product."
}

examples_en.each do |desc, text|
  tokens = en.tokenize(text)
  puts "#{desc}:"
  puts "  Text:   #{text}"
  puts "  Tokens: #{tokens.inspect}"
  puts
end

# ============================================================================
# 2. GERMAN (de) - Underscore, Single Low Quote, Umlauts
# ============================================================================
puts "2. GERMAN - Underscore, Single Low Quote, Umlauts"
puts "-" * 80

de = Kotoshu::Language.get("de").instance
examples_de = {
  "Umlauts" => "Grüße aus Österreich",
  "Special chars" => "Der Preis beträgt 500€ für 5 Stück",
  "Mixed" => "Müller's café in Köln bietet Frühstück an"
}

examples_de.each do |desc, text|
  tokens = de.tokenize(text)
  puts "#{desc}:"
  puts "  Text:   #{text}"
  puts "  Tokens: #{tokens.inspect}"
  puts
end

# ============================================================================
# 3. FRENCH (fr) - Apostrophes, Contractions, Hyphenated Words
# ============================================================================
puts "3. FRENCH - Apostrophes, Contractions (c'est, d', qu')"
puts "-" * 80

fr = Kotoshu::Language.get("fr").instance
examples_fr = {
  "Simple contractions" => "J'ai vu l'homme et la femme",
  "c'est-à-dire" => "C'est-à-dire, je ne sais pas",
  "rendez-vous" => "Rendez-vous chez-eux à 5 heures",
  "Mixed" => "Qu'est-ce que tu penses de l'histoire d'amour?"
}

examples_fr.each do |desc, text|
  tokens = fr.tokenize(text)
  puts "#{desc}:"
  puts "  Text:   #{text}"
  puts "  Tokens: #{tokens.inspect}"
  puts
end

# ============================================================================
# 4. SPANISH (es) - Decimals, Ordinals, Inverted Punctuation
# ============================================================================
puts "4. SPANISH - Decimals (3,14), Ordinals (1.º), Inverted Punctuation"
puts "-" * 80

es = Kotoshu::Language.get("es").instance
examples_es = {
  "Decimals" => "El valor es 3,14 y 12,5 metros cuadrados",
  "Ordinals" => "El 1.er y 2.º lugar fueron para España",
  "Inverted punctuation" => "¿Cómo estás? ¡Muy bien!",
  "Mixed" => "El niño dice que sars-cov-2 es un virus peligroso"
}

examples_es.each do |desc, text|
  tokens = es.tokenize(text)
  puts "#{desc}:"
  puts "  Text:   #{text}"
  puts "  Tokens: #{tokens.inspect}"
  puts
end

# ============================================================================
# 5. PORTUGUESE (pt) - Decimals, Dates, Time, Spaced Numbers
# ============================================================================
puts "5. PORTUGUESE - Decimals, Dates (01.01.2024), Time (12:25)"
puts "-" * 80

pt = Kotoshu::Language.get("pt").instance
examples_pt = {
  "Decimals" => "O preço é R$ 3,50 por quilo",
  "Dates" => "A data é 01.01.2024 e o evento será em 2024-12-25",
  "Time" => "O comboio às 12:30 e o jantar às 20:15",
  "Spaced decimals" => "O orçamento é de 2 000 000 de reais",
  "Mixed" => "Vou ao anti-vírus al-qaïda com mcgraw-hill"
}

examples_pt.each do |desc, text|
  tokens = pt.tokenize(text)
  puts "#{desc}:"
  puts "  Text:   #{text}"
  puts "  Tokens: #{tokens.inspect}"
  puts
end

# ============================================================================
# 6. RUSSIAN (ru) - Apostrophe, Special Abbreviations (б/у)
# ============================================================================
puts "6. RUSSIAN - Apostrophe, Special Abbreviations (б/у - second-hand)"
puts "-" * 80

ru = Kotoshu::Language.get("ru").instance
examples_ru = {
  "Abbreviations" => "Купить б/у компьютер дешевле",
  "Mixed" => "Привет! Как дела, б/н товар?"
}

examples_ru.each do |desc, text|
  tokens = ru.tokenize(text)
  puts "#{desc}:"
  puts "  Text:   #{text}"
  puts "  Tokens: #{tokens.inspect}"
  puts
end

# ============================================================================
# 7. JAPANESE (ja) - Suika Morphological Analysis
# ============================================================================
puts "7. JAPANESE - Suika Morphological Analysis"
puts "-" * 80

ja = Kotoshu::Language.get("ja").instance
examples_ja = {
  "Mixed script" => "私は東京に行きます。",
  "Katakana (foreign words)" => "コンピューターを使っています",
  "Kanji + Hiragana" => "日本語を勉強します",
  "Suika output" => "すももももももものうち"
}

examples_ja.each do |desc, text|
  tokens = ja.tokenize(text)
  puts "#{desc}:"
  puts "  Text:   #{text}"
  puts "  Tokens: #{tokens.inspect}"
  puts
end

puts "=" * 80
puts "Tokenization Examples Complete!"
puts "=" * 80
puts
puts "Language-Specific Features Demonstrated:"
puts "  English:  Contractions (I'm, don't), hyphens (state-of-the-art)"
puts "  German:  Underscore, single low quote (‚), umlauts (ä, ö, ü, ß)"
puts "  French:  7 contraction patterns (c'est, d', qu', jusqu'à)"
puts "  Spanish:  Decimal commas (3,14), ordinals (1.º), inverted punctuation (¿, ¡)"
puts "  Portuguese:  Dates (01.01.2024), time (12:25), spaced decimals (2 000 000)"
puts "  Russian:  Special abbreviations (б/у, б/н)"
puts "  Japanese:  Suika morphological analysis (proper word segmentation)"
puts
puts "All tokenizers ported from LanguageTool Java implementations."
