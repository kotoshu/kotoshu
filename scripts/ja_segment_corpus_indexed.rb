# frozen_string_literal: true

# Segment a ja sentence-per-line corpus, keeping input line numbers so two
# parallel sides (corrupted/corrected) can be re-joined by index even when
# the tagger skips short or empty lines.
# Usage: ruby scripts/ja_segment_corpus_indexed.rb IN.txt OUT.tsv
require "suika"

t = Suika::Tagger.new
File.open(ARGV[1], "w") do |out|
  File.foreach(ARGV[0]).each_with_index do |line, i|
    s = line.chomp
    next if s.empty?
    words = t.parse(s).map { |n| n.to_s.split("\t")[0] }
    next if words.size < 3
    out.puts "#{i}\t#{words.join(' ')}"
  end
end
warn "segmented #{ARGV[0]} -> #{ARGV[1]}"
