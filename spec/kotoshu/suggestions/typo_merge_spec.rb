# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Suggestions::TypoMerge do
  def suggestion(word, confidence, source)
    Kotoshu::Suggestions::Suggestion.new(
      word: word, distance: 0, confidence: confidence, source: source
    )
  end

  def set(rows, limit: 10)
    Kotoshu::Suggestions::SuggestionSet.new(rows.map { |r| suggestion(*r) }, max_size: limit)
  end

  it "places the typo slate ahead of the base suggestions" do
    base = set([["hello", 0.9, :edit_distance], ["help", 0.5, :ngram]])
    typo = set([["held", 0.7, :typo_retrieval]])
    merged = described_class.call(base: base, typo: typo, limit: 10)
    expect(merged.map(&:word)).to eq(%w[held hello help])
  end

  it "drops base duplicates of typo rows" do
    base = set([["hello", 0.9, :edit_distance], ["help", 0.5, :ngram]])
    typo = set([["hello", 0.8, :typo_retrieval]])
    merged = described_class.call(base: base, typo: typo, limit: 10)
    expect(merged.map(&:word)).to eq(%w[hello help])
    expect(merged.first.source).to eq("typo_retrieval")
  end

  it "caps at the limit" do
    base = set([%w[b1 0.5 ngram], %w[b2 0.5 ngram], %w[b3 0.5 ngram]])
    typo = set([%w[t1 0.8 typo_retrieval], %w[t2 0.7 typo_retrieval]])
    merged = described_class.call(base: base, typo: typo, limit: 3)
    expect(merged.map(&:word)).to eq(%w[t1 t2 b1])
  end

  it "passes the base set through when the slate is empty" do
    base = set([%w[hello 0.9 edit_distance]])
    empty = Kotoshu::Suggestions::SuggestionSet.empty
    merged = described_class.call(base: base, typo: empty, limit: 10)
    expect(merged.map(&:word)).to eq(%w[hello])
  end
end
