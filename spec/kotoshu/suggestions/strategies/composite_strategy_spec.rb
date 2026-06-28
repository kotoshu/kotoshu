# frozen_string_literal: true

require "kotoshu"

# Direct spec for Suggestions::Strategies::CompositeStrategy.
#
# CompositeStrategy is the orchestrator that chains multiple strategies
# through a single #generate entry point. It is the structural backbone
# of the suggestion pipeline (Generator builds one by default).
#
# To exercise #generate we need concrete child strategies. We use the
# real EditDistanceStrategy and PhoneticStrategy rather than doubles
# (per the no-double rule) plus a tiny StubStrategy for filter/chaining
# tests where we need predictable handles? behaviour.
RSpec.describe Kotoshu::Suggestions::Strategies::CompositeStrategy do
  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello help held hell shell yellow],
      language_code: "en"
    )
  end

  let(:context) do
    Kotoshu::Suggestions::Context.new(
      word: "helo",
      dictionary: dictionary,
      max_results: 10
    )
  end

  # Minimal concrete strategy for filter/chain assertions. Real
  # strategies have complex handles? logic; we need a knob.
  class StubStrategy < Kotoshu::Suggestions::Strategies::BaseStrategy
    def initialize(name:, handles: true, words: [])
      super(name: name)
      @handles = handles
      @words = words
    end

    def handles?(_context)
      @handles
    end

    def generate(_context)
      Kotoshu::Suggestions::SuggestionSet.from_words(@words, source: name)
    end
  end

  describe "#initialize" do
    it "accepts a name keyword and exposes it via #name" do
      composite = described_class.new(name: :pipeline)
      expect(composite.name).to eq(:pipeline)
    end

    it "defaults strategies to an empty array" do
      composite = described_class.new(name: :pipeline)
      expect(composite.strategies).to eq([])
    end

    it "accepts an initial strategies array" do
      a = StubStrategy.new(name: :a, words: %w[aaa])
      b = StubStrategy.new(name: :b, words: %w[bbb])
      composite = described_class.new(name: :pipeline, strategies: [a, b])
      expect(composite.strategies).to eq([a, b])
    end
  end

  describe "#add / #<<" do
    it "appends a strategy and returns self for chaining" do
      composite = described_class.new(name: :pipeline)
      a = StubStrategy.new(name: :a)
      result = composite.add(a)
      expect(result).to be(composite)
      expect(composite.strategies).to include(a)
    end

    it "is aliased as <<" do
      composite = described_class.new(name: :pipeline)
      a = StubStrategy.new(name: :a)
      composite << a
      expect(composite.strategies).to include(a)
    end

    it "preserves insertion order across multiple adds" do
      composite = described_class.new(name: :pipeline)
      a = StubStrategy.new(name: :a)
      b = StubStrategy.new(name: :b)
      c = StubStrategy.new(name: :c)
      composite.add(a).add(b).add(c)
      expect(composite.strategies).to eq([a, b, c])
    end
  end

  describe "#remove" do
    it "removes the strategy by identity and returns self" do
      composite = described_class.new(name: :pipeline)
      a = StubStrategy.new(name: :a)
      b = StubStrategy.new(name: :b)
      composite.add(a).add(b)
      result = composite.remove(a)
      expect(result).to be(composite)
      expect(composite.strategies).to eq([b])
    end

    it "is a no-op when the strategy is not present" do
      composite = described_class.new(name: :pipeline)
      a = StubStrategy.new(name: :a)
      missing = StubStrategy.new(name: :missing)
      composite.add(a)
      composite.remove(missing)
      expect(composite.strategies).to eq([a])
    end
  end

  describe "#clear" do
    it "removes all strategies and returns self" do
      composite = described_class.new(
        name: :pipeline,
        strategies: [StubStrategy.new(name: :a), StubStrategy.new(name: :b)]
      )
      result = composite.clear
      expect(result).to be(composite)
      expect(composite.strategies).to eq([])
    end
  end

  describe "#applicable_strategies" do
    it "returns only strategies whose handles? is true" do
      yes = StubStrategy.new(name: :yes, handles: true)
      no = StubStrategy.new(name: :no, handles: false)
      composite = described_class.new(name: :pipeline, strategies: [yes, no])
      expect(composite.applicable_strategies(context)).to eq([yes])
    end

    it "returns an empty array when no strategy handles the context" do
      no = StubStrategy.new(name: :no, handles: false)
      composite = described_class.new(name: :pipeline, strategies: [no])
      expect(composite.applicable_strategies(context)).to eq([])
    end

    it "does not mutate the strategies array" do
      yes = StubStrategy.new(name: :yes, handles: true)
      composite = described_class.new(name: :pipeline, strategies: [yes])
      composite.applicable_strategies(context)
      expect(composite.strategies).to eq([yes])
    end
  end

  describe "#generate" do
    it "merges results from every applicable strategy into one SuggestionSet" do
      a = StubStrategy.new(name: :a, words: %w[hello hell])
      b = StubStrategy.new(name: :b, words: %w[help held])
      composite = described_class.new(name: :pipeline, strategies: [a, b])
      result = composite.generate(context)
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result.to_words).to contain_exactly("hello", "hell", "help", "held")
    end

    it "returns an empty SuggestionSet when no strategy handles the context" do
      no = StubStrategy.new(name: :no, handles: false)
      composite = described_class.new(name: :pipeline, strategies: [no])
      result = composite.generate(context)
      expect(result).to be_empty
    end

    it "honours the context max_results cap" do
      a = StubStrategy.new(name: :a, words: %w[w1 w2 w3 w4 w5])
      composite = described_class.new(name: :pipeline, strategies: [a])
      capped_context = Kotoshu::Suggestions::Context.new(
        word: "x", dictionary: dictionary, max_results: 2
      )
      result = composite.generate(capped_context)
      expect(result.size).to be <= 2
    end

    it "skips strategies that don't handle the context but still runs the rest" do
      yes = StubStrategy.new(name: :yes, handles: true, words: %w[foo])
      no = StubStrategy.new(name: :no, handles: false, words: %w[bar])
      composite = described_class.new(name: :pipeline, strategies: [yes, no])
      result = composite.generate(context)
      expect(result.to_words).to contain_exactly("foo")
    end

    it "with real EditDistanceStrategy returns ranked suggestions for a typo" do
      composite = described_class.new(
        name: :pipeline,
        strategies: [Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new]
      )
      result = composite.generate(context)
      expect(result.size).to be_positive
      # Each entry is a real Suggestion with the strategy name as source
      expect(result.suggestions.first.source).to eq("edit_distance")
    end
  end

  describe "#handles?" do
    it "is true when at least one child handles the context" do
      yes = StubStrategy.new(name: :yes, handles: true)
      composite = described_class.new(name: :pipeline, strategies: [yes])
      expect(composite.handles?(context)).to be true
    end

    it "is false when no child handles the context" do
      no = StubStrategy.new(name: :no, handles: false)
      composite = described_class.new(name: :pipeline, strategies: [no])
      expect(composite.handles?(context)).to be false
    end

    it "is false when the composite is empty" do
      composite = described_class.new(name: :pipeline)
      expect(composite.handles?(context)).to be false
    end
  end

  describe "#size / #count / #any?" do
    it "size reports the number of child strategies" do
      composite = described_class.new(
        name: :pipeline,
        strategies: [StubStrategy.new(name: :a), StubStrategy.new(name: :b)]
      )
      expect(composite.size).to eq(2)
    end

    it "count is aliased as size" do
      composite = described_class.new(
        name: :pipeline,
        strategies: [StubStrategy.new(name: :a)]
      )
      expect(composite.count).to eq(composite.size)
    end

    it "any? is true when at least one strategy is present" do
      composite = described_class.new(name: :pipeline)
      expect(composite.any?).to be false
      composite.add(StubStrategy.new(name: :a))
      expect(composite.any?).to be true
    end
  end

  describe "#each_strategy" do
    it "yields each strategy when a block is given" do
      a = StubStrategy.new(name: :a)
      b = StubStrategy.new(name: :b)
      composite = described_class.new(name: :pipeline, strategies: [a, b])
      yielded = []
      composite.each_strategy { |s| yielded << s }
      expect(yielded).to eq([a, b])
    end

    it "returns an Enumerator when no block is given" do
      composite = described_class.new(name: :pipeline)
      expect(composite.each_strategy).to be_an(Enumerator)
    end
  end

  describe "#sort_by_priority!" do
    it "sorts strategies by ascending priority and returns self" do
      s_low = Kotoshu::Suggestions::Strategies::BaseStrategy.new(name: :low, priority: 10)
      s_high = Kotoshu::Suggestions::Strategies::BaseStrategy.new(name: :high, priority: 90)
      composite = described_class.new(name: :pipeline, strategies: [s_high, s_low])
      result = composite.sort_by_priority!
      expect(result).to be(composite)
      expect(composite.strategies).to eq([s_low, s_high])
    end
  end

  describe "#to_s / #inspect" do
    it "includes the class name, composite name, and child strategy names" do
      composite = described_class.new(
        name: :pipeline,
        strategies: [
          Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new,
          Kotoshu::Suggestions::Strategies::PhoneticStrategy.new
        ]
      )
      expect(composite.to_s).to include("CompositeStrategy")
      expect(composite.to_s).to include("pipeline")
      expect(composite.to_s).to include("edit_distance")
      expect(composite.to_s).to include("phonetic")
    end

    it "is aliased as inspect" do
      composite = described_class.new(name: :pipeline)
      expect(composite.inspect).to eq(composite.to_s)
    end
  end

  describe ".with_defaults" do
    it "returns a CompositeStrategy with name :default" do
      composite = described_class.with_defaults
      expect(composite).to be_a(described_class)
      expect(composite.name).to eq(:default)
    end

    it "starts empty (defaults are added by the caller via #add)" do
      composite = described_class.with_defaults
      expect(composite.strategies).to eq([])
    end

    it "forwards config kwargs to the constructor" do
      composite = described_class.with_defaults(max_results: 7)
      expect(composite.max_results).to eq(7)
    end
  end
end
