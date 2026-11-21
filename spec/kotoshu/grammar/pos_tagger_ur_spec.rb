# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Grammar::UrPosTagger do
  let(:tagger) { described_class.new }

  it "tags the stable closed classes without a lexicon" do
    toks = tagger.tag("وہ نہیں ہے")
    expect(toks.map { |t| t[:pos] }).to eq(%w[PRP NEG AUXT])
  end

  it "splits urdu punctuation into its own tokens" do
    toks = tagger.tag("اللہ نے پاکستان کو ۔")
    expect(toks.last[:pos]).to eq("PU")
    expect(toks.map { |t| t[:word] }).to include("کو")
  end

  it "answers UNKNOWN for open-class words pre-lexicon" do
    toks = tagger.tag("پاکستان")
    expect(toks.first[:pos]).to eq(:UNKNOWN)
  end

  it "compiles the purchased corpus into the lexicon" do
    tagger.compile_lexicon([["پاکستان", "NNP"], ["کتابیں", "NN"], ["گھر", "XYZ"]])
    expect(tagger.lexicon["پاکستان"]).to eq("NNP")
    expect(tagger.lexicon["کتابیں"]).to eq("NN")
    expect(tagger.lexicon).not_to have_key("گھر")
    expect(tagger.tag("پاکستان").first[:pos]).to eq("NNP")
  end

  it "maps CLE tags onto the reduced vocabulary for the rule engine" do
    toks = tagger.tag_reduced("وہ نہیں ہے ۔")
    expect(toks.map { |t| t[:reduced] }).to eq(%i[PRON NEG AUX PUNCT])
  end
end
