# frozen_string_literal: true

require "kotoshu"

# Direct spec for the Suggestions::Context value object.
#
# Context is the plain value object strategies receive. It is not a
# lutaml-model — just a struct-like carrier — so the spec covers the
# constructor, option accessor, predicate, and inspect/to_s rendering.
#
# Per the no-double rule, the dictionary is a lightweight Struct stand-in
# rather than a verified double. Context is duck-typed; it never sends
# messages to the dictionary, so any object suffices.
RSpec.describe Kotoshu::Suggestions::Context do
  FakeDictionary = Struct.new(:name)

  let(:dictionary) { FakeDictionary.new("test") }
  let(:context) do
    described_class.new(
      word: "helo",
      dictionary: dictionary,
      max_results: 5,
      min_distance: 1,
      case_sensitive: true
    )
  end

  describe "#initialize" do
    it "exposes word, dictionary, max_results, and options as readers" do
      ctx = described_class.new(
        word: "helo",
        dictionary: dictionary,
        max_results: 3,
        custom_option: 42
      )
      expect(ctx.word).to eq("helo")
      expect(ctx.dictionary).to be(dictionary)
      expect(ctx.max_results).to eq(3)
      expect(ctx.options).to eq(custom_option: 42)
    end

    it "defaults max_results to 10" do
      ctx = described_class.new(word: "x", dictionary: dictionary)
      expect(ctx.max_results).to eq(10)
    end

    it "defaults options to an empty hash when no extra kwargs are given" do
      ctx = described_class.new(word: "x", dictionary: dictionary)
      expect(ctx.options).to eq({})
    end

    it "freezes nothing — callers may mutate options hash if they must" do
      # The contract is: pass context in, strategies read. We document
      # (not enforce) immutability — this test pins current behaviour
      # so a future freeze-on-construct change is a conscious decision.
      ctx = described_class.new(word: "x", dictionary: dictionary, foo: 1)
      expect(ctx.options).not_to be_frozen
    end
  end

  describe "#option" do
    it "returns the stored value when present" do
      expect(context.option(:min_distance)).to eq(1)
      expect(context.option(:case_sensitive)).to be true
    end

    it "returns the supplied default when the option is absent" do
      expect(context.option(:missing, :fallback)).to eq(:fallback)
    end

    it "returns nil when the option is absent and no default is given" do
      expect(context.option(:missing)).to be_nil
    end

    it "returns the stored value even when it is falsy (nil/false)" do
      ctx = described_class.new(word: "x", dictionary: dictionary,
                                enabled: false, value: nil)
      expect(ctx.option(:enabled)).to be(false)
      expect(ctx.option(:value)).to be_nil
    end
  end

  describe "#has_option?" do
    it "is true for an option that was passed" do
      expect(context.has_option?(:min_distance)).to be true
      expect(context.has_option?(:case_sensitive)).to be true
    end

    it "is false for an option that was not passed" do
      expect(context.has_option?(:missing)).to be false
    end

    it "is true even when the stored value is nil" do
      ctx = described_class.new(word: "x", dictionary: dictionary, value: nil)
      expect(ctx.has_option?(:value)).to be true
    end
  end

  describe "#inspect / #to_s" do
    it "renders a readable summary including word and max_results" do
      expect(context.inspect).to include("helo")
      expect(context.inspect).to include("5")
    end

    it "is aliased as to_s" do
      expect(context.to_s).to eq(context.inspect)
    end

    it "does not leak the dictionary object_id into the summary" do
      # Pin the format: a future change might surface the dictionary
      # for debugging, but the current contract is "word + max_results
      # only" so log lines stay compact.
      expect(context.inspect).to match(/\AContext\(word: 'helo', max_results: 5\)\z/)
    end
  end

  describe "integration with Generator" do
    # Smoke-level: Context is constructed by Generator and consumed by
    # every strategy. Pin the field names so a rename breaks loudly.
    it "exposes the three fields strategies read" do
      expect(context.word).to eq("helo")
      expect(context.dictionary).to be(dictionary)
      expect(context.max_results).to eq(5)
    end
  end
end
