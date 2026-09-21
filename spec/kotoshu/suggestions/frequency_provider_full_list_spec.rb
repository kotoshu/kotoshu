# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Suggestions::FrequencyProvider, :full_list_ranks do
  FullListFakeCache = Struct.new(:payload, keyword_init: true) do
    def cached_data?(_code) = true
    def load_cached(_code) = payload
  end

  let(:payload) do
    {
      tiers: {
        top_50: Set.new(%w[der die]),
        top_200: Set.new(%w[der die und]),
        top_1000: Set.new(%w[der die und in])
      },
      full_list: %w[der die und in den],
      ranks: { "der" => 1, "die" => 2, "und" => 3, "in" => 4, "den" => 5 }
    }
  end

  let(:provider) { described_class.new(frequency_cache: FullListFakeCache.new(payload: payload)) }

  it "exposes full_list_for from the cached Kelly/wiki file" do
    expect(provider.full_list_for("de")).to eq(%w[der die und in den])
  end

  it "exposes ranks_for downcased" do
    expect(provider.ranks_for("de")["der"]).to eq(1)
  end

  it "returns empty full_list when only tiers exist" do
    thin = described_class.new(
      frequency_cache: FullListFakeCache.new(
        payload: { tiers: payload[:tiers], full_list: [], ranks: {} }
      )
    )
    expect(thin.full_list_for("de")).to eq([])
  end
end
