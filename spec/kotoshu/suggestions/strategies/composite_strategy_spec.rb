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

  # Traditional strategy whose top candidate confidence is a knob, so
  # cascade specs can pin exact skip/no-skip boundaries.
  class FixedConfidenceStrategy < Kotoshu::Suggestions::Strategies::BaseStrategy
    def initialize(confidence:)
      super(name: :fixed_confidence)
      @confidence = confidence
    end

    def handles?(_context)
      true
    end

    def generate(context)
      Kotoshu::Suggestions::SuggestionSet.new(
        [create_suggestion("certain", confidence: @confidence)],
        max_size: context.max_results
      )
    end
  end

  # Real rerank-shaped strategy that records every invocation, so
  # specs assert on behavior (was the rerank run?) rather than mock
  # interactions. Mirrors SemanticStrategy's skip_when_confident? opt-in.
  class CountingRerankStrategy < Kotoshu::Suggestions::Strategies::BaseStrategy
    def initialize
      super(name: :counting_rerank)
      @invocations = []
    end

    attr_reader :invocations

    def handles?(_context)
      true
    end

    def skip_when_confident?
      true
    end

    def generate(context)
      @invocations << context.word
      Kotoshu::Suggestions::SuggestionSet.new(
        [create_suggestion("reranked", confidence: 0.99)],
        max_size: context.max_results
      )
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

    it "deduplicates across strategies in a single batch (TODO 56 T5.1)" do
      # Both stubs return "hello" — a cross-strategy duplicate.
      a = StubStrategy.new(name: :a, words: %w[hello])
      b = StubStrategy.new(name: :b, words: %w[hello])
      composite = described_class.new(name: :pipeline, strategies: [a, b])

      result = composite.generate(context)

      expect(result.size).to eq(1)
      # Batch merge means dedup runs once over the full candidate pool,
      # so duplicates_removed reflects the cross-strategy total.
      expect(result.duplicates_removed).to eq(1)
    end
  end

  describe "confidence cascade" do
    # The cascade skips skippable strategies (skip_when_confident?,
    # i.e. the semantic rerank) when the traditional pool is already
    # confident. See Suggestions::SemanticCascade and TODO.impl/70.

    def composite_with(traditional:, rerank:, threshold: nil)
      described_class.new(
        name: :pipeline,
        strategies: [traditional, rerank],
        semantic_cascade_threshold: threshold
      )
    end

    it "runs the rerank at the default threshold even for confidence 1.0" do
      # Composite confidence legitimately reaches exactly 1.0, so the
      # default threshold is the always-rerank sentinel — never skips.
      traditional = FixedConfidenceStrategy.new(confidence: 1.0)
      rerank = CountingRerankStrategy.new
      composite = composite_with(
        traditional: traditional, rerank: rerank, threshold: 1.0
      )

      result = composite.generate(context)

      expect(rerank.invocations).to eq(["helo"])
      expect(result.include?("reranked")).to be true
    end

    it "follows the process Configuration when no threshold kwarg is given" do
      Kotoshu.configuration.semantic_cascade_threshold = 0.0
      begin
        traditional = FixedConfidenceStrategy.new(confidence: 0.5)
        rerank = CountingRerankStrategy.new
        composite = described_class.new(
          name: :pipeline, strategies: [traditional, rerank]
        )

        composite.generate(context)

        expect(rerank.invocations).to be_empty
      ensure
        Kotoshu::Configuration.reset
      end
    end

    context "at threshold 0.0 (never rerank)" do
      it "skips the rerank whenever the traditional pool has candidates" do
        traditional = FixedConfidenceStrategy.new(confidence: 0.1)
        rerank = CountingRerankStrategy.new
        composite = composite_with(
          traditional: traditional, rerank: rerank, threshold: 0.0
        )

        result = composite.generate(context)

        expect(rerank.invocations).to be_empty
        expect(result.to_words).to eq(["certain"])
      end

      it "still runs the rerank when the traditional pool is empty" do
        traditional = StubStrategy.new(name: :empty, words: [])
        rerank = CountingRerankStrategy.new
        composite = composite_with(
          traditional: traditional, rerank: rerank, threshold: 0.0
        )

        result = composite.generate(context)

        expect(rerank.invocations).to eq(["helo"])
        expect(result.to_words).to eq(["reranked"])
      end
    end

    context "at a mid threshold" do
      it "skips exactly when the top traditional confidence is at or above it" do
        at_threshold = FixedConfidenceStrategy.new(confidence: 0.9)
        below_threshold = FixedConfidenceStrategy.new(confidence: 0.89)

        skipped = CountingRerankStrategy.new
        composite_with(
          traditional: at_threshold, rerank: skipped, threshold: 0.9
        ).generate(context)
        expect(skipped.invocations).to be_empty

        ran = CountingRerankStrategy.new
        composite_with(
          traditional: below_threshold, rerank: ran, threshold: 0.9
        ).generate(context)
        expect(ran.invocations).to eq(["helo"])
      end

      it "merges rerank candidates into the pool when not skipped" do
        traditional = FixedConfidenceStrategy.new(confidence: 0.5)
        rerank = CountingRerankStrategy.new
        composite = composite_with(
          traditional: traditional, rerank: rerank, threshold: 0.9
        )

        result = composite.generate(context)

        expect(rerank.invocations).to eq(["helo"])
        expect(result.to_words).to contain_exactly("certain", "reranked")
      end
    end

    describe "debug metrics" do
      after { Kotoshu::Metrics.disable }

      it "counts skips as semantic_cascade_skips" do
        Kotoshu::Metrics.enable

        traditional = FixedConfidenceStrategy.new(confidence: 1.0)
        rerank = CountingRerankStrategy.new
        composite = composite_with(
          traditional: traditional, rerank: rerank, threshold: 0.9
        )
        2.times { composite.generate(context) }

        expect(Kotoshu::Metrics.stats[:semantic_cascade_skips]).to eq(2)
      end

      it "does not count when the rerank runs" do
        Kotoshu::Metrics.enable

        traditional = FixedConfidenceStrategy.new(confidence: 0.5)
        rerank = CountingRerankStrategy.new
        composite = composite_with(
          traditional: traditional, rerank: rerank, threshold: 0.9
        )
        composite.generate(context)

        expect(Kotoshu::Metrics.stats[:semantic_cascade_skips]).to eq(0)
      end

      it "exports the counter in StatsD and Prometheus formats" do
        Kotoshu::Metrics.enable

        traditional = FixedConfidenceStrategy.new(confidence: 1.0)
        rerank = CountingRerankStrategy.new
        composite = composite_with(
          traditional: traditional, rerank: rerank, threshold: 0.9
        )
        composite.generate(context)

        expect(Kotoshu::Metrics.to_statsd)
          .to include("kotoshu.semantic_cascade_skips:1|c")
        expect(Kotoshu::Metrics.to_prometheus)
          .to include("kotoshu_semantic_cascade_skips 1")
      end
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
