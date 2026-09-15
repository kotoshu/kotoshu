#!/usr/bin/env ruby
# frozen_string_literal: true

# Port of Spylls examples/lookup.py to Ruby
#
# This example demonstrates advanced lookup features including
# good_forms (valid word forms) and affix_forms (affix variants).

require_relative "../lib/kotoshu"

# Create a Hunspell dictionary from en_US files
examples_dir = File.expand_path(__dir__)
dictionary = Kotoshu::Dictionary::Hunspell.new(
  dic_path: File.join(examples_dir, "en_US.dic"),
  aff_path: File.join(examples_dir, "en_US.aff"),
  language_code: "en-US"
)

# Get all valid forms of a word using affix rules
# good_forms returns all forms that exist in the dictionary
def good_forms(dict, word)
  forms = Set.new
  forms.add(word) if dict.lookup(word)

  # Generate affix variants
  variants = dict.word_variants(word)
  variants.each do |variant|
    forms.add(variant) if dict.lookup(variant)
  end

  forms.to_a
end

# Get all affix forms of a word
# This generates all possible forms with affixes applied
def affix_forms(dict, word)
  dict.word_variants(word)
end

# Examples
puts good_forms(dictionary, "building").inspect
puts good_forms(dictionary, "111th").inspect

# Show affix forms for "reboots"
puts affix_forms(dictionary, "reboots").inspect
