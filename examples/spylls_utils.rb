#!/usr/bin/env ruby
# frozen_string_literal: true

# Port of Spylls examples/utils.rb to Ruby
#
# This example demonstrates capitalization utilities for different
# language-specific casing rules (Regular, Turkic, German).

require_relative "../lib/kotoshu"

# Simple capitalization utilities
# Note: Kotoshu doesn't have full capitalization utilities yet,
# so this is a simplified implementation

module Capitalization
  # Regular capitalization (English-style)
  class RegularCasing
    def guess(word)
      # Guess the capitalization type: :upper, :lower, :title, :mixed
      return :upper if word.upcase == word
      return :lower if word.downcase == word
      return :title if word[0].upcase == word[0] && word[1..].downcase == word[1..]

      :mixed
    end

    def lower(word)
      word.downcase
    end

    def upper(word)
      word.upcase
    end
  end

  # Turkic capitalization (handles dotted/dotless i)
  class TurkicCasing
    def lower(word)
      # Turkic lowercase: I -> ı, İ -> i
      word.tr("Iİ", "ıi")
    end

    def upper(word)
      # Turkic uppercase: i -> İ, ı -> I
      word.tr("iı", "İI")
    end
  end

  # German capitalization (handles sharp s -> SS)
  class GermanCasing
    def lower(word)
      # German lowercase: ß stays ß (in modern German)
      word.downcase
    end

    def upper(word)
      # German uppercase: ß -> SS
      word.downcase.tr("ß", "ss").upcase
    end
  end
end

# Examples with regular casing
regular = Capitalization::RegularCasing.new
puts "Regular casing guess for 'Paris': #{regular.guess('Paris')}"
puts "Regular lower: #{regular.lower('Izmir')}"
puts "Regular upper: #{regular.upper('Izmir')}"

# Examples with Turkic casing
turkic = Capitalization::TurkicCasing.new
puts "Turkic lower: #{turkic.lower('Izmir')}"
puts "Turkic upper: #{turkic.upper('Izmir')}"

# Examples with German casing
german = Capitalization::GermanCasing.new
puts "German lower: #{german.lower('STRASSE')}"
