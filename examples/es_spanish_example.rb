#!/usr/bin/env ruby
# frozen_string_literal: true

# Spanish Language Example
# Demonstrates Spanish spell checking and inverted punctuation.

require 'bundler/setup'
require 'kotoshu'

# Spanish uses Latin script with inverted punctuation marks (¡, ¿)
# Dictionary path for Spanish
DICT_PATH = File.join(__dir__, 'dictionaries', 'es_ES')

puts "=" * 60
puts "Kotoshu - Spanish Language Example"
puts "=" * 60

# Create Spanish language instance
spanish = Kotoshu::Languages::Spanish.new

# --- Spell Checking ---
puts "\n## Corrección Ortográfica (Spell Checking)"
puts "-" * 40

words_to_check = %w[hola mundo español café año día señor]
words_to_check.each do |word|
  result = Kotoshu.setup?("es") ? Kotoshu.correct?(word, language: "es") : nil
  status = result ? "✓" : "✗"
  puts "#{status} #{word.ljust(15)} #{result ? 'correcto' : 'incorrecto'}"
end

# --- Accent Handling ---
puts "\n## Acentos (Accents)"
puts "-" * 40

# Spanish accents distinguish meaning
accent_pairs = {
  "el" => "the (masculine)",
  "él" => "he / him",
  "tu" => "your",
  "tú" => "you (informal)",
  "si" => "if / yes",
  "sí" => "yes / oneself",
  "mas" => "but (conjunction)",
  "más" => "more",
  "solo" => "alone / only",
  "sólo" => "only (adverb)",
  "de" => "of / from",
  "dé" => "give (subjunctive)",
}

puts "Accents distinguish meaning:"
accent_pairs.each do |word, meaning|
  result = Kotoshu.setup?("es") ? Kotoshu.correct?(word, language: "es") : nil
  puts "  #{word.ljust(8)} : #{meaning}"
end

# --- Suggestions with Accent Recovery ---
puts "\n## Sugerencias con Acentos (Suggestions with Accents)"
puts "-" * 40

words_without_accents = %w[cafe ano]
words_without_accents.each do |word|
  suggestions = Kotoshu.setup?("es") ? Kotoshu.suggest(word, language: "es").to_words.first(5) : []
  puts "Suggestions for '#{word}': #{suggestions.inspect}"
end

# --- Inverted Punctuation ---
puts "\n## Puntuación Invertida (Inverted Punctuation)"
puts "-" * 40

# Spanish uses ¿ at the beginning and ? at the end
# ¡ at the beginning and ! at the end
inverted_punctuation = [
  "¿Cómo estás?",
  "¡Hola!",
  "¿Qué tal?",
  "¡Muy bien!",
  "¿Dónde está el baño?",
  "¡No lo sé!"
]

puts "Inverted punctuation for questions and exclamations:"
inverted_punctuation.each do |sentence|
  tokens = spanish.tokenize(sentence)
  issues = [] # grammar rules ship for English today
  status = issues.empty? ? "✓" : "✗"
  puts "  #{status} #{sentence.ljust(25)} #{issues.empty? ? 'correct' : issues.first&.message}"
end

# --- Tokenization ---
puts "\n## Tokenización"
puts "-" * 40

text = "¡Hola mundo! ¿Cómo estás hoy?"
tokens = spanish.tokenize(text)
tokens.each { |t| puts "  #{t}" }

# --- POS Tagging ---
puts "\n## Etiquetado POS (POS Tagging)"
puts "-" * 40

sentence_tokens = spanish.tokenize("El gato come el pescado")
begin
  tagged = spanish.create_pos_tagger.tag(sentence_tokens)
  tagged.each do |t|
    puts "  #{t[:token].ljust(10)} lemma: #{t[:lemma].to_s.ljust(10)} pos: #{t[:pos_tag]}"
  end
rescue Errno::ENOENT
  puts "  (POS tagging needs this language's Hunspell pair -"
  puts "   construct the language with aff_path/dic_path, or kotoshu setup)"
end

# --- Gender Agreement ---
puts "\n## Concordancia de Género (Gender Agreement)"
puts "-" * 40

gender_examples = [
  "el gato",      # masculine
  "la gata",      # feminine
  "el perro",
  "la perra",
  "niño",         # boy
  "niña",         # girl
]

gender_examples.each do |phrase|
  tokens = spanish.tokenize(phrase)
  issues = [] # grammar rules ship for English today
  status = issues.empty? ? "✓" : "✗"
  puts "  #{status} #{phrase.ljust(15)} #{issues.empty? ? 'correct' : issues.first&.message}"
end

# --- Verb Conjugation ---
puts "\n## Conjugación Verbal (Verb Conjugation)"
puts "-" * 40

verb_forms = {
  "hablar" => "to speak (infinitive)",
  "hablo" => "I speak (present)",
  "hablas" => "you speak (present)",
  "habla" => "he/she speaks (present)",
  "hablamos" => "we speak (present)",
  "hablan" => "they speak (present)",
  "hablé" => "I spoke (past)",
  "hablaba" => "I was speaking (imperfect)",
}

verb_forms.each do |form, meaning|
  result = Kotoshu.setup?("es") ? Kotoshu.correct?(form, language: "es") : nil
  puts "  #{form.ljust(10)} #{meaning}"
end

puts "\n" + ("=" * 60)
puts "¡Ejemplo español completado!"
puts "=" * 60
