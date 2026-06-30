# frozen_string_literal: true

require "kotoshu"

# Direct spec for Models::Result::WordResult — the per-word check result.
#
# WordResult is a lutaml-model Serializable that wraps a word with its
# correct/incorrect flag, optional position, and a collection of
# Suggestion objects. It is the per-word shape returned by Spellchecker
# and aggregated by DocumentResult.
RSpec.describe Kotoshu::Models::Result::WordResult do
  let(:suggestion_class) { Kotoshu::Suggestions::Suggestion }
  let(:suggestions) do
    [
      suggestion_class.new(word: "hello", distance: 1, source: "edit_distance"),
      suggestion_class.new(word: "hell", distance: 2, source: "edit_distance"),
      suggestion_class.new(word: "help", distance: 2, source: "ngram")
    ]
  end

  describe ".correct" do
    it "builds a correct result with no suggestions" do
      result = described_class.correct("hello")
      expect(result).to be_correct
      expect(result.suggestions).to be_empty
    end

    it "honours the position keyword" do
      result = described_class.correct("hello", position: 42)
      expect(result.position).to eq(42)
    end
  end

  describe ".incorrect" do
    it "builds an incorrect result" do
      result = described_class.incorrect("hellp", suggestions: suggestions)
      expect(result).to be_incorrect
    end

    it "stores the suggestions array" do
      result = described_class.incorrect("hellp", suggestions: suggestions)
      expect(result.suggestions.size).to eq(3)
    end

    it "accepts a SuggestionSet for suggestions" do
      set = Kotoshu::Suggestions::SuggestionSet.new(suggestions)
      result = described_class.incorrect("hellp", suggestions: set)
      expect(result.suggestions.size).to eq(3)
    end

    it "defaults suggestions to an empty array" do
      result = described_class.incorrect("hellp")
      expect(result.suggestions).to be_empty
    end

    it "raises ArgumentError for an unsupported suggestions type" do
      expect do
        described_class.incorrect("hellp", suggestions: "bogus")
      end.to raise_error(ArgumentError, /SuggestionSet, Array, or nil/)
    end
  end

  describe "#initialize" do
    it "stringifies the word" do
      result = described_class.new(word: :foo, correct: true)
      expect(result.word).to eq("foo")
    end

    it "accepts metadata" do
      result = described_class.new(word: "foo", correct: true, metadata: { lang: "en" })
      expect(result.metadata[:lang]).to eq("en")
    end

    it "defaults metadata to an empty hash" do
      result = described_class.new(word: "foo", correct: true)
      expect(result.metadata).to eq({})
    end
  end

  describe "#correct? / #incorrect?" do
    it "is correct when correct: true" do
      expect(described_class.correct("hello")).to be_correct
      expect(described_class.correct("hello")).not_to be_incorrect
    end

    it "is incorrect when correct: false" do
      result = described_class.incorrect("hellp")
      expect(result).to be_incorrect
      expect(result).not_to be_correct
    end
  end

  describe "#has_suggestions? / #suggestion_count" do
    it "reports suggestions present" do
      result = described_class.incorrect("hellp", suggestions: suggestions)
      expect(result).to have_suggestions
      expect(result.suggestion_count).to eq(3)
    end

    it "reports no suggestions when empty" do
      result = described_class.incorrect("hellp")
      expect(result).not_to have_suggestions
      expect(result.suggestion_count).to eq(0)
    end
  end

  describe "#top_suggestions" do
    it "returns the first n suggestion words" do
      result = described_class.incorrect("hellp", suggestions: suggestions)
      expect(result.top_suggestions(2)).to eq(%w[hello hell])
    end

    it "defaults to 3" do
      result = described_class.incorrect("hellp", suggestions: suggestions)
      expect(result.top_suggestions.size).to eq(3)
    end
  end

  describe "#first_suggestion" do
    it "returns the first suggestion's word" do
      result = described_class.incorrect("hellp", suggestions: suggestions)
      expect(result.first_suggestion).to eq("hello")
    end

    it "returns nil when there are no suggestions" do
      result = described_class.incorrect("hellp")
      expect(result.first_suggestion).to be_nil
    end
  end

  describe "#to_suggestion_set" do
    it "wraps the suggestions in a SuggestionSet" do
      result = described_class.incorrect("hellp", suggestions: suggestions)
      set = result.to_suggestion_set
      expect(set).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(set.size).to eq(3)
    end
  end

  describe "#== / #eql? / #hash" do
    it "equals another WordResult with the same word and correct flag" do
      a = described_class.correct("hello")
      b = described_class.correct("hello")
      expect(a).to eq(b)
      expect(a.eql?(b)).to be true
    end

    it "differs when the word differs" do
      expect(described_class.correct("a")).not_to eq(described_class.correct("b"))
    end

    it "differs when the correct flag differs" do
      expect(described_class.correct("x")).not_to eq(described_class.incorrect("x"))
    end

    it "is consistent with hash equality" do
      a = described_class.correct("hello")
      b = described_class.correct("hello")
      expect(a.hash).to eq(b.hash)
    end

    it "returns false when compared to a non-WordResult" do
      expect(described_class.correct("hello")).not_to eq("hello")
    end
  end

  describe "#to_s / #inspect" do
    it "shows just the word when correct" do
      expect(described_class.correct("hello").to_s).to eq("hello")
    end

    it "shows top suggestions when incorrect with suggestions" do
      result = described_class.incorrect("hellp", suggestions: suggestions)
      expect(result.to_s).to start_with("hellp (did you mean ")
      expect(result.to_s).to include("hello")
    end

    it "shows 'no suggestions' when incorrect without suggestions" do
      result = described_class.incorrect("zzzz")
      expect(result.to_s).to eq("zzzz (no suggestions)")
    end

    it "aliases inspect to to_s" do
      result = described_class.correct("hello")
      expect(result.inspect).to eq(result.to_s)
    end
  end
end
