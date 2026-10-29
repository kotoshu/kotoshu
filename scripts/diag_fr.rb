# frozen_string_literal: true

# In-job diagnostic: decode the first probe sentences and dump the raw
# argmax label distribution + applied findings, to isolate x86 int8
# inference behavior vs local arm64.
require "json"

model_dir = ARGV[0] || "/model"
input = ARGV[1] || "/code/data/fr_heldout_probe_sources.txt"

tagger = Kotoshu::Grammar::Tagger.from_dir(model_dir)
decoder = Kotoshu::Grammar::GectorDecoder.new(tagger: tagger, rounds: 1, min_confidence: 0.0)

File.readlines(input).first(3).each do |src|
  res = decoder.correct(src.chomp.split)
  puts "SRC: #{src.strip[0, 50]}"
  puts "OUT: #{res[:corrected].join(' ')[0, 50]}"
  puts "EDIT: #{res[:applied].map { |f| "#{f[:label]}@#{f[:index]}(#{f[:confidence]})" }.first(5).join(' ')}"
  puts "---"
end
