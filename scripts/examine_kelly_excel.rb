#!/usr/bin/env ruby
# frozen_string_literal: true

# Test script to examine Kelly Excel file structure
# Usage: ruby scripts/examine_kelly_excel.rb

require 'roo'
require 'roo-xls' # Explicitly require for XLS support

EXCEL_FILE = '/Users/mulgogi/src/external/ssharoff.github.io/kelly/en_m3.xls'

puts "Examining: #{EXCEL_FILE}"
puts "=" * 70

workbook = Roo::Spreadsheet.open(EXCEL_FILE)
puts "Class: #{workbook.class}"
puts "Sheets: #{workbook.sheets.join(', ')}"
puts

sheet = workbook.sheet(workbook.sheets.first)
puts "First sheet: #{workbook.sheets.first}"
puts "Dimensions: #{sheet.last_row} rows x #{sheet.last_column} columns"
puts

# Examine first 10 rows
puts "First 10 rows:"
puts "-" * 70

(1..[10, sheet.last_row].min).each do |row_num|
  row = sheet.row(row_num)
  puts "Row #{row_num}: #{row.map { |c| c.to_s.strip[0..30] }.join(' | ')}"
end

puts
puts "Sample words (rows 2-6):"
puts "-" * 70

(2..6).each do |row_num|
  row = sheet.row(row_num)
  word = row[0]
  rest = row[1..-1] || []
  puts "  #{word.to_s.ljust(30)} | #{rest.map { |c| c.to_s }.join(' | ')}"
end

workbook.close
