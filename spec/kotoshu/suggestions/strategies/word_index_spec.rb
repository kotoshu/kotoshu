# frozen_string_literal: true

require "kotoshu"

# Direct spec for Suggestions::Strategies::WordIndex — the per-sweep
# lookup structure that replaced KeyboardProximityStrategy's whole-list
# scan per keyboard variant. The semantics here are the historical
# find_word semantics, frozen: exact (lowercase) membership returns the
# input string, otherwise the first-in-list-order word sharing the
# lowercase form wins, and nil/empty finds nothing.
RSpec.describe Kotoshu::Suggestions::Strategies::WordIndex do
  describe ".build" do
    it "indexes every listed word for exact lookup" do
      index = described_class.build(%w[hello help])
      expect(index.find("hello")).to eq("hello")
    end

    it "is empty over an empty word list" do
      index = described_class.build([])
      expect(index.find("hello")).to be_nil
    end
  end

  describe "#find" do
    it "returns the input string when the lowercase form is a word as-is" do
      index = described_class.build(%w[hello])
      # The exact branch answers membership of the LOWERCASED input and
      # returns the input verbatim — a quirk of the original find_word,
      # kept so variant strings surface unchanged.
      expect(index.find("HELLO")).to eq("HELLO")
    end

    it "prefers the exact branch over the case-insensitive branch" do
      # "hello" is listed as-is (exact branch hits), so the input wins
      # even though "Hello" appears earlier in list order.
      index = described_class.build(%w[Hello hello])
      expect(index.find("hello")).to eq("hello")
      expect(index.find("HeLLo")).to eq("HeLLo")
    end

    it "falls back to the first-in-list-order word with the same lowercase form" do
      # No listed word is "apple" as-is, so the case-insensitive branch
      # runs — first in list order among the case variants.
      index = described_class.build(%w[Apple APPLE aPpLe])
      expect(index.find("apple")).to eq("Apple")
      expect(index.find("APPLY")).to be_nil
    end

    it "keeps first-in-list-order among same-lowercase words regardless of query case" do
      index = described_class.build(%w[APPLE Apple])
      expect(index.find("apple")).to eq("APPLE")
      expect(index.find("aPpLe")).to eq("APPLE")
    end

    it "matches a case-insensitive form when only a cased entry exists" do
      index = described_class.build(%w[Hello])
      expect(index.find("hello")).to eq("Hello")
    end

    it "returns nil for a word absent from the list" do
      index = described_class.build(%w[hello])
      expect(index.find("help")).to be_nil
    end

    it "returns nil for empty and nil input" do
      index = described_class.build(%w[hello])
      expect(index.find("")).to be_nil
      expect(index.find(nil)).to be_nil
    end
  end
end
