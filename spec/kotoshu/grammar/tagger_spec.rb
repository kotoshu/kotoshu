# frozen_string_literal: true

require "spec_helper"
require "kotoshu/grammar"

RSpec.describe Kotoshu::Grammar::Tagger do
  describe "deterministic fix generation (CI-safe, no model)" do
    fixes = {
      "$AGREEMENT_WAS_WERE" => { "was" => ["were"], "were" => ["was"], "Was" => ["were"] },
      "$AGREEMENT_MODAL_OF" => { "of" => ["have"], "OF" => ["have"] },
      "$CAPITALIZATION" => { "i" => ["I"], "london" => ["London"] },
      "$ARTICLE" => { "a" => ["an"], "an" => ["a"] },
      "$DETERMINER_NUMBER" => { "this" => ["these"], "these" => ["this"] },
      "$AGREEMENT_3SG" => { "need" => %w[needs need], "go" => %w[goes go], "try" => %w[tries try] }
    }
    fixes.each do |label, cases_|
      it "generates fixes for #{label}" do
        tagger = described_class.allocate
        cases_.each do |word, expected|
          expect(tagger.fix_for(label, word)).to eq(expected)
        end
      end
    end

    it "capitalizes without losing the rest of the word" do
      tagger = described_class.allocate
      expect(tagger.fix_for("$CAPITALIZATION", "paris")).to eq(["Paris"])
    end
  end

  describe "message_for" do
    it "maps classes to messages" do
      tagger = described_class.allocate
      expect(tagger.message_for("$AGREEMENT_WAS_WERE")).to eq("was/were agreement")
      expect(tagger.message_for("$UNKNOWN_CLASS")).to eq("Grammar")
    end
  end
end

RSpec.describe Kotoshu::Grammar::Morphology do
  it "inflects and uninflects 3sg forms" do
    expect(described_class.inflect_3sg("need")).to eq("needs")
    expect(described_class.inflect_3sg("go")).to eq("goes")
    expect(described_class.inflect_3sg("try")).to eq("tries")
    expect(described_class.inflect_3sg("have")).to eq("has")
    expect(described_class.uninflect_3sg("needs")).to eq("need")
    expect(described_class.uninflect_3sg("goes")).to eq("go")
  end
end

RSpec.describe "hybrid grammar checking (ONNX-gated)", :onnx do
  let(:model_dir) { ENV.fetch("KOTOSHU_GRAMMAR_TAGGER_DIR", "/tmp/gec-model-dir") }
  let(:tagger) { Kotoshu::Grammar::Tagger.from_dir(model_dir) }
  let(:hybrid) { Kotoshu::Grammar::Checker.new(language: "en", tagger: tagger) }
  let(:plain) { Kotoshu::Grammar::Checker.new(language: "en") }

  before do
    skip "tagger model dir not present" unless File.directory?(model_dir)
    skip "onnxruntime not installed" unless Kotoshu::Models::OnnxModel::ONNX_LOADED
  rescue NameError
    skip "models not loaded"
  end

  it "detects what the rules structurally miss (non-pronoun subject)" do
    errors = hybrid.check("The machine need a new part.")
    neural = errors.select { |e| e[:type] == "neural" }
    expect(neural).to be_any
    expect(neural.first[:rule_id]).to eq("$AGREEMENT_3SG")
    expect(neural.first[:suggestions]).to include("needs")
  end

  it "detects compound-subject agreement the rules miss" do
    errors = hybrid.check("My brother and my sister was there.")
    neural = errors.select { |e| e[:type] == "neural" }
    expect(neural.map { |e| e[:rule_id] }).to include("$AGREEMENT_WAS_WERE")
    expect(neural.flat_map { |e| e[:suggestions] }).to include("were")
  end

  it "defers to rules where they already fire" do
    text = "They was late for the meeting."
    errors = hybrid.check(text)
    expect(errors.map { |e| e[:rule_id] }).to include("EN_WAS_PLURAL")
    expect(errors.select { |e| e[:type] == "neural" }).to be_empty
  end

  it "stays silent on clean text" do
    expect(hybrid.check("The quick brown fox jumps over the lazy dog.")).to be_empty
  end

  it "byte-BPE tokenization matches the reference fixture" do
    fixture = JSON.parse(File.read(File.expand_path("../../fixtures/grammar/bpe_conformance.json", __dir__)))
    tokenizer = Kotoshu::Grammar::ByteBpe.new(
      File.join(model_dir, "vocab.json"), File.join(model_dir, "merges.txt")
    )
    fixture.each do |case_|
      next unless case_["words"]

      expect(tokenizer.encode_words(case_["words"])).to eq(case_["input_ids"])
    end
  end
end
