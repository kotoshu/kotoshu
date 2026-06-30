# frozen_string_literal: true

require "kotoshu"

# Result-model consistency audit (TODO.impl/56 T5.3).
#
# WordResult / DocumentResult are lutaml-model Serializables; the
# Suggestion class is also a lutaml-model Serializable. SuggestionSet
# is a plain Ruby collection wrapper that delegates per-element
# (de)serialization to Suggestion.
#
# This spec locks in the round-trip invariant: serialize → parse →
# equal. If any of these fail, the model layer has drifted from the
# serialized shape — that's the failure mode the global "no
# hand-rolled to_h" rule exists to prevent.
RSpec.describe "Result model serialization consistency" do
  let(:suggestion) do
    Kotoshu::Suggestions::Suggestion.new(
      word: "hello", distance: 1, source: "edit_distance",
      confidence: 0.92
    )
  end

  describe Kotoshu::Suggestions::Suggestion do
    it "round-trips through to_hash / from_hash" do
      original = suggestion
      parsed = described_class.from_hash(original.to_hash)
      expect(parsed.word).to eq(original.word)
      expect(parsed.distance).to eq(original.distance)
      expect(parsed.source).to eq(original.source)
      expect(parsed.confidence).to eq(original.confidence)
    end
  end

  describe Kotoshu::Models::Result::WordResult do
    let(:result) do
      described_class.new(
        word: "helo",
        correct: false,
        suggestions: [suggestion],
        position: 42,
        metadata: { line: 3 }
      )
    end

    it "round-trips through to_hash / from_hash" do
      parsed = described_class.from_hash(result.to_hash)
      expect(parsed.word).to eq("helo")
      expect(parsed.correct).to be(false)
      expect(parsed.position).to eq(42)
      expect(parsed.suggestions.length).to eq(1)
      expect(parsed.suggestions.first.word).to eq("hello")
    end

    it "round-trips an empty-suggestions result" do
      result = described_class.correct("hello")
      parsed = described_class.from_hash(result.to_hash)
      expect(parsed.correct?).to be true
      expect(Array(parsed.suggestions)).to be_empty
    end
  end

  describe Kotoshu::Models::Result::DocumentResult do
    let(:word_results) do
      [
        Kotoshu::Models::Result::WordResult.new(
          word: "helo", correct: false, suggestions: [suggestion], position: 0
        ),
        Kotoshu::Models::Result::WordResult.new(
          word: "wrld", correct: false,
          suggestions: [Kotoshu::Suggestions::Suggestion.new(word: "world", distance: 1)],
          position: 5
        )
      ]
    end
    let(:result) do
      described_class.new(file: "input.txt", errors: word_results, word_count: 100,
                          metadata: { language: "en" })
    end

    it "round-trips through to_hash / from_hash" do
      parsed = described_class.from_hash(result.to_hash)
      expect(parsed.file).to eq("input.txt")
      expect(parsed.word_count).to eq(100)
      expect(parsed.errors.length).to eq(2)
      expect(parsed.errors.map(&:word)).to contain_exactly("helo", "wrld")
      expect(parsed.metadata[:language] || parsed.metadata["language"]).to eq("en")
    end

    it "round-trips a result with no errors" do
      success = described_class.new(file: "clean.txt", errors: [], word_count: 50)
      parsed = described_class.from_hash(success.to_hash)
      expect(parsed.success?).to be true
      expect(Array(parsed.errors)).to be_empty
    end
  end

  describe Kotoshu::Suggestions::SuggestionSet do
    it "to_hashes / from_hashes round-trip via the underlying Suggestion" do
      set = described_class.new([
                                  Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1),
                                  Kotoshu::Suggestions::Suggestion.new(word: "world", distance: 2)
                                ])

      hashes = set.to_hashes
      rebuilt = hashes.map { |h| Kotoshu::Suggestions::Suggestion.from_hash(h) }

      expect(rebuilt.map(&:word)).to contain_exactly("hello", "world")
      expect(rebuilt.map(&:distance)).to contain_exactly(1, 2)
    end

    it "as_json delegates to to_hashes (no JSON-specific hand-rolled path)" do
      set = described_class.new([
                                  Kotoshu::Suggestions::Suggestion.new(word: "x", distance: 0)
                                ])
      expect(set.as_json).to eq(set.to_hashes)
    end

    it "is symmetric — empty set to_hashes is []" do
      expect(described_class.empty.to_hashes).to eq([])
    end
  end

  describe "Cross-model invariants" do
    it "WordResult's suggestion collection uses the same Suggestion serialization" do
      word_result = Kotoshu::Models::Result::WordResult.new(
        word: "x", correct: false, suggestions: [suggestion]
      )
      hash = word_result.to_hash
      parsed = Kotoshu::Models::Result::WordResult.from_hash(hash)

      # Suggestion equality: same word + distance (the deterministic
      # fields). Suggestion has custom == via word.lowercase.
      expect(parsed.suggestions.first.word).to eq(word_result.suggestions.first.word)
    end

    it "DocumentResult.errors contains WordResult instances after round-trip" do
      word = Kotoshu::Models::Result::WordResult.new(
        word: "helo", correct: false, suggestions: [suggestion], position: 0
      )
      doc = Kotoshu::Models::Result::DocumentResult.new(file: "f", errors: [word])
      parsed = Kotoshu::Models::Result::DocumentResult.from_hash(doc.to_hash)
      expect(parsed.errors.first).to be_a(Kotoshu::Models::Result::WordResult)
    end
  end
end
