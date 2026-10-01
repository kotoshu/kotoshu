# frozen_string_literal: true

require "spec_helper"
require "json"
require "kotoshu/grammar"

RSpec.describe Kotoshu::Grammar::ByteBpe do
  let(:vocab_path) { File.expand_path("/tmp/roberta_tok/vocab.json") }
  let(:merges_path) { File.expand_path("/tmp/roberta_tok/merges.txt") }
  let(:tokenizer) { described_class.new(vocab_path, merges_path) }
  let(:fixture) { JSON.parse(File.read(File.expand_path("../../fixtures/grammar/bpe_conformance.json", __dir__))) }

  before do
    skip "tokenizer files not downloaded" unless File.exist?(vocab_path)
  end

  it "replays the reference tokenizer exactly (word mode)" do
    mismatches = []
    fixture.each do |case_|
      next unless case_["words"]

      ids = tokenizer.encode_words(case_["words"])
      align = tokenizer.alignment(case_["words"])
      mismatches << case_["words"].join(" ") if ids != case_["input_ids"]
      mismatches << "align:#{case_['words'].join(' ')}" if align != case_["word_ids"]
    end
    expect(mismatches).to be_empty, mismatches.join("\n")
  end

  it "replays the reference tokenizer exactly (text mode)" do
    fixture.each do |case_|
      next unless case_["text"]

      expect(tokenizer.encode(case_["text"])).to eq(case_["input_ids"])
    end
  end

  it "frames with BOS/EOS and builds masks" do
    ids = tokenizer.encode_words(["Hello"])
    expect(ids.first).to eq(0)
    expect(ids.last).to eq(2)
    expect(tokenizer.mask_for(ids)).to all(eq(1))
  end
end
