# frozen_string_literal: true

require "kotoshu"

# Direct spec for Suggestions::Strategies::PhoneticStrategy.
#
# PhoneticStrategy finds dictionary words whose Soundex or Metaphone
# code matches the input word's, then ranks them by Levenshtein
# distance. Soundex and Metaphone are private helpers — exercised
# here through the public generate pipeline.
#
# The strategy had no direct spec — only exercised indirectly via
# CompositeStrategy and integration tests.
RSpec.describe Kotoshu::Suggestions::Strategies::PhoneticStrategy do
  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[robert rupert ashcraft schmidt smith rune rober rubrt rbert],
      language_code: "en"
    )
  end

  let(:strategy) { described_class.new }

  let(:context_for) do
    ->(word) { Kotoshu::Suggestions::Context.new(word: word, dictionary: dictionary) }
  end

  describe "ALGORITHMS constant" do
    it "lists soundex and metaphone" do
      expect(described_class::ALGORITHMS).to contain_exactly(:soundex, :metaphone)
    end

    it "is frozen so external mutation is impossible" do
      expect(described_class::ALGORITHMS).to be_frozen
    end
  end

  describe "#initialize" do
    it "defaults name to :phonetic" do
      expect(described_class.new.name).to eq(:phonetic)
    end

    it "is enabled by default" do
      expect(described_class.new).to be_enabled
    end

    it "honours an explicit name override" do
      expect(described_class.new(name: :phon).name).to eq(:phon)
    end
  end

  describe "#generate (default algorithm = soundex)" do
    it "returns a SuggestionSet of Suggestion objects" do
      result = strategy.generate(context_for.call("rober"))
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result.to_a).to all(be_a(Kotoshu::Suggestions::Suggestion))
    end

    it "tags every suggestion with source = 'phonetic'" do
      result = strategy.generate(context_for.call("rober"))
      result.to_a.each do |s|
        expect(s.source).to eq("phonetic")
      end
    end

    it "excludes the input word from the result set" do
      result = strategy.generate(context_for.call("robert"))
      expect(result.to_words).not_to include("robert")
    end

    it "returns an empty set when no dictionary word shares the phonetic code" do
      result = strategy.generate(context_for.call("zzzzz"))
      expect(result).to be_empty
    end

    it "finds words that share the Soundex code (Robert/Rupert → R163)" do
      # The classic Soundex example: 'robert' and 'rupert' both encode
      # to R163. A query for one should surface the other as a
      # phonetic match (subject to the distance cap of 2).
      #
      # Note: 'rober' encodes to R160 (no final consonant cluster),
      # so the smoke test queries 'robert' directly to surface the
      # R163 classmates 'rupert' / 'rubrt' / 'rbert'.
      result = strategy.generate(context_for.call("robert"))
      expected_classmates = %w[rupert rubrt rbert]
      expect(result.to_words & expected_classmates).not_to be_empty
    end

    it "respects the implicit max_distance=2 cap" do
      result = strategy.generate(context_for.call("rober"))
      result.to_a.each do |s|
        expect(s.distance).to be <= 2
      end
    end

    it "filters out zero-distance matches (which would be the word itself)" do
      result = strategy.generate(context_for.call("robert"))
      result.to_a.each do |s|
        expect(s.distance).to be > 0
      end
    end

    it "sorts suggestions by ascending distance" do
      result = strategy.generate(context_for.call("rober"))
      distances = result.to_a.map(&:distance)
      expect(distances).to eq(distances.sort)
    end
  end

  describe "#generate with algorithm: :metaphone" do
    let(:metaphone_strategy) { described_class.new(algorithm: :metaphone) }

    it "returns a SuggestionSet of Suggestion objects" do
      result = metaphone_strategy.generate(context_for.call("smith"))
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result.to_a).to all(be_a(Kotoshu::Suggestions::Suggestion))
    end

    it "tags every suggestion with source = 'phonetic'" do
      result = metaphone_strategy.generate(context_for.call("smith"))
      result.to_a.each do |s|
        expect(s.source).to eq("phonetic")
      end
    end

    it "excludes the input word from the result set" do
      result = metaphone_strategy.generate(context_for.call("smith"))
      expect(result.to_words).not_to include("smith")
    end

    it "respects the implicit max_distance=2 cap" do
      result = metaphone_strategy.generate(context_for.call("smith"))
      result.to_a.each do |s|
        expect(s.distance).to be <= 2
      end
    end
  end

  describe "#handles?" do
    it "is true for a word not in the dictionary" do
      expect(strategy.handles?(context_for.call("xyzzy"))).to be true
    end

    it "is false for a word in the dictionary" do
      expect(strategy.handles?(context_for.call("robert"))).to be false
    end

    it "is false when the strategy is disabled" do
      disabled = described_class.new(enabled: false)
      expect(disabled.handles?(context_for.call("xyzzy"))).to be false
    end
  end

  describe "algorithm dispatch" do
    # The strategy falls back to soundex when given an unknown
    # algorithm. Pin that contract so callers know the fallback.
    let(:unknown_strategy) { described_class.new(algorithm: :bogus) }

    it "produces results even when the algorithm name is unknown" do
      result = unknown_strategy.generate(context_for.call("rober"))
      # Should behave identically to the soundex default.
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end

    it "produces the same code path as the soundex default" do
      default = strategy.generate(context_for.call("rober")).to_words
      unknown = unknown_strategy.generate(context_for.call("rober")).to_words
      expect(unknown).to eq(default)
    end
  end
end
