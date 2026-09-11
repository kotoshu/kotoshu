# frozen_string_literal: true

# Generates lib/kotoshu/data/frozen_kelly.rb from the Rust engine's
# frozen tier tables (kotoshu-rs kotoshu/src/suggest/frequency_data.rs)
# so both engines carry byte-identical frequency data for `en`
# (plan 119). The rs tables are themselves frozen from the Kelly
# en.json sha256 97535823f41aa3f0… — this script preserves that
# provenance rather than re-deriving from the raw Kelly data.
#
# Usage: ruby scripts/generate_frozen_tiers.rb <path-to-frequency_data.rs>
#
# The generator is deterministic: same input file, same output bytes.

require "json"

SRC = ARGV[0]
abort "usage: #{$PROGRAM_NAME} <kotoshu-rs frequency_data.rs>" unless SRC
abort "not found: #{SRC}" unless File.exist?(SRC)

def parse_tier(source, name)
  match = source.match(/pub const #{name}: &\[&str\] = &\[(.*?)\];/m)
  abort "tier #{name} not found in #{SRC}" unless match

  match[1].scan(/"([^"]+)"/).flatten
end

source = File.read(SRC)
tiers = { "top_50" => parse_tier(source, "TOP_50"),
          "top_200" => parse_tier(source, "TOP_200"),
          "top_1000" => parse_tier(source, "TOP_1000") }
abort "unparsed" if tiers.values.any?(&:empty?)

data = {
  "provenance" => {
    "source" => "kotoshu-rs kotoshu/src/suggest/frequency_data.rs",
    "upstream" => "kotoshu/frequency-list-kelly data/en.json",
    "upstream_sha256" => "97535823f41aa3f06c2087dfc162aec0a591412b8b95c0594fcbb2cea79b0e61"
  },
  "tiers" => tiers.transform_keys(&:downcase)
}

dest = File.expand_path("../lib/kotoshu/data/frozen_kelly/en.json", __dir__)
File.write(dest, JSON.pretty_generate(data) + "\n")
puts "wrote #{dest}: #{tiers.map { |k, v| "#{k}=#{v.size}" }.join(' ')}"
