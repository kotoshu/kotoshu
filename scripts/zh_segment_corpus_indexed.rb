# frozen_string_literal: true

# Segment a zh sentence-per-line corpus, keeping input line numbers so two
# parallel sides (corrupted/clean) can be re-joined by index even when the
# segmenter skips short or empty lines. Position-zipping the raw outputs
# desynchronizes every pair after the first skip (the zh_gector_seg
# poisoning incident).
# Usage: ruby -Ilib -rkotoshu scripts/zh_segment_corpus_indexed.rb DICT IN.tsv OUT.tsv
require "kotoshu"

dict, input, output = ARGV
abort "usage: zh_segment_corpus_indexed.rb DICT IN OUT" unless output

seg = Kotoshu::Grammar::ZhSegmenter.new(dict)
File.open(output, "w") do |out|
  File.foreach(input).each_with_index do |line, i|
    s = line.chomp
    next if s.empty?
    words = seg.segment(s)
    next if words.size < 3
    out.puts "#{i}\t#{words.join(' ')}"
  end
end
warn "segmented #{input} -> #{output}"
