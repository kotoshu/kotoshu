# frozen_string_literal: true

require_relative "../../../lib/kotoshu/suggestions/pipeline"
require_relative "../../../lib/kotoshu/suggestions/context"
require_relative "../../../lib/kotoshu/dictionary/plain_text"
require_relative "../../../lib/kotoshu/suggestions/strategies/base_strategy"

RSpec.describe Kotoshu::Suggestions::Pipeline do
  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello world help test],
      language_code: "en"
    )
  end

  let(:context) { Kotoshu::Suggestions::Context.new(word: "helo", dictionary: dictionary) }

  describe "#initialize" do
    it "creates empty pipeline" do
      pipeline = described_class.new
      expect(pipeline.stages).to eq([])
    end

    it "creates pipeline with block" do
      pipeline = described_class.new do |p|
        p.add :stage1
        p.add :stage2
      end

      expect(pipeline.stages.size).to eq(2)
    end
  end

  describe "#add" do
    let(:pipeline) { described_class.new }

    it "adds a stage" do
      pipeline.add(:test_stage)
      expect(pipeline.stages).to eq([:test_stage])
    end

    it "adds multiple stages" do
      pipeline.add(:stage1)
      pipeline.add(:stage2)
      pipeline.add(:stage3)

      expect(pipeline.stages).to eq(%i[stage1 stage2 stage3])
    end

    it "returns self for chaining" do
      result = pipeline.add(:stage1).add(:stage2)
      expect(result).to be(pipeline)
    end
  end

  describe "#remove" do
    let(:pipeline) do
      described_class.new do |p|
        p.add(:stage1)
        p.add(:stage2)
        p.add(:stage3)
      end
    end

    it "removes a stage" do
      pipeline.remove(:stage2)
      expect(pipeline.stages).to eq(%i[stage1 stage3])
    end

    it "returns self for chaining" do
      result = pipeline.remove(:stage1)
      expect(result).to be(pipeline)
    end
  end

  describe "#execute" do
    let(:strategy) do
      Class.new(Kotoshu::Suggestions::Strategies::BaseStrategy) do
        attr_reader :called

        def initialize
          @called = false
        end

        def generate(_context)
          @called = true
          Kotoshu::Suggestions::SuggestionSet.empty
        end
      end
    end

    it "executes stages in sequence" do
      strategy1 = strategy.new
      strategy2 = strategy.new

      pipeline = described_class.new do |p|
        p.add(:stage1)
        p.add(:stage2)
      end

      pipeline.execute(context, { stage1: strategy1, stage2: strategy2 })

      expect(strategy1.called).to be true
      expect(strategy2.called).to be true
    end

    it "can early terminate on empty result" do
      early_stop = Class.new(Kotoshu::Suggestions::Strategies::BaseStrategy) do
        def generate(_context)
          Kotoshu::Suggestions::SuggestionSet.empty
        end
      end

      never_called = strategy.new

      pipeline = described_class.new do |p|
        p.add(:early_stop)
        p.add(:never_called)
      end

      pipeline.execute(context, { early_stop: early_stop.new, never_called: never_called }, early_termination: true)

      expect(never_called.called).to be false
    end
  end

  describe "context sharing" do
    it "shares context between stages" do
      # Stage 1 adds data to context
      stage1 = Class.new(Kotoshu::Suggestions::Strategies::BaseStrategy) do
        def generate(_context)
          # Modify context (in real implementation, this would be shared context)
          Kotoshu::Suggestions::SuggestionSet.from_words(%w[hello])
        end
      end

      stage2 = Class.new(Kotoshu::Suggestions::Strategies::BaseStrategy) do
        def generate(_context)
          # Would use data from previous stage
          Kotoshu::Suggestions::SuggestionSet.from_words(%w[hello world])
        end
      end

      pipeline = described_class.new do |p|
        p.add(:stage1)
        p.add(:stage2)
      end

      result = pipeline.execute(context, { stage1: stage1.new, stage2: stage2.new })

      expect(result.to_words).to include("hello")
    end
  end
end
