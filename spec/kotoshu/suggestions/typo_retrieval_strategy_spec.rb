# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Suggestions::Strategies::TypoRetrievalStrategy do
  # A real engine stand-in (no doubles): answers #suggest with real
  # SuggestionSets the way Kotoshu::Typo::Engine does.
  class RecordingTypoEngine
    attr_reader :asked

    def initialize(rows)
      @rows = rows
      @asked = []
    end

    def suggest(word, max_suggestions: nil)
      @asked << [word, max_suggestions]
      limit = max_suggestions || @rows.size
      Kotoshu::Suggestions::SuggestionSet.new(@rows.first(limit), max_size: limit, ranked: true)
    end
  end

  def row(word, confidence = 0.7)
    Kotoshu::Suggestions::Suggestion.new(
      word: word, distance: 0, confidence: confidence, source: :typo_retrieval
    )
  end

  let(:rows) { [row("hello", 0.9), row("hell", 0.6)] }
  let(:engine) { RecordingTypoEngine.new(rows) }
  let(:strategy) { described_class.new(engine: engine, max_results: 5) }

  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello world help held hell bell well tell shell yellow],
      language_code: "en"
    )
  end

  def context_for(word)
    Kotoshu::Suggestions::Context.new(word: word, dictionary: dictionary)
  end

  describe "#generate" do
    it "returns the engine's rows as a suggestion set" do
      result = strategy.generate(context_for("helo"))
      expect(result.map(&:word)).to eq(%w[hello hell])
      expect(result.map(&:source).uniq).to eq(%w[typo_retrieval])
    end

    it "passes the configured max_results to the engine" do
      strategy.generate(context_for("helo"))
      expect(engine.asked).to eq([["helo", 5]])
    end

    it "returns an empty set when the strategy is disabled" do
      disabled = described_class.new(engine: engine, enabled: false)
      expect(disabled.generate(context_for("helo"))).to be_empty
    end
  end

  describe "#handles?" do
    it "handles a misspelling when enabled with an engine" do
      expect(strategy.handles?(context_for("helo"))).to be(true)
    end

    it "does not handle an empty word" do
      expect(strategy.handles?(context_for(""))).to be(false)
    end

    it "does not handle when disabled" do
      disabled = described_class.new(engine: engine, enabled: false)
      expect(disabled.handles?(context_for("helo"))).to be(false)
    end
  end

  describe "#skip_when_confident?" do
    it "never lets a confident base set skip the retrieval" do
      expect(strategy.skip_when_confident?).to be(false)
    end
  end
end
