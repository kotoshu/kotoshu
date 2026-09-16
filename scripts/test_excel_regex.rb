#!/usr/bin/env ruby
# frozen_string_literal: true

require 'roo'
require 'roo-xls'

EXCEL_FILE = '/Users/mulgogi/src/external/ssharoff.github.io/kelly/en_m3.xls'
CEFR_LEVELS = %w[A1 A2 B1 B2 C1 C2].freeze

workbook = Roo::Spreadsheet.open(EXCEL_FILE)
sheet = workbook.sheet(workbook.sheets.first)

# Get first data row
row = sheet.row(2)
cefr_raw = row[3].to_s.strip

puts "Raw CEFR: #{cefr_raw.inspect}"
puts "Codepoints: #{cefr_raw.codepoints.map { |c| c.to_s(16) }.join(' ')}"

# Test new regex
cefr_clean = cefr_raw.gsub(/["']/, '').strip.upcase
puts "Cleaned: #{cefr_clean.inspect}"
puts "Valid CEFR: #{CEFR_LEVELS.include?(cefr_clean)}"

# Test a few more rows
puts "\nTesting rows 2-10:"
(2..10).each do |i|
  row = sheet.row(i)
  word = row[1]
  cefr_raw = row[3].to_s.strip
  cefr_clean = cefr_raw.gsub(/["']/, '').strip.upcase
  is_valid = CEFR_LEVELS.include?(cefr_clean)
  puts "  #{word.ljust(15)} CEFR: #{cefr_raw.ljust(10)} -> #{cefr_clean.ljust(3)} valid: #{is_valid}"
end

workbook.close
