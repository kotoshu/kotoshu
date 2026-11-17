# frozen_string_literal: true

# Local eval decode with language-appropriate pre-tokenization:
# zh slices are raw text; the model was trained on segmented tokens,
# so the ZhSegmenter pre-pass precedes the tagger (the eval-job decodes
# fed raw zh and measured noise). ko/others decode directly.
#
# Usage: ruby -Ilib -rkotoshu scripts/eval_decode_local.rb MODEL_DIR IN.txt OUT.txt SEG.zh DICT.txt
#        (SEG.zh triggers the segmenter pre-pass; omit for whitespace langs)
require "kotoshu"

model_dir, input, output, seg_flag, dict = ARGV
abort "usage: eval_decode_local.rb MODEL IN OUT [SEG.zh DICT]" unless model_dir && input && output

tagger = Kotoshu::Grammar::Tagger.from_dir(model_dir)
margin = ENV["MARGIN"] && !ENV["MARGIN"].empty? ? ENV["MARGIN"].to_f : nil
decoder = Kotoshu::Grammar::GectorDecoder.new(tagger: tagger, rounds: 4,
                                              min_confidence: (ENV["MIN_CONFIDENCE"] || "0").to_f,
                                              margin: margin)
seg = if seg_flag == "SEG.zh"
        require "kotoshu/grammar/zh_segmenter"
        Kotoshu::Grammar::ZhSegmenter.new(dict)
      elsif seg_flag == "SEG.ja"
        require "suika"
        t = Suika::Tagger.new
        ->(s) { t.parse(s).map { |n| n.to_s.split("\t")[0] } }
      end

File.open(output, "w") do |out|
  File.foreach(input) do |line|
    s = line.chomp
    toks = s.empty? ? [] : (seg ? (seg.respond_to?(:segment) ? seg.segment(s) : seg.call(s)) : s.split)
    next out.puts if toks.empty?
    res = decoder.correct(toks)
    out.puts res[:corrected].join(" ")
    out.flush
  end
end
warn "decoded #{input} -> #{output}"
