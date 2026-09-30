# frozen_string_literal: true

# Error injector: generates synthetic grammar-training data from CLEAN
# public-domain English text (TODO.grammar/9, the local-model path).
#
# For each sentence, injects errors from classes that mirror the rule
# taxonomy (lib/kotoshu/grammar/rules/en), aligned at token level:
#   { clean, corrupted, edits: [{ src_idx, tgt_idx, src, tgt }] }
#
# The tagger then learns to predict exactly the corrections our rules
# describe — 100% our own data, nothing to attribute.
#
# Usage:
#   ruby scripts/error_injector.rb clean.txt out.jsonl [seed]

require "json"

class ErrorInjector
  SENTENCE_END = /(?<=[.!?])\s+/

  def initialize(seed: 42)
    @rng = Random.new(seed)
  end

  # Tokenize into word/punct tokens with indices (simple split keeps
  # alignment trivial: whitespace tokens, punctuation attached).
  def tokenize(line)
    line.split(/\s+/)
  end

  # Each class: [pattern, replacement, probability]
  CLASSES = {
    # agreement: 3sg -> base
    verb_3sg_to_base: [
      [%r{\A(goes|makes|takes|sees|comes|gets|gives|finds|tells|says|knows|writes|runs|puts|sets|walks|talks|works|plays|eats|drinks|reads|likes|needs|wants|looks|seems|helps|turns|starts|means|stays)\z}i,
       ->(w) { w.sub(/s\z/, "") }, 0.30]
    ],
    # was/were confusion
    was_were: [
      [/\Awas\z/i, ->(_) { "were" }, 0.10],
      [/\Awere\z/i, ->(_) { "was" }, 0.10]
    ],
    # of/have after a modal
    modal_of: [
      [/\A(have|has)\z/i, ->(_) { "of" }, 0.05]
    ],
    # capitalization: sentence-start lowered, I lowered
    capitalization: [
      [/\AI\z/, ->(_) { "i" }, 0.05]
    ],
    # article: a/an swap
    article_swap: [
      [/\Aa\z/i, ->(_) { "an" }, 0.03],
      [/\Aan\z/i, ->(_) { "a" }, 0.03]
    ],
    # determiner number
    this_these: [
      [/\Athis\z/i, ->(_) { "these" }, 0.03],
      [/\Athese\z/i, ->(_) { "this" }, 0.03]
    ],
    # spelling: double a consonant or drop one
    letter_tweak: [
      [/\A[a-z]{4,}\z/i, :letter_tweak, 0.02]
    ]
  }.freeze

  def letter_tweak(word)
    mid = word.length / 2
    c = word[mid]
    @rng.rand < 0.5 ? word.dup.insert(mid, c) : word.dup.delete_char_at(mid)
  end

  def delete_char_at(str, idx = nil)
    # String#delete_at does not exist; emulate via slicing.
    idx ||= str.length / 2
    str[0...idx] + str[idx + 1..]
  end

  # Inject errors into one sentence; returns nil when nothing changed.
  def inject(sentence)
    tokens = tokenize(sentence)
    corrupted = tokens.dup
    edits = []
    tokens.each_with_index do |tok, idx|
      CLASSES.each_value do |variants|
        next unless @rng.rand < 0.35

        variants.each do |(pattern, replacer, probability)|
          next unless tok.match?(pattern) && @rng.rand < probability

          # sentence-start capitalization class only
          if pattern == /\AI\z/ && idx.zero?
            corrupted[idx] = tok.downcase
            edits << { src_idx: idx, tgt_idx: idx, src: tok, tgt: corrupted[idx] }
            next
          end
          replacement = replacer.is_a?(Symbol) ? send(replacer, tok) : replacer.call(tok)
          next if replacement.nil? || replacement.empty?

          corrupted[idx] = replacement
          edits << { src_idx: idx, tgt_idx: idx, src: tok, tgt: replacement }
        end
      end
    end
    return nil if edits.empty?

    { "clean" => sentence, "corrupted" => corrupted.join(" "), "edits" => edits }
  end

  def run(io_in, io_out)
    produced = 0
    io_in.each_line do |line|
      sentence = line.strip
      next if sentence.empty? || sentence.split.length < 6

      pair = inject(sentence)
      next if pair.nil?

      io_out.puts JSON.generate(pair)
      produced += 1
    end
    produced
  end
end

if $PROGRAM_NAME == __FILE__
  input = ARGV[0]
  output = ARGV[1] or abort "usage: error_injector.rb CLEAN_TXT OUT_JSONL [SEED]"
  seed = (ARGV[2] || 42).to_i
  injector = ErrorInjector.new(seed: seed)
  if input == "-"
    count = injector.run($stdin, File.open(output, "w"))
  else
    count = injector.run(File.open(input), File.open(output, "w"))
  end
  warn "wrote #{count} corrupted/clean pairs to #{output}"
end
