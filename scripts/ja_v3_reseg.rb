#!/usr/bin/env ruby
# frozen_string_literal: true

# Re-segment the ja_v3 pack + teacher exacts with suika (the serving
# segmenter). The pack was segmented by ja_segment_corpus.rb whose token
# granularity differs from suika's — the ja-v11 model trained on those
# tokens copy-throughs at eval (train/decode tokenization mismatch,
# 2026-11-17 gate 0.0039). This job: join tokens -> raw string -> suika
# parse -> space-joined token stream.
#
# Inputs  (kotoshu/gec-training-private):
#   teacher/ja_v3/ja_v3_pairs_all.jsonl   71,812 pairs (class/clean/corrupted/src)
#   teacher/ja_v3/ds_out.jsonl            70,995 teacher rows (11,954 exact)
# Outputs (same repo):
#   corpora/ja_v3_reseg_pairs.jsonl       re-segmented pairs
#   corpora/ja_v3_reseg_exact.jsonl       re-segmented teacher exact rows

require "json"
require "open-uri"
require "cgi"
require "fileutils"

REPO = "kotoshu/gec-training-private"
TOKEN = ENV.fetch("HF_TOKEN")

def fetch(path)
  url = "https://huggingface.co/datasets/#{REPO}/resolve/main/#{path}"
  out = "/tmp/#{File.basename(path)}"
  unless File.exist?(out)
    puts "downloading #{path}"
    File.binwrite(out, URI.open(url, "Authorization" => "Bearer #{TOKEN}").read)
  end
  out
end

def upload(path, remote)
  cmd = "python3 -c \"from huggingface_hub import HfApi;" \
        "HfApi().upload_file(path_or_fileobj='#{path}', path_in_repo='#{remote}'," \
        "repo_type='dataset', repo_id='#{REPO}', commit_message='#{remote}')\""
  system(cmd) || abort("upload failed: #{remote}")
  puts "uploaded #{remote}"
end

require "suika"
t = Suika::Tagger.new

reseg = ->(text) { t.parse(text).map { |n| n.to_s.split("\t")[0] }.join(" ") }

pairs_in = fetch("teacher/ja_v3/ja_v3_pairs_all.jsonl")
pairs_out = "/tmp/ja_v3_reseg_pairs.jsonl"
n = 0
File.open(pairs_out, "w") do |f|
  File.foreach(pairs_in) do |l|
    next if l.strip.empty?
    r = JSON.parse(l)
    # pack rows are space-joined token streams -> raw string -> suika
    raw = r["corrupted"].split.join
    clean_raw = r["clean"].split.join
    f.write(JSON.generate({ "corrupted" => reseg.call(raw),
                            "clean" => reseg.call(clean_raw),
                            "class" => r["class"],
                            "src" => r["src"] }) + "\n")
    n += 1
    puts "pairs #{n}" if (n % 10_000).zero?
  end
end
puts "pairs re-segmented: #{n}"
upload(pairs_out, "corpora/ja_v3_reseg_pairs.jsonl")

state_in = fetch("teacher/ja_v3/ds_out.jsonl")
exact_out = "/tmp/ja_v3_reseg_exact.jsonl"
n = e = 0
File.open(exact_out, "w") do |f|
  File.foreach(state_in) do |l|
    next if l.strip.empty?
    r = JSON.parse(l)
    e += 1
    next unless r["status"] == "exact"
    raw = r["corrupted"].split.join
    clean_raw = r["clean"].split.join
    f.write(JSON.generate({ "corrupted" => reseg.call(raw),
                            "clean" => reseg.call(clean_raw),
                            "cls" => r["cls"] }) + "\n")
    n += 1
  end
end
puts "teacher exact re-segmented: #{n}/#{e}"
upload(exact_out, "corpora/ja_v3_reseg_exact.jsonl")
puts "RESEG-DONE"
