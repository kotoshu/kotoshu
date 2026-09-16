#!/usr/bin/env ruby
# frozen_string_literal: true

# Test fancy quote removal for Kelly CEFR data

CEFR_LEVELS = %w[A1 A2 B1 B2 C1 C2].freeze

# The actual data from Kelly Excel has fancy quotes
cefr_raw = '"A1"'
puts "Raw: '#{cefr_raw}'"
puts "Code points: #{cefr_raw.codepoints.map { |c| c.to_s(16) }.join(', ')}"

# Try different methods
puts "\nMethod 1 (gsub /[\"]):"
cleaned = cefr_raw.gsub(/[\"]/, '').strip.upcase
puts "  Result: '#{cleaned}'"
puts "  Valid: #{CEFR_LEVELS.include?(cleaned)}"

puts "\nMethod 2 (encode UTF-8):"
cleaned2 = cefr_raw.encode('UTF-8').gsub(/["]/, '').strip.upcase
puts "  Result: '#{cleaned2}'"
puts "  Valid: #{CEFR_LEVELS.include?(cleaned2)}"

puts "\nMethod 3 (include both quote types):"
cleaned3 = cefr_raw.gsub(/["']|\"/, '').strip.upcase
puts "  Result: '#{cleaned3}'"
puts "  Valid: #{CEFR_LEVELS.include?(cleaned3)}"
