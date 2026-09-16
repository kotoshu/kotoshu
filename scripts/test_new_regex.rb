#!/usr/bin/env ruby
# frozen_string_literal: true

# Test the new regex pattern

CEFR_LEVELS = %w[A1 A2 B1 B2 C1 C2].freeze

# The actual data has fancy quotes U+201C and U+201D
cefr_raw = '"A1"'
puts "Raw: '#{cefr_raw}'"
puts "Codepoints: #{cefr_raw.codepoints.map { |c| c.to_s(16) }.join(' ')}"

# Test the new regex pattern
cefr_clean = cefr_raw.gsub(/[""']/, '').strip.upcase
puts "Cleaned: '#{cefr_clean}'"
puts "Valid CEFR: #{CEFR_LEVELS.include?(cefr_clean)}"

# Test with regular quotes too
cefr_raw2 = '"A2"'
cefr_clean2 = cefr_raw2.gsub(/[""']/, '').strip.upcase
puts "\nWith regular quotes:"
puts "Raw: '#{cefr_raw2}'"
puts "Cleaned: '#{cefr_clean2}'"
puts "Valid CEFR: #{CEFR_LEVELS.include?(cefr_clean2)}"
