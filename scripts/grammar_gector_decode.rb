# frozen_string_literal: true

# Decode a sentence-per-line file with the GECToR tagger (iterative),
# producing corrected sentences for official M2 scoring.
#
# Usage: bundle exec ruby -Ilib -rkotoshu scripts/grammar_gector_decode.rb \
#          MODEL_DIR IN.txt OUT.txt [THRESHOLDS.json]
#
# THRESHOLDS.json (optional) carries dev-tuned per-label confidence
# floors (scripts/tune_thresholds.py output).

require "json"

model_dir = ARGV[0]
input = ARGV[1]
output = ARGV[2]
thresholds_path = ARGV[3]
abort "usage: gector_decode MODEL_DIR IN OUT [THRESHOLDS.json]" unless model_dir && input && output

label_thresholds = {}
label_thresholds = JSON.parse(File.read(thresholds_path))["thresholds"] if thresholds_path

rounds = (ENV["ROUNDS"] || "2").to_i
# Without dev-tuned per-label thresholds, a 0.0 floor lets every non-KEEP
# prediction fire; 0.5 is the GECToR-reasonable global floor.
min_confidence = ENV.fetch("MIN_CONFIDENCE", "0.5").to_f
tagger = Kotoshu::Grammar::Tagger.from_dir(model_dir)
decoder = Kotoshu::Grammar::GectorDecoder.new(tagger: tagger, rounds: rounds,
                                              min_confidence: min_confidence,
                                              label_thresholds: label_thresholds)

File.open(output, "w") do |out|
  File.foreach(input) do |line|
    out.puts decoder.correct(line.chomp.split)[:corrected].join(" ")
    out.flush
  end
end
warn "decoded #{File.readlines(input).length} sentences -> #{output}"
