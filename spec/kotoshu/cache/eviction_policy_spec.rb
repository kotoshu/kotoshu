# frozen_string_literal: true

require "kotoshu"

RSpec.describe Kotoshu::Cache::EvictionPolicy do
  let(:entry) do
    lambda do |path, size, cached_at|
      { path: path, size: size, cached_at: cached_at }
    end
  end

  describe "#initialize" do
    it "accepts a non-negative max_size" do
      expect { described_class.new(max_size: 0) }.not_to raise_error
      expect { described_class.new(max_size: 1_048_576) }.not_to raise_error
    end

    it "rejects a negative max_size" do
      expect { described_class.new(max_size: -1) }.to raise_error(ArgumentError)
    end

    it "coerces stringy numerics to integer" do
      policy = described_class.new(max_size: "1024")
      expect(policy.max_size).to eq(1024)
    end
  end

  describe "#plan" do
    it "returns an empty evict list when total is at or under the cap" do
      policy = described_class.new(max_size: 1_000)
      entries = [
        entry.call("a", 400, "2026-01-01T00:00:00Z"),
        entry.call("b", 500, "2026-02-01T00:00:00Z")
      ]
      plan = policy.plan(entries)

      expect(plan[:evict]).to eq([])
      expect(plan[:keep].size).to eq(2)
      expect(plan[:bytes_reclaimed]).to eq(0)
    end

    it "evicts oldest-first until total fits the cap" do
      policy = described_class.new(max_size: 1_000)
      entries = [
        entry.call("old",    400, "2026-01-01T00:00:00Z"),
        entry.call("medium", 400, "2026-02-01T00:00:00Z"),
        entry.call("new",    400, "2026-03-01T00:00:00Z")
      ]
      plan = policy.plan(entries)

      # total = 1200, cap = 1000 → evict the oldest entry (400), new total = 800.
      expect(plan[:evict].map { |e| e[:path] }).to eq(["old"])
      expect(plan[:bytes_reclaimed]).to eq(400)
      expect(plan[:keep].map { |e| e[:path] }).to eq(%w[medium new])
    end

    it "evicts multiple oldest entries when one is not enough" do
      policy = described_class.new(max_size: 500)
      entries = [
        entry.call("oldest", 400, "2026-01-01T00:00:00Z"),
        entry.call("older",  400, "2026-02-01T00:00:00Z"),
        entry.call("newer",  400, "2026-03-01T00:00:00Z")
      ]
      plan = policy.plan(entries)

      # total = 1200, cap = 500 → evict oldest + older (800), keep newer (400).
      expect(plan[:evict].map { |e| e[:path] }).to eq(%w[oldest older])
      expect(plan[:bytes_reclaimed]).to eq(800)
      expect(plan[:keep].map { |e| e[:path] }).to eq(["newer"])
    end

    it "handles an empty entry list" do
      policy = described_class.new(max_size: 100)
      plan = policy.plan([])

      expect(plan[:evict]).to eq([])
      expect(plan[:keep]).to eq([])
      expect(plan[:bytes_reclaimed]).to eq(0)
    end

    it "treats nil cached_at as oldest (sorted first for eviction)" do
      policy = described_class.new(max_size: 0)
      entries = [
        entry.call("with-timestamp", 100, "2026-03-01T00:00:00Z"),
        entry.call("no-timestamp",   100, nil)
      ]
      plan = policy.plan(entries)

      expect(plan[:evict].first[:path]).to eq("no-timestamp")
    end

    it "does not mutate the caller's array" do
      policy = described_class.new(max_size: 0)
      entries = [
        entry.call("a", 100, "2026-01-01T00:00:00Z"),
        entry.call("b", 100, "2026-02-01T00:00:00Z")
      ]
      original = entries.dup
      policy.plan(entries)
      expect(entries).to eq(original)
    end

    it "zero max_size evicts everything" do
      policy = described_class.new(max_size: 0)
      entries = [
        entry.call("a", 100, "2026-01-01T00:00:00Z"),
        entry.call("b", 100, "2026-02-01T00:00:00Z")
      ]
      plan = policy.plan(entries)

      expect(plan[:evict].size).to eq(2)
      expect(plan[:keep]).to eq([])
      expect(plan[:bytes_reclaimed]).to eq(200)
    end
  end
end
