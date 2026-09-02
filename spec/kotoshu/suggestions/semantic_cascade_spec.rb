# frozen_string_literal: true

require "kotoshu"

# Direct spec for Suggestions::SemanticCascade (TODO.impl/70).
#
# SemanticCascade is the confidence-cascade decision object for the
# semantic rerank: skip the (expensive, ONNX-backed) rerank when the
# traditional composite pool is already confident. These specs pin
# the comparison semantics with real Suggestion objects and a real
# Configuration — no ONNX needed, the decision is pure input/output.
RSpec.describe Kotoshu::Suggestions::SemanticCascade do
  def suggestion(word:, confidence:)
    Kotoshu::Suggestions::Suggestion.new(
      word: word, confidence: confidence, source: :edit_distance
    )
  end

  def pool(*confidences)
    confidences.map { |c| suggestion(word: "hello", confidence: c) }
  end

  describe "#initialize" do
    it "defaults to the always-rerank threshold" do
      expect(described_class.new.threshold).to eq(described_class::ALWAYS_RERANK)
    end

    it "falls back to always-rerank for a nil threshold" do
      expect(described_class.new(threshold: nil).threshold)
        .to eq(described_class::ALWAYS_RERANK)
    end

    it "coerces non-Float thresholds (e.g. ENV strings) to Float" do
      expect(described_class.new(threshold: "0.9").threshold).to eq(0.9)
      expect(described_class.new(threshold: "0.9").threshold).to be_a(Float)
    end
  end

  describe ".from_configuration" do
    it "reads the SCHEMA default (1.0) from a fresh Configuration" do
      cascade = described_class.from_configuration(Kotoshu::Configuration.new)
      expect(cascade.threshold).to eq(1.0)
    end

    it "reads a programmatic threshold from the Configuration" do
      config = Kotoshu::Configuration.new
      config.semantic_cascade_threshold = 0.85
      cascade = described_class.from_configuration(config)
      expect(cascade.threshold).to eq(0.85)
    end

    it "reads KOTOSHU_SEMANTIC_CASCADE_THRESHOLD and converts it to Float" do
      ENV["KOTOSHU_SEMANTIC_CASCADE_THRESHOLD"] = "0.75"
      begin
        cascade = described_class.from_configuration(Kotoshu::Configuration.new)
        expect(cascade.threshold).to eq(0.75)
        expect(cascade.threshold).to be_a(Float)
      ensure
        ENV.delete("KOTOSHU_SEMANTIC_CASCADE_THRESHOLD")
      end
    end
  end

  describe "#armed?" do
    it "is false at the default threshold (always rerank)" do
      expect(described_class.new(threshold: 1.0)).not_to be_armed
    end

    it "is true for any threshold strictly below 1.0" do
      expect(described_class.new(threshold: 0.9)).to be_armed
      expect(described_class.new(threshold: 0.0)).to be_armed
    end

    it "is false above 1.0 (never skips)" do
      expect(described_class.new(threshold: 1.5)).not_to be_armed
    end
  end

  describe "#skip?" do
    context "at the default threshold of 1.0" do
      # Composite confidence legitimately reaches exactly 1.0
      # (distance-0 matches, the default confidence of a fresh
      # Suggestion) — a plain >= would change the default behavior.
      # 1.0 is the always-rerank sentinel: never skips.
      let(:cascade) { described_class.new(threshold: 1.0) }

      it "never skips, even for a top candidate with confidence exactly 1.0" do
        expect(cascade.skip?(pool(1.0, 0.5))).to be false
      end
    end

    context "at threshold 0.0 (never rerank)" do
      let(:cascade) { described_class.new(threshold: 0.0) }

      it "skips any non-empty pool, even a low-confidence one" do
        expect(cascade.skip?(pool(0.1, 0.0))).to be true
      end

      it "does not skip an empty pool (traditional found nothing)" do
        expect(cascade.skip?([])).to be false
      end
    end

    context "at a mid threshold" do
      let(:cascade) { described_class.new(threshold: 0.9) }

      it "skips when the top confidence is at or above the threshold" do
        expect(cascade.skip?(pool(0.95, 0.4))).to be true
        expect(cascade.skip?(pool(0.9, 0.4))).to be true
      end

      it "does not skip when the top confidence is below the threshold" do
        expect(cascade.skip?(pool(0.89, 0.4))).to be false
      end

      it "judges by the top candidate, not the rest of the pool" do
        expect(cascade.skip?(pool(0.4, 0.95))).to be false
        expect(cascade.skip?(pool(0.95, 0.4))).to be true
      end

      it "does not skip an empty pool" do
        expect(cascade.skip?([])).to be false
      end
    end
  end
end
