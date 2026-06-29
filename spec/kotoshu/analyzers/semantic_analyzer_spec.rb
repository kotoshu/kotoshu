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

      # EmbeddingModel#similarity calls embedding_for under the hood;
      # context ranking uses similarity. Hand back a trivial embedding
      # so the analyzer's context_boost path doesn't crash on the stub.
      def embedding_for(word)
        return nil unless @vocab.include?(word)

        Kotoshu::Models::WordEmbedding.new(word, [1.0], "en", dimension: 1)
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

  describe "#analyze with a Documents::Document" do
    let(:document) do
      # Two text nodes simulating the markup case:
      #   "an " (plain) + "frend" (bold) + " world" (plain)
      # Flattened: "an frend world"
      # "frend" is OOV → triggers edit-distance fallback → "friend"-ish
      # suggestions (we seed the vocab with "friend" below).
      Kotoshu::Documents::Document.new(
        text_nodes: [
          Kotoshu::Documents::TextNode.new(
            text: "an ",
            source_range: Kotoshu::Documents::SourceRange.new(
              start_pos: Kotoshu::Documents::SourcePosition.new(offset: 0, line: 1, column: 1),
              end_pos: Kotoshu::Documents::SourcePosition.new(offset: 3, line: 1, column: 4)
            ),
            flattened_offset: 0,
            format: :plain
          ),
          Kotoshu::Documents::TextNode.new(
            text: "frend",
            source_range: Kotoshu::Documents::SourceRange.new(
              start_pos: Kotoshu::Documents::SourcePosition.new(offset: 7, line: 1, column: 8),
              end_pos: Kotoshu::Documents::SourcePosition.new(offset: 17, line: 1, column: 18)
            ),
            flattened_offset: 3,
            format: :bold
          ),
          Kotoshu::Documents::TextNode.new(
            text: " world",
            source_range: Kotoshu::Documents::SourceRange.new(
              start_pos: Kotoshu::Documents::SourcePosition.new(offset: 17, line: 1, column: 18),
              end_pos: Kotoshu::Documents::SourcePosition.new(offset: 23, line: 1, column: 24)
            ),
            flattened_offset: 8,
            format: :plain
          )
        ],
        source: "an **frend** world",
        format: :markdown
      )
    end
    let(:vocab) { %w[hello help held heap world ruby test example friend] }
    let(:analyzer_with_friend) { described_class.new(model_class.new(vocab), min_similarity: 0.0) }

    it "rejects a non-Document argument" do
      expect { analyzer_with_friend.analyze("not a document") }
        .to raise_error(ArgumentError, /must be a Kotoshu::Documents::Document/)
    end

    it "emits SemanticErrors carrying source_range from the document" do
      errors = analyzer_with_friend.analyze(document)
      # "an" is 2 chars; "frend" is OOV (5 chars); "world" is in vocab.
      # Expect one error: "frend" → "friend".
      expect(errors.length).to eq(1)
      error = errors.first
      expect(error.original).to eq("frend")
      expect(error.source_range).not_to be_nil
      # Source range matches the bold "**frend**" node (offset 7..17).
      expect(error.source_range.start.offset).to eq(7)
      expect(error.source_range.end.offset).to eq(17)
    end

    it "suggests the in-vocabulary friend for the frend typo" do
      error = analyzer_with_friend.analyze(document).first
      expect(error.suggestions.map(&:word)).to include("friend")
    end

    it "produces an error whose id is stable for the same source range" do
      error_a = analyzer_with_friend.analyze(document).first
      error_b = analyzer_with_friend.analyze(document).first
      expect(error_a.id).to eq(error_b.id)
    end
  end
end
