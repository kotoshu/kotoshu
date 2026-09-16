#!/usr/bin/env ruby
# frozen_string_literal: true

# Test fancy quote removal

CEFR_LEVELS = %w[A1 A2 B1 B2 C1 C2].freeze

cefr_raw = '"A1"'
puts "Raw: '#{cefr_raw}'"
puts "Cleaned: '#{cefr_raw.gsub(/['\"]/, '').strip.upcase}'"
puts "Is valid: #{CEFR_LEVELS.include?(cefr_raw.gsub(/['\"]/, '').strip.upcase)}"
