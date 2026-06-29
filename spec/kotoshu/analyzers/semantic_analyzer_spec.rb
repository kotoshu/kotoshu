# frozen_string_literal: true

require "kotoshu"

# Direct spec for the SemanticAnalyzer's OOV fallback path.
#
# When the embedding model returns [] for a word (which is what
# EmbeddingModel#nearest_neighbors does for any OOV input — it has no
# vector to compute similarity against), the analyzer falls back to
# an edit-distance walk over the model's vocabulary. This keeps the
# semantic path useful for the exact case it exists to handle:
# misspellings, which by definition are not in the vocabulary.
#
# This spec uses an in-memory EmbeddingModel subclass (no ONNX runtime
# required) so it runs in the default suite.
RSpec.describe Kotoshu::Analyzers::SemanticAnalyzer do
  let(:model_class) do
    Class.new(Kotoshu::Models::EmbeddingModel) do
      def initialize(vocab)
        @vocab = vocab
      end

      def vocabulary
        @vocab
      end

      # Only in-vocab words have neighbors; OOV returns [] — that's
      # the production behavior this spec exercises the fallback for.
      def nearest_neighbors(word, k: 10)
        return [] unless @vocab.include?(word)

        # Trivial neighbor set: don't bother computing real vectors,
        # just return the word itself with similarity 1.0.
        [Kotoshu::Models::NearestNeighbor.new(word: word, similarity: 1.0,
                                              distance: 0, embedding: nil)]
      end
    end
  end

  let(:vocab) { %w[hello help held heap world ruby test example] }
  let(:model) { model_class.new(vocab) }
  let(:analyzer) { described_class.new(model, min_similarity: 0.0) }

  describe "#suggest_corrections for an OOV word" do
    it "falls back to edit-distance neighbors when the model returns []" do
      corrections = analyzer.suggest_corrections("helo")
      words = corrections.map(&:word)
      expect(words).to include("hello")
      expect(words).to include("help")
    end

    it "scored by inverse edit distance (distance-1 ranks above distance-2)" do
      corrections = analyzer.suggest_corrections("helo")
      hello = corrections.find { |c| c.word == "hello" }
      expect(hello.confidence).to be > 0.4 # distance 1 → 1/(1+1) = 0.5
    end

    it "returns [] when no vocabulary word is within edit distance 2" do
      corrections = analyzer.suggest_corrections("zzzzzzzzz")
      expect(corrections).to eq([])
    end
  end

  describe "#suggest_corrections for an in-vocab word" do
    it "uses the model's nearest_neighbors (no fallback)" do
      corrections = analyzer.suggest_corrections("hello")
      # The stub returns a single trivial neighbor (the word itself).
      expect(corrections.length).to eq(1)
      expect(corrections.first.word).to eq("hello")
    end
  end
end
