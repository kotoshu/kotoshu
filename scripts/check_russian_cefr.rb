#!/usr/bin/env ruby
# frozen_string_literal: true

require 'roo'
require 'roo-xls'

EXCEL_FILE = '/Users/mulgogi/src/external/ssharoff.github.io/kelly/ru_m3.xls'

workbook = Roo::Spreadsheet.open(EXCEL_FILE)
sheet = workbook.sheet(workbook.sheets.first)

puts "Russian Excel File Structure"
puts "=" * 70
puts "Dimensions: #{sheet.last_row} rows x #{sheet.last_column} columns"
puts

puts "First 5 rows:"
puts "-" * 70
(1..5).each do |i|
  row = sheet.row(i)
  puts "Row #{i}: #{row.map { |c| c.to_s[0..30] }.join(' | ')}"
end

puts
puts "Column 3 (CEFR) for rows 2-20:"
puts "-" * 70
(2..20).each do |i|
  row = sheet.row(i)
  word = row[1]
  cefr = row[3]
  puts "Row #{i}: #{word.ljust(20)} CEFR: #{cefr.inspect}"
end

workbook.close
