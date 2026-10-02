# frozen_string_literal: true

# Head-to-head: kotoshu (rules / hybrid) vs LanguageTool CLI on the
# SAME injected dev sentences (TODO.grammar/5, frozen 2026-10-01:
# hybrid F0.5 0.827 vs LT 0.432, token-level, 2,392 sentences).
# Usage: bundle exec ruby -Ilib -rkotoshu scripts/grammar_headtohead.rb
require "json"

# Gold: corrupted sentences + word-index edits
gold = File.readlines("/tmp/gec_dev_cls.jsonl").map { |l| JSON.parse(l) }

# Word char-spans per line (whitespace split, matching the injector)
def word_spans(line)
  spans = []
  pos = 0
  line.split(/\s+/).each do |w|
    start = line.index(w, pos)
    spans << (start...(start + w.length))
    pos = start + w.length
  end
  spans
end

def f05(p, r)
  return 0.0 if p + r == 0

  (1.25 * p * r) / ((0.25 * p) + r)
end

# --- LanguageTool: file-level offsets -> per-line word indices
file_text = File.read("/tmp/dev_sentences.txt")
line_starts = []
pos = 0
file_text.each_line do |line|
  line_starts << pos
  pos += line.length
end
lt = JSON.parse(File.read("/tmp/lt_out.json"))
lt_flags = Array.new(gold.length) { [] }
lines = file_text.each_line.to_a
lt["matches"].each do |m|
  off = m["offset"]
  line_no = line_starts.rindex { |s| s <= off } || 0
  rel = off - line_starts[line_no]
  line = lines[line_no]
  spans = word_spans(line)
  spans.each_with_index do |span, wi|
    lt_flags[line_no] << wi if rel < span.end && (rel + (m["length"] || 1)) > span.begin
  end
end

# --- Kotoshu: rules-only and hybrid
plain = Kotoshu::Grammar::Checker.new(language: "en")
tagger = Kotoshu::Grammar::Tagger.from_dir("/tmp/gec-model-dir")
hybrid = Kotoshu::Grammar::Checker.new(language: "en", tagger: tagger)

results = { "lt" => { tp: 0, fp: 0, fn: 0 }, "rules" => { tp: 0, fp: 0, fn: 0 }, "hybrid" => { tp: 0, fp: 0, fn: 0 } }
gold.each_with_index do |row, i|
  words = row["corrupted"].split
  spans = word_spans(row["corrupted"])
  gold_idx = row["edits"].map { |e| e["src_idx"] }.compact
  flag_sets = {}
  flag_sets["lt"] = lt_flags[i].uniq
  koto_flags = lambda do |checker|
    checker.check(row["corrupted"]).filter_map do |e|
      wi = spans.index { |s| s.begin <= e[:start_offset] && e[:start_offset] < s.end }
      wi
    end.uniq
  end
  flag_sets["rules"] = koto_flags.call(plain)
  flag_sets["hybrid"] = koto_flags.call(hybrid)
  flag_sets.each do |tool, flags|
    flags.each { |f| gold_idx.include?(f) ? results[tool][:tp] += 1 : results[tool][:fp] += 1 }
    results[tool][:fn] += gold_idx.reject { |g| flags.include?(g) }.length
  end
end

puts "tool         TP     FP     FN     prec      rec     F0.5"
results.each do |tool, c|
  p = c[:tp].to_f / [c[:tp] + c[:fp], 1].max
  r = c[:tp].to_f / [c[:tp] + c[:fn], 1].max
  puts format("%-8s %6d %6d %6d %8.4f %8.4f %8.4f", tool, c[:tp], c[:fp], c[:fn], p, r, f05(p, r))
end
