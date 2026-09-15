#!/usr/bin/env ruby
# frozen_string_literal: true

# Port of Spylls examples/unmunch.py to Ruby
#
# "Unmunching" (Hunspell's term) is the process of turning an
# affix-compressed dictionary into a plain list of all language's words.
#
# For example, in the dictionary we have "spell/JSMDRZG" (stem + flags
# declaring what suffixes and prefixes it might have), and we can run
# this script to produce:
#   spell
#   spell's
#   spelled
#   speller
#   spellers
#   spelling
#   spellings
#   spells
#
# Usage:
#   ruby spylls_unmunch.rb --dictionary=en_US --word=spell
#
# Running without --word will unmunch the entire dictionary.
#
# WARNINGS:
# 1. The script is not extensively tested, just a demo
# 2. It doesn't try to produce all possible words for compounding,
#    because the list is potentially infinite.

require "optparse"
require "set"
require_relative "../lib/kotoshu"

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby spylls_unmunch.rb [options]"

  opts.on("-d", "--dictionary DICTIONARY", "Dictionary path to unmunch (<path>.aff and <path>.dic should be present)") do |d|
    options[:dictionary] = d
  end

  opts.on("-w", "--word WORD", "Singular word to unmunch (if absent, unmunch the whole dictionary)") do |w|
    options[:word] = w
  end

  opts.on("-i", "--immediate", "Output unmunch for each word immediately (more memory-effective, but not sorted and might contain duplicates)") do |i|
    options[:immediate] = i
  end
end.parse!

# Default dictionary path
options[:dictionary] ||= File.join(File.expand_path(__dir__), "en_US")

# Resolve dictionary paths
dic_path = if options[:dictionary].end_with?(".dic")
             options[:dictionary]
           else
             "#{options[:dictionary]}.dic"
           end

aff_path = dic_path.sub(".dic", ".aff")

# Parse affix file directly (workaround for parse_affix_rules bug)
def parse_affix_file(aff_path)
  affix_rules = {
    prefix: Hash.new { |h, k| h[k] = [] },
    suffix: Hash.new { |h, k| h[k] = [] }
  }

  current_flag = nil
  current_type = nil
  current_cross_product = false

  File.foreach(aff_path) do |line|
    line = line.strip
    next if line.empty? || line.start_with?("#")

    parts = line.split
    next unless parts.length >= 4

    type = parts[0]

    case type
    when "PFX", "SFX"
      flag = parts[1]

      # Check if this is a header line (has 4 parts and parts[2] is Y/N and parts[3] is a number)
      if parts.length == 4 && ["Y", "N"].include?(parts[2]) && parts[3].match?(/^\d+$/)
        # Header line - start new rule group
        current_flag = flag
        current_type = type
        current_cross_product = parts[2] == "Y"
      elsif parts.length >= 5 && current_flag
        # Rule line: format is TYPE FLAG STRIP ADD CONDITION
        # parts[2] = strip, parts[3] = add, parts[4] = condition
        strip = parts[2] == "0" ? "" : parts[2]
        add = parts[3]
        condition = parts[4] || "."

        type_sym = current_type == "PFX" ? :prefix : :suffix

        affix_rules[type_sym][current_flag] << {
          strip: strip,
          add: add,
          condition: condition,
          cross_product: current_cross_product
        }
      end
    end
  end

  affix_rules
end

# Parse the affix file directly
affix_rules = parse_affix_file(aff_path)

# Load the dictionary file to get word index
word_index = {}
File.foreach(dic_path).each_with_index do |line, idx|
  next if idx == 0 # Skip first line (word count)

  line = line.strip
  next if line.empty? || line.start_with?("#")

  # Parse "word/flags" format
  parts = line.split("/")
  word = parts[0]
  flags = parts[1] ? parts[1].chars : []

  word_index[word] = flags
end

# Compile condition string to regex (simplified version)
def compile_condition(condition, type)
  return // if condition == "."

  regex_str = condition.dup

  # Handle character classes
  # Keep [...] and [^...] as-is (they are valid in Ruby regex)
  # Only need to handle special cases like "." (match any)

  # For simple conditions without special characters, use as-is
  pattern = if regex_str !~ /[\[\]\.\^\$\*\+\?\(\)\{\}\|\\]/
              # Simple string match
              regex_str
            else
              # Complex pattern - use as-is but handle special cases
              regex_str
            end

  # Anchor to end for suffix, beginning for prefix
  if type == :suffix
    Regexp.new("#{pattern}$")
  else
    Regexp.new("^#{pattern}")
  end
end

# Check if a condition matches a word
def condition_matches?(condition_str, word, type)
  condition = compile_condition(condition_str, type)
  word.match?(condition)
end

# Unmunch function: generate all word forms from a stem with flags
def unmunch(stem, flags, affix_rules)
  result = Set.new
  result.add(stem) # Always include the stem

  # Get applicable suffixes and prefixes from flags
  suffixes = []
  prefixes = []

  flags.each do |flag|
    # Add suffixes for this flag
    if affix_rules[:suffix][flag]
      affix_rules[:suffix][flag].each do |rule|
        # Check if condition matches the stem
        if condition_matches?(rule[:condition], stem, :suffix)
          suffixes << rule
        end
      end
    end

    # Add prefixes for this flag
    if affix_rules[:prefix][flag]
      affix_rules[:prefix][flag].each do |rule|
        # Check if condition matches the stem
        if condition_matches?(rule[:condition], stem, :prefix)
          prefixes << rule
        end
      end
    end
  end

  # Apply suffixes
  suffixes.each do |rule|
    # Strip from end, add suffix
    root = rule[:strip].empty? ? stem : stem[0...-rule[:strip].length]
    suffixed = root + rule[:add]
    result.add(suffixed)
  end

  # Apply prefixes
  prefixes.each do |rule|
    # Strip from beginning, add prefix
    root = rule[:strip].empty? ? stem : stem[rule[:strip].length..]
    prefixed = rule[:add] + root
    result.add(prefixed)

    # Apply cross-product rules (prefix + suffix combinations)
    if rule[:cross_product]
      suffixes.each do |suffix_rule|
        # Apply suffix after prefix
        root2 = suffix_rule[:strip].empty? ? prefixed : prefixed[0...-suffix_rule[:strip].length]
        combo = root2 + suffix_rule[:add]
        result.add(combo)
      end
    end
  end

  result
end

result = Set.new

if options[:word]
  lookup = options[:word]
  puts "Unmunching only words with stem #{lookup}"
else
  lookup = nil
  puts "Unmunching the whole dictionary"
end

puts ""

# Process each word in the dictionary
word_index.each do |stem, flags|
  next if lookup && stem != lookup

  if lookup
    puts "Unmunching #{stem} with flags #{flags.inspect}"
  end

  if options[:immediate]
    unmunch(stem, flags, affix_rules).sort.each { |word| puts word }
  else
    result.merge(unmunch(stem, flags, affix_rules))
  end
end

puts ""

# Output results (sorted)
unless options[:immediate]
  result.sort.each { |word| puts word }
end
