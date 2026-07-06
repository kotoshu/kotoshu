# frozen_string_literal: true

require "kotoshu"

# Direct spec for Algorithms::EditDistance.
#
# The Damerau-Levenshtein algorithm is the core of EditDistanceStrategy
# and several other places that need fuzzy string match scoring. It was
# previously a private method on the strategy and tested via send; the
# extraction to its own module (TODO 56 T5 architecture cleanup) lets
# the algorithm be reused and tested directly.
RSpec.describe Kotoshu::Algorithms::EditDistance do
  describe ".distance" do
    it "returns 0 for identical strings" do
      expect(described_class.distance("hello", "hello")).to eq(0)
    end

    it "returns the other string's length when one is empty" do
      expect(described_class.distance("", "hello")).to eq(5)
      expect(described_class.distance("hello", "")).to eq(5)
      expect(described_class.distance("", "")).to eq(0)
    end

    it "counts single-character substitution as 1" do
      expect(described_class.distance("cat", "cut")).to eq(1)
      expect(described_class.distance("hello", "hallo")).to eq(1)
    end

    it "counts single-character insertion as 1" do
      expect(described_class.distance("helo", "hello")).to eq(1)
      expect(described_class.distance("cat", "coat")).to eq(1)
    end

    it "counts single-character deletion as 1" do
      expect(described_class.distance("hello", "helo")).to eq(1)
      expect(described_class.distance("book", "boo")).to eq(1)
    end

    it "counts adjacent-character transposition as 1 (Damerau extension)" do
      expect(described_class.distance("wrold", "world")).to eq(1)
      expect(described_class.distance("teh", "the")).to eq(1)
    end

    it "sums multiple operations for distant strings" do
      expect(described_class.distance("kitten", "sitting")).to eq(3)
      expect(described_class.distance("hello", "help")).to eq(2)
    end
  end

  describe ".distance_with_threshold" do
    it "returns the distance when it is within the threshold" do
      expect(described_class.distance_with_threshold("hello", "hallo", 2)).to eq(1)
    end

    it "returns the distance when it equals the threshold" do
      expect(described_class.distance_with_threshold("hello", "hello", 0)).to eq(0)
    end

    it "returns nil when the distance exceeds the threshold" do
      expect(described_class.distance_with_threshold("kitten", "sitting", 2)).to be_nil
    end
  end
end
