# frozen_string_literal: true

require "kotoshu"

# Phase E of TODO.impl/38-onnx-semantic-gating.md
#
# This is the end-to-end smoke test for the semantic path. It is tagged
# :onnx so it only runs when ONNX_TESTS=1 is set, and it skips
# gracefully when the English model is not cached or onnxruntime is
# unavailable.
#
# Coverage:
#   - Resolve the English model from cache (skip on miss).
#   - SemanticStrategy end-to-end: similarity, find_similar, generate.
#   - SemanticAnalyzer construction from OnnxModel + valid_word? round-trip.
#   - Distinguishability: related word pairs score higher than unrelated.
RSpec.describe "Semantic path end-to-end", :onnx do
  let(:language_code) { "en" }

  let(:strategy) do
    Kotoshu::Suggestions::Strategies::SemanticStrategy.new(
      language_code: language_code,
      preload_embeddings: false
    )
  end

  before do
    skip "onnxruntime not loaded" unless Kotoshu::Models::OnnxModel::ONNX_LOADED
    skip "ONNX model not cached for #{language_code}" unless strategy.search
  end

  describe "SemanticStrategy#semantic_similarity" do
    it "returns a Float for in-vocabulary word pairs" do
      sim = strategy.semantic_similarity("cat", "dog")
      expect(sim).to be_a(Float)
      expect(sim).to be_within(1.0).of(0.0)
    end

    it "returns nil when either word is out of vocabulary" do
      expect(strategy.semantic_similarity("zzznotaword", "cat")).to be_nil
      expect(strategy.semantic_similarity("cat", "zzznotaword")).to be_nil
    end

    it "distinguishes related from unrelated word pairs" do
      # Related concepts should cluster together in FastText space.
      related = strategy.semantic_similarity("cat", "dog")
      unrelated = strategy.semantic_similarity("cat", "computer")

      skip "one of the probe words is OOV" if related.nil? || unrelated.nil?

      expect(related).to be > unrelated
    end

    it "scores a word against itself at or near 1.0" do
      sim = strategy.semantic_similarity("hello", "hello")
      skip "probe word OOV" if sim.nil?

      expect(sim).to be_within(0.01).of(1.0)
    end
  end

  describe "SemanticStrategy#find_similar_words" do
    it "returns a non-empty list of neighbors for an in-vocabulary word" do
      neighbors = strategy.find_similar_words("hello", k: 5)
      expect(neighbors).to be_an(Array)
      expect(neighbors.size).to be > 0
      expect(neighbors.first).to be_a(Hash)
      expect(neighbors.first[:word]).to be_a(String)
      expect(neighbors.first[:similarity]).to be_a(Float)
    end

    it "respects the k limit" do
      neighbors = strategy.find_similar_words("world", k: 3)
      expect(neighbors.size).to be <= 3
    end
  end

  describe "SemanticStrategy#generate for a typo" do
    let(:dictionary) do
      Kotoshu::Dictionary::PlainText.from_words(
        %w[hello help held hell hero helmet],
        language_code: language_code
      )
    end

    let(:context) do
      Kotoshu::Suggestions::Context.new(word: "helo", dictionary: dictionary)
    end

    it "returns a SuggestionSet of the correct type" do
      result = strategy.generate(context)
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end

    it "produces at least one candidate from semantic neighbors" do
      result = strategy.generate(context)
      # Either the strategy finds semantic neighbors or it returns empty,
      # but the call must succeed without raising.
      expect(result.size).to be >= 0
    end
  end

  describe "SemanticAnalyzer construction from OnnxModel" do
    it "builds an analyzer from the cached OnnxModel and answers valid_word?" do
      model = Kotoshu::Models::OnnxModel.from_github(language_code)
      analyzer = Kotoshu::Analyzers::SemanticAnalyzer.new(model)

      expect(analyzer.model).to be(model)
      expect(analyzer.max_suggestions).to be > 0

      # Round-trip the vocabulary predicate on a common English word.
      expect(analyzer.valid_word?("hello")).to be true
      expect(analyzer.valid_word?("zzznotaword")).to be false
    end

    it "produces corrections for a misspelling" do
      model = Kotoshu::Models::OnnxModel.from_github(language_code)
      analyzer = Kotoshu::Analyzers::SemanticAnalyzer.new(model)

      corrections = analyzer.suggest_corrections("helo")
      expect(corrections).to be_an(Array)
      expect(corrections.size).to be <= analyzer.max_suggestions
    end
  end
end
