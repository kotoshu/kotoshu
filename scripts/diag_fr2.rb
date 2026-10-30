# frozen_string_literal: true

# Deep in-job diagnostic: tokenizer alignment + per-position argmax
# labels/confidences for the first probe sentence.
require "json"

model_dir = ARGV[0] || "/model"
input = ARGV[1] || "/code/data/fr_heldout_probe_sources.txt"

tagger = Kotoshu::Grammar::Tagger.from_dir(model_dir)
tok = tagger.tokenizer
words = File.readlines(input)[0].chomp.split
puts "words: #{words.size} #{words.first(8).inspect}"

ids = tok.encode_words(words)
align = tok.alignment(words)
puts "ids: #{ids.size}  align: #{align.size}"
puts "labels table size: #{tagger.labels.size}"
puts "labels sample: #{tagger.labels.first(3).inspect} key0: #{tagger.labels['0'].inspect}"

logits = tagger.model.predict({ "input_ids" => [ids],
                               "attention_mask" => [tok.mask_for(ids)] })["logits"][0]
puts "logits rows: #{logits.size}  cols: #{logits[0].size}"

align.each_with_index do |word_index, pos|
  next if word_index.nil? || pos > 12
  row = logits[pos]
  exps = row.map { |v| Math.exp(v - row.max) }
  sum = exps.sum
  best = row.each_with_index.max_by { |v, _| v }[1]
  conf = exps[best] / sum
  label = tagger.labels[best.to_s]
  puts "pos #{pos} word #{word_index} argmax_id #{best} label #{label.inspect} conf #{conf.round(4)}"
end
