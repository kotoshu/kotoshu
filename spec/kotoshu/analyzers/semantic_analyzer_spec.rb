# frozen_string_literal: true

require "kotoshu"

# Trigger autoload of the analyzers namespace.
Kotoshu::Analyzers::SemanticAnalyzer

# Direct spec for Analyzers::SemanticAnalyzer.
#
# The analyzer was only exercised indirectly via the CLI (which itself has
# limited specs and depends on ONNX runtime). This file uses a toy
# EmbeddingModel subclass + Struct-backed document/location fixtures —
# no ONNX, no network.
#
# While writing this spec, a fundamental design flaw surfaced:
#
#   `#suggest_corrections` calls `@model.nearest_neighbors(word, ...)`,
#   which returns [] for OOV words (out-of-vocabulary). But OOV is
#   precisely the case the analyzer is supposed to handle. The result is
#   that `#detect_error` calls `SemanticError.new(suggestions: [])`, which
#   raises ArgumentError (SemanticError rejects empty suggestions).
#
# The full fix requires either:
#   - adding an edit-distance fallback for OOV queries (the traditional path),
#   - using FastText subword embeddings to synthesize an OOV vector, or
#   - relaxing SemanticError's empty-suggestions constraint.
#
# Until that lands, the affected tests below assert the CURRENT behavior
# (returning [] / raising ArgumentError) as regression tests, with NOTE
# comments. When the design is fixed, those tests should be flipped to
# assert the correct behavior.
RSpec.describe Kotoshu::Analyzers::SemanticAnalyzer do
  # ---- fixtures ----------------------------------------------------------

  # A real EmbeddingModel subclass with a tiny in-memory vocabulary.
  let(:toy_model_class) do
    Class.new(Kotoshu::Models::EmbeddingModel) do
      def initialize(vocab:, vectors:, language_code: "en", dimension: 3)
        super(language_code: language_code, dimension: dimension)
        @vocab = vocab
        @vectors = vectors
        @vocabulary_size = vocab.size
      end

      def embedding_for(word)
        idx = @vocab.index(word)
        return nil unless idx

        Kotoshu::Models::WordEmbedding.new(word, @vectors[idx], @language_code,
                                           dimension: @dimension)
      end

      def vocabulary
        @vocab
      end
    end
  end

  # cat=[1,0,0], dog=[0.9,0.1,0] (similar to cat), car=[0,0,1] (far).
  let(:vocab) { %w[cat dog car] }
  let(:vectors) do
    [
      [1.0, 0.0, 0.0],
      [0.9, 0.1, 0.0],
      [0.0, 0.0, 1.0]
    ]
  end
  let(:model) { toy_model_class.new(vocab: vocab, vectors: vectors) }
  let(:analyzer) { described_class.new(model) }
  let(:location) { Loc.new(1, 0) }

  # Struct-backed location matching what Context#word_at_location reads
  # (calls @location.column and @location.line) and what SemanticError#<=>
  # delegates to (needs <=>).
  Loc = Struct.new(:line, :column) do
    include Comparable

    def <=>(other)
      [line, column] <=> [other.line, other.column]
    end
  end

  # ---- constructor -------------------------------------------------------

  describe "#initialize" do
    it "accepts an EmbeddingModel" do
      expect(described_class.new(model).model).to be(model)
    end

    it "raises ArgumentError when given a non-EmbeddingModel" do
      expect { described_class.new("not a model") }
        .to raise_error(ArgumentError, /Model must be an EmbeddingModel/)
    end

    it "exposes max_suggestions and the default" do
      expect(analyzer.max_suggestions).to eq(described_class::DEFAULT_MAX_SUGGESTIONS)
    end

    it "accepts custom max_suggestions" do
      a = described_class.new(model, max_suggestions: 3)
      expect(a.max_suggestions).to eq(3)
    end
  end

  # ---- valid_word? -------------------------------------------------------

  describe "#valid_word?" do
    it "is true for words in the vocabulary" do
      expect(analyzer.valid_word?("cat")).to be true
    end

    it "is false for OOV words" do
      expect(analyzer.valid_word?("helo")).to be false
    end

    it "is false for nil/empty strings" do
      expect(analyzer.valid_word?(nil)).to be false
      expect(analyzer.valid_word?("")).to be false
    end

    it "is true for pure numbers (skipped as a shortcut)" do
      expect(analyzer.valid_word?("123")).to be true
    end

    it "is true for single characters (treated as abbreviations)" do
      expect(analyzer.valid_word?("a")).to be true
    end
  end

  # ---- calculate_confidence ---------------------------------------------

  describe "#calculate_confidence" do
    def suggestion(confidence)
      Kotoshu::Models::Suggestion.new("x", confidence: confidence)
    end

    it "is 1.0 when top suggestion > HIGH_CONFIDENCE_THRESHOLD (0.85)" do
      expect(analyzer.calculate_confidence([suggestion(0.9)])).to eq(1.0)
    end

    it "is 0.7 when top suggestion is in the medium band (0.70..0.85]" do
      expect(analyzer.calculate_confidence([suggestion(0.75)])).to eq(0.7)
    end

    it "is 0.5 when top suggestion is below MEDIUM_CONFIDENCE_THRESHOLD" do
      expect(analyzer.calculate_confidence([suggestion(0.6)])).to eq(0.5)
    end

    it "is 0.0 when there are no suggestions" do
      expect(analyzer.calculate_confidence([])).to eq(0.0)
      expect(analyzer.calculate_confidence(nil)).to eq(0.0)
    end
  end

  # ---- suggest_corrections ----------------------------------------------

  describe "#suggest_corrections" do
    it "returns [] for nil/empty word" do
      expect(analyzer.suggest_corrections(nil)).to eq([])
      expect(analyzer.suggest_corrections("")).to eq([])
    end

    # NOTE: design-flaw regression test. nearest_neighbors returns [] for
    # OOV queries, so suggest_corrections also returns [] for them. The
    # analyzer's primary purpose is to suggest corrections for OOV words,
    # so this is broken. When the fallback path lands, flip this test to
    # expect a non-empty array.
    it "currently returns [] for OOV words (design flaw — see file header)" do
      expect(analyzer.suggest_corrections("helo")).to eq([])
    end

    it "filters out suggestions below min_similarity" do
      a = described_class.new(model, min_similarity: 0.999)
      expect(a.suggest_corrections("cat")).to eq([])
    end

    it "returns at most max_suggestions" do
      a = described_class.new(model, max_suggestions: 1)
      result = a.suggest_corrections("cat")
      expect(result.length).to be <= 1
    end
  end

  # ---- detect_error ------------------------------------------------------

  describe "#detect_error" do
    it "returns nil for a valid (in-vocab) word" do
      expect(analyzer.detect_error(word: "cat", location: location)).to be_nil
    end

    # NOTE: design-flaw regression test. suggest_corrections returns [] for
    # OOV words → SemanticError.new rejects empty suggestions → ArgumentError.
    # When the OOV fallback lands, flip this to expect a SemanticError.
    it "currently raises ArgumentError for OOV words (design flaw — see header)" do
      expect { analyzer.detect_error(word: "helo", location: location) }
        .to raise_error(ArgumentError, /Suggestions cannot be empty/)
    end
  end

  # ---- analyze -----------------------------------------------------------

  describe "#analyze" do
    # Minimal document Struct. text_nodes is an Array of Structs with
    # #text and #location. context_for is an overridable method (Struct
    # auto-generates attribute readers, so use a real class with the
    # method defined explicitly).
    let(:document_class) do
      Class.new do
        def initialize(text_nodes:, context_for_proc:)
          @text_nodes = text_nodes
          @context_for_proc = context_for_proc
        end

        attr_reader :text_nodes

        def context_for(loc)
          @context_for_proc.call(loc)
        end
      end
    end

    let(:text_node_class) { Struct.new(:text, :location, keyword_init: true) }

    let(:document) do
      document_class.new(
        text_nodes: [text_node_class.new(text: "cat dog car", location: Loc.new(1, 0))],
        context_for_proc: ->(_loc) {}
      )
    end

    it "returns an array" do
      expect(analyzer.analyze(document)).to be_an(Array)
    end

    it "returns [] when the document has no OOV words" do
      expect(analyzer.analyze(document)).to eq([])
    end

    # NOTE: design-flaw regression test. Any OOV word in the document
    # triggers detect_error, which raises ArgumentError. The whole analyze
    # call therefore raises on the first OOV word — it can't recover.
    # When the OOV fallback lands, flip this to expect a 1-element array
    # of SemanticErrors.
    it "currently propagates ArgumentError from detect_error on OOV (design flaw)" do
      doc = document_class.new(
        text_nodes: [text_node_class.new(text: "helo",
                                         location: Loc.new(1, 0))],
        context_for_proc: ->(_loc) {}
      )
      expect { analyzer.analyze(doc) }
        .to raise_error(ArgumentError, /Suggestions cannot be empty/)
    end
  end

  # ---- constants ---------------------------------------------------------

  describe "constants" do
    it "defines the documented thresholds" do
      expect(described_class::HIGH_CONFIDENCE_THRESHOLD).to eq(0.85)
      expect(described_class::MEDIUM_CONFIDENCE_THRESHOLD).to eq(0.70)
      expect(described_class::MIN_SIMILARITY).to eq(0.50)
      expect(described_class::DEFAULT_MAX_SUGGESTIONS).to eq(5)
    end
  end
end
