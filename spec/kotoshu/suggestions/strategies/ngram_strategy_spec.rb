# frozen_string_literal: true

require "kotoshu"

# Direct spec for Suggestions::Strategies::NgramStrategy.
#
# NgramStrategy ranks dictionary words by Jaccard n-gram similarity to
# the input word and returns those above two thresholds (raw similarity
# and typo-similarity), with a non-zero distance derived from similarity.
#
# The strategy was only exercised indirectly via CompositeStrategy /
# integration tests. This spec pins its thresholds, distance
# derivation, and edge cases.
RSpec.describe Kotoshu::Suggestions::Strategies::NgramStrategy do
  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello help held hell shell yellow helo helds helps],
      language_code: "en"
    )
  end

  let(:strategy) { described_class.new }

  let(:context_for) do
    ->(word) { Kotoshu::Suggestions::Context.new(word: word, dictionary: dictionary) }
  end

  describe "#initialize" do
    it "defaults name to :ngram" do
      expect(described_class.new.name).to eq(:ngram)
    end

    it "is enabled by default" do
      expect(described_class.new).to be_enabled
    end

    it "honours an explicit name override" do
      expect(described_class.new(name: :custom_ngram).name).to eq(:custom_ngram)
    end
  end

  describe "#generate" do
    it "returns a SuggestionSet of Suggestion objects" do
      result = strategy.generate(context_for.call("helo"))
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result.to_a).to all(be_a(Kotoshu::Suggestions::Suggestion))
    end

    it "tags every suggestion with source = 'ngram'" do
      result = strategy.generate(context_for.call("helo"))
      result.to_a.each do |s|
        expect(s.source).to eq("ngram")
      end
    end

    it "excludes the input word from the result set" do
      # 'helo' is in the test dictionary — generate should still not
      # return it as a suggestion for itself.
      result = strategy.generate(context_for.call("helo"))
      expect(result.to_words).not_to include("helo")
    end

    it "stamps original_length metadata on each suggestion" do
      result = strategy.generate(context_for.call("helo"))
      result.to_a.each do |s|
        expect(s.metadata[:original_length]).to eq(4)
      end
    end

    it "returns an empty set when the input word is shorter than n" do
      # n defaults to 3 — a 2-character word has no 3-grams.
      result = strategy.generate(context_for.call("he"))
      expect(result).to be_empty
    end

    it "returns an empty set when no dictionary word passes the thresholds" do
      result = strategy.generate(context_for.call("zzzzzzzzzz"))
      expect(result).to be_empty
    end

    it "honours a custom n via config" do
      bigram = described_class.new(n: 2, min_similarity: 0.1, min_typo_similarity: 0.1)
      result = bigram.generate(context_for.call("helo"))
      # With bigrams + low thresholds we should get at least one suggestion
      # for a near-typo like 'helo'.
      expect(result.size).to be_positive
    end

    it "honours a stricter min_similarity threshold by returning fewer suggestions" do
      strict = described_class.new(min_similarity: 0.95, min_typo_similarity: 0.95)
      loose = described_class.new(min_similarity: 0.1, min_typo_similarity: 0.1)
      strict_result = strict.generate(context_for.call("helo"))
      loose_result = loose.generate(context_for.call("helo"))
      expect(strict_result.size).to be <= loose_result.size
    end

    it "derives distance from similarity: higher similarity = lower distance" do
      result = strategy.generate(context_for.call("helo"))
      next if result.size < 2

      # Take the top two by sort order (lower distance first).
      first, second = result.to_a.first(2)
      expect(first.distance).to be <= second.distance
    end

    it "every distance is non-zero (zero-distance matches are filtered)" do
      result = strategy.generate(context_for.call("helo"))
      result.to_a.each do |s|
        expect(s.distance).to be > 0
      end
    end
  end

  describe "#handles?" do
    it "is true for a word not in the dictionary" do
      expect(strategy.handles?(context_for.call("xyzzy"))).to be true
    end

    it "is false for a word in the dictionary" do
      expect(strategy.handles?(context_for.call("hello"))).to be false
    end

    it "is false when the strategy is disabled" do
      disabled = described_class.new(enabled: false)
      expect(disabled.handles?(context_for.call("xyzzy"))).to be false
    end
  end

  describe "ranking" do
    it "ranks higher-similarity (lower-distance) suggestions first" do
      result = strategy.generate(context_for.call("helo"))
      distances = result.to_a.map(&:distance)
      expect(distances).to eq(distances.sort)
    end
  end

  describe "with a real misspelled word (smoke)" do
    it "finds plausible corrections for 'helo'" do
      result = strategy.generate(context_for.call("helo"))
      # 'helo' is close to several dictionary words. We don't pin the
      # exact ranking — that depends on Jaccard + typo-similarity
      # thresholds — but at least one near-neighbour should appear.
      expected_neighbours = %w[hello hell help held]
      expect(result.to_words & expected_neighbours).not_to be_empty
    end
  end
end
