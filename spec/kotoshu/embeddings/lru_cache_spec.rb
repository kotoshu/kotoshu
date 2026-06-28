# frozen_string_literal: true

require "kotoshu"

RSpec.describe Kotoshu::Embeddings::LruCache do
  describe "#initialize" do
    it "defaults max_size to 1000" do
      expect(described_class.new.max_size).to eq(1000)
    end

    it "honors a custom max_size" do
      expect(described_class.new(max_size: 5).max_size).to eq(5)
    end

    it "defaults ttl to nil (no expiry)" do
      expect(described_class.new.ttl).to be_nil
    end

    it "honors a custom ttl" do
      expect(described_class.new(ttl: 60).ttl).to eq(60)
    end

    it "starts empty with zero hits and misses" do
      cache = described_class.new
      expect(cache).to be_empty
      expect(cache.hits).to eq(0)
      expect(cache.misses).to eq(0)
    end
  end

  describe "#[] and #[]=" do
    it "stores and retrieves a value" do
      cache = described_class.new(max_size: 5)
      cache["a"] = 1
      expect(cache["a"]).to eq(1)
    end

    it "returns nil for a missing key" do
      expect(described_class.new["missing"]).to be_nil
    end

    it "overwrites an existing value without growing the cache" do
      cache = described_class.new(max_size: 2)
      cache["a"] = 1
      cache["a"] = 2
      expect(cache.size).to eq(1)
      expect(cache["a"]).to eq(2)
    end

    it "returns the stored value from []=" do
      cache = described_class.new
      expect(cache["a"] = "value").to eq("value")
    end
  end

  describe "LRU eviction at capacity" do
    let(:cache) { described_class.new(max_size: 3) }

    it "evicts the least recently used key when capacity is exceeded" do
      cache["a"] = 1
      cache["b"] = 2
      cache["c"] = 3
      # Touch "a" so "b" becomes LRU
      cache["a"]
      cache["d"] = 4

      expect(cache.keys).to contain_exactly("a", "c", "d")
      expect(cache["b"]).to be_nil
    end

    it "treats a write to an existing key as a use, not an eviction trigger" do
      cache["a"] = 1
      cache["b"] = 2
      cache["c"] = 3
      cache["a"] = 10 # update, not insert
      expect(cache.size).to eq(3)
      expect(cache["a"]).to eq(10)
    end

    it "evicts in insertion order when no reads occur" do
      cache["a"] = 1
      cache["b"] = 2
      cache["c"] = 3
      cache["d"] = 4

      expect(cache["a"]).to be_nil
      expect(cache.keys).to eq(%w[d c b])
    end

    it "honors max_size of 1 (always keeps the latest)" do
      single = described_class.new(max_size: 1)
      single["a"] = 1
      single["b"] = 2
      expect(single.size).to eq(1)
      expect(single["a"]).to be_nil
      expect(single["b"]).to eq(2)
    end
  end

  describe "access order tracking" do
    let(:cache) { described_class.new(max_size: 3) }

    it "promotes the most recently read key to mru" do
      cache["a"] = 1
      cache["b"] = 2
      cache["c"] = 3
      cache["a"] # read — promote "a" to MRU

      expect(cache.mru.first).to eq("a")
      expect(cache.lru.first).to eq("b")
    end

    it "reports lru/mru as nil when empty" do
      empty_cache = described_class.new
      expect(empty_cache.lru).to be_nil
      expect(empty_cache.mru).to be_nil
    end

    it "returns key-value pairs from lru/mru" do
      cache["a"] = 1
      cache["b"] = 2
      expect(cache.mru).to eq(["b", 2])
      expect(cache.lru).to eq(["a", 1])
    end
  end

  describe "#key?" do
    it "returns true for an existing key" do
      cache = described_class.new
      cache["a"] = 1
      expect(cache.key?("a")).to be true
    end

    it "returns false for a missing key" do
      expect(described_class.new.key?("missing")).to be false
    end

    it "returns false for a deleted key" do
      cache = described_class.new
      cache["a"] = 1
      cache.delete("a")
      expect(cache.key?("a")).to be false
    end
  end

  describe "#delete" do
    it "removes the key" do
      cache = described_class.new
      cache["a"] = 1
      expect(cache.delete("a")).to eq(1)
      expect(cache).to be_empty
    end

    it "returns nil when deleting a missing key" do
      expect(described_class.new.delete("nope")).to be_nil
    end
  end

  describe "#clear" do
    it "removes all entries" do
      cache = described_class.new
      cache["a"] = 1
      cache["b"] = 2
      expect(cache.clear).to be(cache)
      expect(cache).to be_empty
      expect(cache.keys).to eq([])
    end
  end

  describe "#size and #empty?" do
    it "tracks size as entries are added" do
      cache = described_class.new(max_size: 5)
      expect(cache.size).to eq(0)
      cache["a"] = 1
      expect(cache.size).to eq(1)
      cache["b"] = 2
      expect(cache.size).to eq(2)
    end

    it "reflects eviction in size" do
      cache = described_class.new(max_size: 2)
      cache["a"] = 1
      cache["b"] = 2
      cache["c"] = 3
      expect(cache.size).to eq(2)
    end
  end

  describe "#keys and #values" do
    it "returns keys in MRU-first order" do
      cache = described_class.new(max_size: 5)
      cache["a"] = 1
      cache["b"] = 2
      cache["c"] = 3
      expect(cache.keys).to eq(%w[c b a])
    end

    it "returns values in MRU-first order" do
      cache = described_class.new(max_size: 5)
      cache["a"] = 1
      cache["b"] = 2
      cache["c"] = 3
      expect(cache.values).to eq([3, 2, 1])
    end

    it "returns a defensive copy of keys" do
      cache = described_class.new
      cache["a"] = 1
      keys = cache.keys
      keys << "tampered"
      expect(cache.keys).to eq(%w[a])
    end
  end

  describe "#stats" do
    it "reports size, max_size, ttl, and hit/miss counts" do
      cache = described_class.new(max_size: 5, ttl: 30)
      stats = cache.stats
      expect(stats).to include(
        size: 0, max_size: 5, hits: 0, misses: 0, hit_rate: 0.0, ttl: 30
      )
    end

    it "counts hits on cache reads" do
      cache = described_class.new
      cache["a"] = 1
      cache["a"]
      cache["a"]
      expect(cache.stats[:hits]).to eq(2)
    end

    it "computes hit_rate as hits / (hits + misses)" do
      cache = described_class.new
      cache["a"] = 1
      cache["a"] # hit
      cache["missing"] # miss (returns nil, no increment)
      # reads of missing keys do not increment misses (only TTL-expired reads do)
      expect(cache.stats[:hit_rate]).to eq(1.0)
    end
  end

  describe "#fetch (cache-aside)" do
    it "returns the cached value when present" do
      cache = described_class.new
      cache["a"] = 1
      expect(cache.fetch("a") { raise "should not yield" }).to eq(1)
    end

    it "computes, stores, and returns the block result on miss" do
      cache = described_class.new
      result = cache.fetch("computed") { "computed-value" }
      expect(result).to eq("computed-value")
      expect(cache["computed"]).to eq("computed-value")
    end

    it "only invokes the block once per key" do
      cache = described_class.new
      invocations = 0
      3.times { cache.fetch("k") { invocations += 1 } }
      expect(invocations).to eq(1)
    end
  end

  describe "TTL expiry", :slow do
    it "treats an expired entry as missing on read" do
      cache = described_class.new(max_size: 5, ttl: 1)
      cache["short"] = "lived"
      sleep 1.1
      expect(cache["short"]).to be_nil
    end

    it "counts an expired read as a miss" do
      cache = described_class.new(max_size: 5, ttl: 1)
      cache["short"] = "lived"
      sleep 1.1
      cache["short"]
      expect(cache.misses).to eq(1)
    end

    it "physically evicts the entry on expired read" do
      cache = described_class.new(max_size: 5, ttl: 1)
      cache["short"] = "lived"
      sleep 1.1
      cache["short"]
      expect(cache.key?("short")).to be false
      expect(cache.size).to eq(0)
    end

    it "returns false from key? for an expired entry" do
      cache = described_class.new(max_size: 5, ttl: 1)
      cache["short"] = "lived"
      sleep 1.1
      expect(cache.key?("short")).to be false
    end
  end
end
