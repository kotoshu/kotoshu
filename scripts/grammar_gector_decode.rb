# frozen_string_literal: true

# Decode a sentence-per-line file with the GECToR tagger (iterative),
# producing corrected sentences for official M2 scoring.
#
# Usage: bundle exec ruby -Ilib -rkotoshu scripts/grammar_gector_decode.rb MODEL_DIR IN.txt OUT.txt

require "json"

model_dir = ARGV[0]
input = ARGV[1]
output = ARGV[2]
abort "usage: gector_decode MODEL_DIR IN OUT" unless model_dir && input && output

tagger = Kotoshu::Grammar::Tagger.from_dir(model_dir)
decoder = Kotoshu::Grammar::GectorDecoder.new(tagger: tagger, rounds: 2)

File.open(output, "w") do |out|
  File.foreach(input) do |line|
    out.puts decoder.correct(line.chomp.split)[:corrected].join(" ")
    out.flush
  end
end
warn "decoded #{File.readlines(input).length} sentences -> #{output}"
