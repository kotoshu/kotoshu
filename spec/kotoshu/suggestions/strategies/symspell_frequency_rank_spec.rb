# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Suggestions::Strategies::SymSpellStrategy, :frequency_ranking do
  # Real frequency provider backed by an in-memory cache — no doubles.
  FreqRankFakeCache = Struct.new(:payload, keyword_init: true) do
    def cached_data?(_code) = true
    def load_cached(_code) = payload
  end

  let(:words) { %w[ihr ihre irrt ehrt hort] }
  let(:ranks) { { "ihr" => 1, "ihre" => 50, "irrt" => 200, "ehrt" => 500, "hort" => 800 } }
  let(:provider) do
    Kotoshu::Suggestions::FrequencyProvider.new(
      frequency_cache: FreqRankFakeCache.new(
        payload: {
          tiers: {
            top_50: Set.new(%w[ihr]),
            top_200: Set.new(%w[ihr ihre]),
            top_1000: Set.new(words)
          },
          full_list: words,
          ranks: ranks
        }
      )
    )
  end

  let(:strategy) do
    described_class.new(
      language_code: "de",
      frequency_provider: provider
    )
  end

  it "indexes the frequency full_list and ranks by (distance, rank)" do
    ctx = Kotoshu::Suggestions::Context.new(word: "ihrt", dictionary: words, max_results: 5)
    result = strategy.generate(ctx)
    expect(result.to_words.first).to eq("ihr")
    expect(result.to_words).to include("ihre")
    expect(result.to_words).not_to include("ihr-t")
  end

  it "accepts an explicit dictionary without a frequency list" do
    strat = described_class.new(dictionary: words)
    ctx = Kotoshu::Suggestions::Context.new(word: "ihrt", dictionary: words, max_results: 5)
    expect(strat.generate(ctx).to_words).to include("ihr")
  end
end
