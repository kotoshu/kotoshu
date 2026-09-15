#!/usr/bin/env ruby
# frozen_string_literal: true

# Keyboard Layout Demo
#
# This example demonstrates the Kotoshu keyboard layout system,
# which provides language-aware keyboard layouts for spell checking.
#
# Run with: ruby examples/10_keyboard_layout_demo.rb

require_relative '../lib/kotoshu/keyboard'

puts "=" * 70
puts "Kotoshu Keyboard Layout System Demo"
puts "=" * 70
puts

# ========== LANGUAGE TO LAYOUT MAPPING ==========
puts "Language to Keyboard Layout Mapping"
puts "-" * 40
puts

%w[de en es fr pt ru].each do |lang|
  layout = Kotoshu::Keyboard.layout_for(lang)
  lang_name = case lang
             when 'de' then 'German (Deutsch)'
             when 'en' then 'English'
             when 'es' then 'Spanish (Español)'
             when 'fr' then 'French (Français)'
             when 'pt' then 'Portuguese (Português)'
             when 'ru' then 'Russian (Русский)'
             else lang.upcase
              end
  puts "  #{lang_name.ljust(25)} → #{layout.name}"
end
puts

# ========== KEYBOARD DISTANCE CALCULATIONS ==========
puts "Keyboard Distance Calculations"
puts "-" * 40
puts

puts "QWERTY Layout (English, Spanish, Portuguese):"
qwerty = Kotoshu::Keyboard.layout_by_name('QWERTY')
puts "  Distance 'q' to 'w': #{qwerty.distance('q', 'w')} (adjacent)"
puts "  Distance 'q' to 'p': #{qwerty.distance('q', 'p')} (far apart)"
puts "  Adjacent to 'q': #{qwerty.adjacent_keys('q').join(', ')}"
puts

puts "QWERTZ Layout (German):"
qwertz = Kotoshu::Keyboard.layout_by_name('QWERTZ')
puts "  Distance 'z' to 'y': #{qwertz.distance('z', 'y')} (swapped from QWERTY!)"
puts "  Distance 'ä' to 'ö': #{qwertz.distance('ä', 'ö')}"
puts "  Adjacent to 'z': #{qwertz.adjacent_keys('z').join(', ')}"
puts

puts "AZERTY Layout (French):"
azerty = Kotoshu::Keyboard.layout_by_name('AZERTY')
puts "  Distance 'a' to 'q': #{azerty.distance('a', 'q')} (swapped from QWERTY!)"
puts "  Distance 'z' to 'w': #{azerty.distance('z', 'w')} (swapped from QWERTY!)"
puts "  Adjacent to 'a': #{azerty.adjacent_keys('a').join(', ')}"
puts

puts "JCUKEN Layout (Russian):"
jcuken = Kotoshu::Keyboard.layout_by_name('JCUKEN')
puts "  Distance 'й' to 'ц': #{jcuken.distance('й', 'ц')} (Cyrillic J-C)"
puts "  Distance 'п' to 'р': #{jcuken.distance('п', 'р')} (home row)"
puts "  Adjacent to 'й': #{jcuken.adjacent_keys('й').join(', ')}"
puts

# ========== TYPO DETECTION EXAMPLES ==========
puts "Typo Detection Examples"
puts "-" * 40
puts

puts "English common typos (QWERTY):"
puts "  'teh' → 'the' (e adjacent to t, h adjacent to e)"
puts "  'adn' → 'and' (d adjacent to s, n adjacent to space)"
puts "  'helo' → 'hello' (missing double l)"
puts

puts "German common typos (QWERTZ):"
puts "  'z' instead of 'y' (swapped positions on QWERTZ)"
puts "  'ueber' → 'über' (missing umlaut)"
puts "  'Strasse' → 'Straße' (ss to ß)"
puts

puts "French common typos (AZERTY):"
puts "  'a' instead of 'q' (swapped positions on AZERTY)"
puts "  'cafe' → 'café' (missing accent)"
puts

# ========== ADJACENT KEY TYPO DEMONSTRATION ==========
puts "Adjacent Key Typo Detection"
puts "-" * 40
puts

puts "For QWERTY (English/Spanish/Portuguese):"
qwerty = Kotoshu::Keyboard.layout_for('en')
%w[q w a s z x].each do |key|
  adjacent = qwerty.adjacent_keys(key)
  puts "  Keys adjacent to '#{key}': #{adjacent.join(', ')}"
end
puts

puts "For QWERTZ (German):"
qwertz = Kotoshu::Keyboard.layout_for('de')
%w[z y a ä ö ü].each do |key|
  adjacent = qwertz.adjacent_keys(key)
  puts "  Keys adjacent to '#{key}': #{adjacent.join(', ')}"
end
puts

# ========== LANGUAGE-SPECIFIC KEY POSITIONS ==========
puts "Language-Specific Key Positions"
puts "-" * 40
puts

puts "German QWERTZ special keys:"
puts "  ä position: #{qwertz.position('ä').inspect}"
puts "  ö position: #{qwertz.position('ö').inspect}"
puts "  ü position: #{qwertz.position('ü').inspect}"
puts "  ß position: #{qwertz.position('ß').inspect}"
puts

puts "French AZERTY accent keys (positions):"
puts "  é position: #{azerty.position('é').inspect}"
puts "  è position: #{azerty.position('è').inspect}"
puts "  à position: #{azerty.position('à').inspect}"
puts

# ========== SPELL CHECKING INTEGRATION ==========
puts "Spell Checking Integration"
puts "-" * 40
puts

puts "The keyboard layout system integrates with EditDistanceStrategy to:"
puts "  1. Detect adjacent-key typos (common mistake)"
puts "  2. Penalize distant-key typos (unlikely mistake)"
puts "  3. Improve suggestion ranking with language-awareness"
puts
puts "Example (English QWERTY):"
puts "  Typo: 'teh' → Suggestion: 'the' (confidence: high)"
puts "    Reason: e is adjacent to t, h is adjacent to e"
puts
puts "Example (German QWERTZ):"
puts "  Typo: 'zah' → Suggestion: 'zahl' (confidence: high)"
puts "    Reason: a is adjacent to z on QWERTZ"
puts

puts "=" * 70
puts "Keyboard layout system demo complete!"
puts "=" * 70
