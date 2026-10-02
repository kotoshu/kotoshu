# frozen_string_literal: true

# Dump per-token predictions with softmax confidences for threshold
# tuning (GECToR tunes one threshold per label on dev; this produces
# the raw material). Single pass over each line's words — thresholds
# transfer to the iterative decoder.
#
# Usage: bundle exec ruby -Ilib -rkotoshu scripts/grammar_conf_dump.rb MODEL_DIR IN.txt OUT.jsonl

require "json"

model_dir = ARGV[0]
input = ARGV[1]
output = ARGV[2]
abort "usage: grammar_conf_dump MODEL_DIR IN OUT" unless model_dir && input && output

tagger = Kotoshu::Grammar::Tagger.from_dir(model_dir)
tokenizer = tagger.tokenizer
labels = tagger.labels

File.open(output, "w") do |out|
  File.foreach(input) do |line|
    words = line.chomp.split
    next if words.empty?

    ids = tokenizer.encode_words(words)
    align = tokenizer.alignment(words)
    logits = tagger.model.predict({
                                    "input_ids" => [ids],
                                    "attention_mask" => [tokenizer.mask_for(ids)]
                                  })["logits"][0]
    per_word = {}
    align.each_with_index do |word_index, pos|
      next if word_index.nil? || per_word.key?(word_index)

      row = logits[pos]
      exps = row.map { |v| Math.exp(v - row.max) }
      sum = exps.sum
      best = row.each_with_index.max_by { |v, _| v }[1]
      per_word[word_index] = [best, exps[best] / sum]
    end
    preds = per_word.filter_map do |index, (label_id, conf)|
      label = labels[label_id.to_s]
      next if label.nil? || label == "$KEEP"

      { i: index, label: label, conf: conf.round(4) }
    end
    out.puts JSON.generate({ words: words, preds: preds })
    out.flush
  end
end
warn "dumped #{File.readlines(input).length} lines -> #{output}"
