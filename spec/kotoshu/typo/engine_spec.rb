# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Typo::Engine do
  # A real native-engine stand-in answering typo_suggest with the
  # hashes the Rust binding returns (no doubles).
  class NativeTypoStub
    def initialize(rows)
      @rows = rows
    end

    def typo_suggest(_word)
      @rows
    end
  end

  describe "#suggest" do
    it "maps native rows to typo_retrieval suggestions with clamped confidence" do
      native = NativeTypoStub.new(
        [{ "word" => "hello", "score" => 0.9 }, { "word" => "hell", "score" => -0.2 }]
      )
      engine = described_class.new(native, language: "en")
      result = engine.suggest("helo")
      expect(result.map(&:word)).to eq(%w[hello hell])
      expect(result.map(&:source).uniq).to eq(%w[typo_retrieval])
      expect(result.map(&:confidence)).to eq([0.9, 0.0])
    end

    it "honors the limit and returns an empty set for no rows" do
      native = NativeTypoStub.new([{ "word" => "a", "score" => 0.5 },
                                   { "word" => "b", "score" => 0.4 }])
      engine = described_class.new(native, language: "en")
      expect(engine.suggest("x", max_suggestions: 1).map(&:word)).to eq(%w[a])
      expect(described_class.new(NativeTypoStub.new([]), language: "en").suggest("x")).to be_empty
    end
  end

  describe ".for" do
    it "never raises on an unresolvable chain" do
      result = described_class.for(
        "en",
        configuration: Kotoshu::Configuration.new(cache_path: "/nonexistent-kotoshu-typo")
      )
      # Either the layer is absent (nil) or artifacts resolved on a
      # machine with a warm cache — both are valid silent outcomes.
      expect(result.nil? || result.is_a?(described_class)).to be(true)
    end
  end
end
