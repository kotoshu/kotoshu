# frozen_string_literal: true

require_relative "../../../lib/kotoshu/cache/cache"
require_relative "../../../lib/kotoshu/cache/lookup_cache"

RSpec.describe Kotoshu::Cache::LookupCache do
  let(:cache) { described_class.new(max_size: 100) }

  describe "#initialize" do
    it "creates cache with default max size" do
      c = described_class.new
      expect(c.max_size).to eq(1000)
    end

    it "creates cache with custom max size" do
      c = described_class.new(max_size: 500)
      expect(c.max_size).to eq(500)
    end
  end

  describe "#fetch" do
    it "stores and retrieves values" do
      cache.fetch("test_key", "computed_value")
      result = cache.fetch("test_key", "should_not_compute")

      expect(result).to eq("computed_value")
    end

    it "calls block only on cache miss" do
      call_count = 0

      3.times do
        cache.fetch("counter") do
          call_count += 1
          call_count
        end
      end

      expect(call_count).to eq(1)
    end

    it "returns cached value without executing block" do
      cache.fetch("key", "first_value")
      result = cache.fetch("key") { raise "Should not be called" }

      expect(result).to eq("first_value")
    end
  end

  describe "#write" do
    it "stores a value" do
      cache.write("key", "value")
      expect(cache.read("key")).to eq("value")
    end

    it "overwrites existing value" do
      cache.write("key", "value1")
      cache.write("key", "value2")
      expect(cache.read("key")).to eq("value2")
    end
  end

  describe "#read" do
    it "returns nil for missing key" do
      expect(cache.read("nonexistent")).to be_nil
    end

    it "returns stored value" do
      cache.write("key", "value")
      expect(cache.read("key")).to eq("value")
    end
  end

  describe "#delete" do
    it "removes a key from cache" do
      cache.write("key", "value")
      cache.delete("key")
      expect(cache.read("key")).to be_nil
    end

    it "does nothing for nonexistent key" do
      expect { cache.delete("nonexistent") }.not_to raise_error
    end
  end

  describe "#clear" do
    it "removes all entries" do
      cache.write("key1", "value1")
      cache.write("key2", "value2")
      cache.clear

      expect(cache.read("key1")).to be_nil
      expect(cache.read("key2")).to be_nil
    end
  end

  describe "#key?" do
    it "returns true for existing key" do
      cache.write("key", "value")
      expect(cache.key?("key")).to be true
    end

    it "returns false for missing key" do
      expect(cache.key?("nonexistent")).to be false
    end
  end

  describe "#size" do
    it "returns number of entries" do
      expect(cache.size).to eq(0)

      5.times { |i| cache.write("key#{i}", "value#{i}") }
      expect(cache.size).to eq(5)
    end
  end

  describe "LRU eviction" do
    it "evicts least recently used entries when max size reached" do
      small_cache = described_class.new(max_size: 3)

      small_cache.write("key1", "value1")
      small_cache.write("key2", "value2")
      small_cache.write("key3", "value3")

      # All three should be present
      expect(small_cache.key?("key1")).to be true
      expect(small_cache.key?("key2")).to be true
      expect(small_cache.key?("key3")).to be true

      # Add fourth entry - should evict key1
      small_cache.write("key4", "value4")

      expect(small_cache.key?("key1")).to be false
      expect(small_cache.key?("key2")).to be true
      expect(small_cache.key?("key3")).to be true
      expect(small_cache.key?("key4")).to be true
    end

    it "updates LRU order on read" do
      small_cache = described_class.new(max_size: 3)

      small_cache.write("key1", "value1")
      small_cache.write("key2", "value2")
      small_cache.write("key3", "value3")

      # Access key1 to make it more recent
      small_cache.read("key1")

      # Add fourth entry - should evict key2 (least recently used)
      small_cache.write("key4", "value4")

      expect(small_cache.key?("key1")).to be true
      expect(small_cache.key?("key2")).to be false
      expect(small_cache.key?("key3")).to be true
      expect(small_cache.key?("key4")).to be true
    end
  end

  describe "#stats" do
    it "returns cache statistics" do
      stats = cache.stats

      expect(stats).to include(:hits, :misses, :size, :hit_rate)
      expect(stats[:hits]).to eq(0)
      expect(stats[:misses]).to eq(0)
      expect(stats[:size]).to eq(0)
    end

    it "tracks hits and misses" do
      cache.write("key", "value")

      cache.read("key")      # hit
      cache.read("missing")  # miss

      stats = cache.stats
      expect(stats[:hits]).to eq(1)
      expect(stats[:misses]).to eq(1)
      expect(stats[:hit_rate]).to eq(0.5)
    end
  end

  describe "#reset_stats" do
    it "resets statistics counters" do
      cache.write("key", "value")
      cache.read("key")      # hit
      cache.read("missing")  # miss

      cache.reset_stats
      stats = cache.stats

      expect(stats[:hits]).to eq(0)
      expect(stats[:misses]).to eq(0)
    end
  end
end
