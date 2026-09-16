#!/usr/bin/env ruby
# frozen_string_literal: true

# Diagnostic script to examine CEFR data in Kelly Excel files

require 'roo'
require 'roo-xls'

EXCEL_FILE = '/Users/mulgogi/src/external/ssharoff.github.io/kelly/en_m3.xls'
CEFR_LEVELS = %w[A1 A2 B1 B2 C1 C2].freeze

puts "CEFR Column Diagnostic"
puts "=" * 70

workbook = Roo::Spreadsheet.open(EXCEL_FILE)
sheet = workbook.sheet(workbook.sheets.first)

puts "\nExamining CEFR data (column 3) from rows 2-20:"
puts "-" * 70

(2..20).each do |row_num|
  row = sheet.row(row_num)
  word = row[1]
  cefr_raw = row[3]
  cefr_string = cefr_raw.to_s

  puts "Row #{row_num}: word='#{word}'"
  puts "  Raw type: #{cefr_raw.class}"
  puts "  Raw value: #{cefr_raw.inspect}"
  puts "  String value: #{cefr_string.inspect}"
  puts "  String bytes: #{cefr_string.bytes.join(' ')}"
  puts "  String codepoints: #{cefr_string.codepoints.map { |c| c.to_s(16) }.join(' ')}"

  # Test cleaning
  cleaned = cefr_string.gsub(/["]/, '').strip.upcase
  puts "  Cleaned: #{cleaned.inspect}"
  puts "  Valid CEFR: #{CEFR_LEVELS.include?(cleaned)}"
  puts
end

workbook.close
