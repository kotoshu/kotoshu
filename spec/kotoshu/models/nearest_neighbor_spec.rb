# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Models::NearestNeighbor do
  describe "similarity validation" do
    it "accepts the mathematical cosine range and clamps into the suggestion range" do
      expect(described_class.new(word: "x", similarity: 0.85).similarity).to eq(0.85)

      # Float rounding just past 1.0 clamps down.
      expect(described_class.new(word: "x", similarity: 1.0000000001).similarity).to eq(1.0)

      # True negatives are noise suggestions: clamped to 0.0, not raised.
      neighbor = described_class.new(word: "x", similarity: -0.4)
      expect(neighbor.similarity).to eq(0.0)
      expect(neighbor.distance).to eq(1.0)
    end

    it "raises for values outside the cosine range" do
      expect { described_class.new(word: "x", similarity: 1.5) }
        .to raise_error(ArgumentError, /out of range/)
      expect { described_class.new(word: "x", similarity: -1.5) }
        .to raise_error(ArgumentError, /out of range/)
    end

    it "raises for non-finite similarity" do
      expect { described_class.new(word: "x", similarity: Float::NAN) }
        .to raise_error(ArgumentError, /finite/)
    end
  end
end
