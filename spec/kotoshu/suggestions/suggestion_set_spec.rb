# frozen_string_literal: true

RSpec.describe Kotoshu::Suggestions::SuggestionSet do
  let(:suggestions) do
    [
      Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1, confidence: 0.9, source: :edit_distance),
      Kotoshu::Suggestions::Suggestion.new(word: "help",   distance: 2, confidence: 0.7, source: :ngram),
      Kotoshu::Suggestions::Suggestion.new(word: "hell",   distance: 1, confidence: 0.8, source: :edit_distance)
    ]
  end

  let(:set) { described_class.new(suggestions) }

  describe "#to_a consistency with #suggestions" do
    it "returns Array<Suggestion>, the same shape as #suggestions" do
      expect(set.to_a).to all(be_a(Kotoshu::Suggestions::Suggestion))
    end

    it "yields Suggestion objects to Enumerable methods" do
      words = set.map(&:word)
      expect(words).to eq(%w[hello hell help])
    end

    it "returns the same count as #suggestions" do
      expect(set.to_a.size).to eq(set.suggestions.size)
    end
  end

  describe "#to_hashes" do
    it "returns Array<Hash>" do
      expect(set.to_hashes).to all(be_a(Hash))
    end

    it "includes word, distance, confidence, source keys" do
      first = set.to_hashes.first
      expect(first.keys).to include("word", "distance", "confidence", "source")
    end
  end

  describe "#as_json" do
    it "delegates to #to_hashes (serialization shape)" do
      expect(set.as_json).to eq(set.to_hashes)
    end
  end

  describe "#to_words" do
    it "returns Array<String>" do
      expect(set.to_words).to all(be_a(String))
    end
  end
end
