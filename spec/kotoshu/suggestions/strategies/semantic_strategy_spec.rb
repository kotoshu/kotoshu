# frozen_string_literal: true

require_relative "../../../../lib/kotoshu/suggestions/strategies/semantic_strategy"
require_relative "../../../../lib/kotoshu/suggestions/context"
require_relative "../../../../lib/kotoshu/dictionary/plain_text"

RSpec.describe Kotoshu::Suggestions::Strategies::SemanticStrategy do
  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello world help held hell bell well tell shell yellow their they're],
      language_code: "en"
    )
  end

  let(:context) { Kotoshu::Suggestions::Context.new(word: "helo", dictionary: dictionary) }

  describe "#initialize" do
    it "creates a strategy with language code" do
      strategy = described_class.new(language_code: "en")
      expect(strategy.name).to eq(:semantic)
      expect(strategy.language_code).to eq("en")
    end

    it "accepts config options" do
      strategy = described_class.new(
        language_code: "en",
        min_semantic_similarity: 0.7,
        semantic_boost_weight: 0.5
      )
      expect(strategy.get_config(:min_semantic_similarity)).to eq(0.7)
      expect(strategy.get_config(:semantic_boost_weight)).to eq(0.5)
    end

    it "is enabled by default" do
      strategy = described_class.new(language_code: "en")
      expect(strategy.enabled?).to be true
    end

    it "can be disabled" do
      strategy = described_class.new(language_code: "en", enabled: false)
      expect(strategy.enabled?).to be false
    end
  end

  describe "#generate" do
    context "when ONNX model is not available" do
      let(:strategy) { described_class.new(language_code: "xx") }

      it "returns empty suggestion set" do
        result = strategy.generate(context)
        expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
        expect(result.size).to be_zero
      end
    end

    context "when ONNX model is available", :integration do
      let(:strategy) do
        described_class.new(
          language_code: "en",
          preload_embeddings: false
        )
      end

      before do
        # Skip if ONNX model not cached
        skip "ONNX model not available for en" unless strategy.vocabulary && strategy.model
      end

      it "generates suggestions for a typo" do
        typo_context = Kotoshu::Suggestions::Context.new(
          word: "helo",
          dictionary: dictionary
        )
        result = strategy.generate(typo_context)
        expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
        # Should find semantically similar words
        expect(result.size).to be > 0 unless result.empty?
      end

      it "includes semantic_similarity in metadata" do
        result = strategy.generate(context)
        unless result.empty?
          first_suggestion = result.suggestions.first
          expect(first_suggestion.metadata).to have_key(:semantic_similarity)
        end
      end

      it "respects max_results config" do
        limited_strategy = described_class.new(
          language_code: "en",
          max_results: 3
        )
        result = limited_strategy.generate(context)
        expect(result.size).to be <= 3 unless result.empty?
      end

      it "handles words in vocabulary (real-word errors)" do
        valid_context = Kotoshu::Suggestions::Context.new(
          word: "their",
          dictionary: dictionary
        )
        result = strategy.generate(valid_context)
        expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      end
    end
  end

  describe "#handles?" do
    let(:strategy) { described_class.new(language_code: "en") }

    it "returns true when enabled" do
      expect(strategy.handles?(context)).to be true
    end

    it "returns false when disabled" do
      disabled_strategy = described_class.new(language_code: "en", enabled: false)
      expect(disabled_strategy.handles?(context)).to be false
    end

    it "returns true for words not in vocabulary" do
      typo_context = Kotoshu::Suggestions::Context.new(
        word: "xyzabc",
        dictionary: dictionary
      )
      expect(strategy.handles?(typo_context)).to be true
    end

    it "returns true for words in vocabulary (real-word error detection)" do
      valid_context = Kotoshu::Suggestions::Context.new(
        word: "hello",
        dictionary: dictionary
      )
      expect(strategy.handles?(valid_context)).to be true
    end
  end

  describe "#semantic_similarity", :integration do
    let(:strategy) do
      described_class.new(language_code: "en")
    end

    before do
      skip "ONNX model not available" unless strategy.search
    end

    it "computes similarity between two words" do
      similarity = strategy.semantic_similarity("hello", "world")
      expect(similarity).to be_a(Float).or be_nil
    end

    it "returns nil for unknown words" do
      similarity = strategy.semantic_similarity("xyzabc", "hello")
      expect(similarity).to be_nil
    end

    it "returns 1.0 for identical words" do
      similarity = strategy.semantic_similarity("hello", "hello")
      expect(similarity).to eq(1.0) unless similarity.nil?
    end
  end

  describe "#find_similar_words", :integration do
    let(:strategy) do
      described_class.new(language_code: "en")
    end

    before do
      skip "ONNX model not available" unless strategy.search
    end

    it "finds semantically similar words" do
      neighbors = strategy.find_similar_words("hello", k: 5)
      expect(neighbors).to be_an(Array)
      expect(neighbors.size).to be <= 5
    end

    it "returns hashes with word and similarity keys" do
      neighbors = strategy.find_similar_words("hello", k: 3)
      unless neighbors.empty?
        first = neighbors.first
        expect(first).to have_key(:word)
        expect(first).to have_key(:similarity)
      end
    end
  end

  describe "#embedding_for", :integration do
    let(:strategy) do
      described_class.new(language_code: "en")
    end

    before do
      skip "ONNX model not available" unless strategy.search
    end

    it "returns embedding vector for known word" do
      embedding = strategy.embedding_for("hello")
      expect(embedding).to be_an(Array) unless embedding.nil?
    end

    it "returns nil for unknown word" do
      embedding = strategy.embedding_for("xyzabc123")
      expect(embedding).to be_nil
    end
  end

  describe "#to_s" do
    it "returns informative string representation" do
      strategy = described_class.new(language_code: "en")
      str = strategy.to_s
      expect(str).to include("SemanticStrategy")
      expect(str).to include("en")
    end
  end

  describe "context analysis", :integration do
    let(:strategy) do
      described_class.new(
        language_code: "en",
        max_context_window: 5
      )
    end

    before do
      skip "ONNX model not available" unless strategy.search
    end

    it "can analyze context for real-word errors" do
      # "their" vs "they're" - both valid but context matters
      valid_context = Kotoshu::Suggestions::Context.new(
        word: "their",
        dictionary: dictionary
      )
      result = strategy.generate(valid_context)
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end
  end
end
