# frozen_string_literal: true

# En nonword frozen-split bench: run the shipped suggest pipeline over
# eval/realword/en.suggest2-nonword.json and emit the top-5 slate per
# pair. Scoring (top-1/3/5 hit rate) happens in the caller.
#
# Usage: ruby -Ilib -rkotoshu eval/nonword_bench.rb SPLIT.json OUT.json
require "kotoshu"
require "json"

split_path, out_path = ARGV
abort "usage: nonword_bench.rb SPLIT.json OUT.json" unless split_path && out_path

split = JSON.parse(File.read(split_path))
slates = split["pairs"].map do |p|
  sugg = Kotoshu.suggest(p["typo"], language: :en) || []
  { "typo" => p["typo"], "correction" => p["correction"],
    "class" => p["class"], "top5" => sugg.top(5).map(&:word) }
end
File.write(out_path, JSON.pretty_generate(slates))
warn "slates: #{slates.size} -> #{out_path}"
