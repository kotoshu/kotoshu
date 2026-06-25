# frozen_string_literal: true

require_relative "../../../lib/kotoshu/cache/suggestion_cache"

RSpec.describe Kotoshu::Cache::SuggestionCache do
  let(:cache) { described_class.new(max_size: 100) }

  describe "#initialize" do
    it "creates cache with default max size" do
      c = described_class.new
      expect(c.max_size).to eq(5000)
    end

    it "creates cache with custom max size" do
      c = described_class.new(max_size: 100)
      expect(c.max_size).to eq(100)
    end
  end

  describe "#write and #read" do
    it "stores and retrieves suggestions with default max_results" do
      cache.write("helo", %w[hello help])
      result = cache.read("helo")

      expect(result).to eq(%w[hello help])
    end

    it "stores and retrieves suggestions with custom max_results" do
      cache.write("helo", ["hello"], max_results: 5)
      result = cache.read("helo", max_results: 5)

      expect(result).to eq(["hello"])
    end

    it "separates cache entries by max_results" do
      cache.write("helo", ["hello"], max_results: 5)
      cache.write("helo", %w[hello help held], max_results: 10)

      expect(cache.read("helo", max_results: 5)).to eq(["hello"])
      expect(cache.read("helo", max_results: 10)).to eq(%w[hello help held])
    end

    it "is case-insensitive for words" do
      cache.write("HELO", ["hello"])
      result = cache.read("helo")

      expect(result).to eq(["hello"])
    end
  end

  describe "#fetch" do
    it "returns cached value without executing block" do
      cache.write("helo", ["hello"])

      call_count = 0
      result = cache.fetch("helo") do
        call_count += 1
        ["computed"]
      end

      expect(result).to eq(["hello"])
      expect(call_count).to eq(0)
    end

    it "computes and caches on miss" do
      call_count = 0

      result = cache.fetch("helo") do
        call_count += 1
        %w[hello help]
      end

      expect(result).to eq(%w[hello help])
      expect(call_count).to eq(1)

      # Second call should hit cache
      cached = cache.fetch("helo") { raise "Should not be called" }
      expect(cached).to eq(%w[hello help])
    end

    it "respects max_results in cache key" do
      cache.fetch("helo", max_results: 5) { ["hello"] }
      cache.fetch("helo", max_results: 10) { %w[hello help] }

      # Both should be cached separately
      expect(cache.read("helo", max_results: 5)).to eq(["hello"])
      expect(cache.read("helo", max_results: 10)).to eq(%w[hello help])
    end
  end

  describe "#delete" do
    it "removes cached suggestions" do
      cache.write("helo", ["hello"])
      cache.delete("helo")

      expect(cache.read("helo")).to be_nil
    end

    it "respects max_results when deleting" do
      cache.write("helo", ["hello"], max_results: 5)
      cache.write("helo", %w[hello help], max_results: 10)

      cache.delete("helo", max_results: 5)

      expect(cache.read("helo", max_results: 5)).to be_nil
      expect(cache.read("helo", max_results: 10)).to eq(%w[hello help])
    end
  end

  describe "#key?" do
    it "returns true for cached word" do
      cache.write("helo", ["hello"])
      expect(cache.key?("helo")).to be true
    end

    it "returns false for missing word" do
      expect(cache.key?("helo")).to be false
    end

    it "respects max_results" do
      cache.write("helo", ["hello"], max_results: 5)

      expect(cache.key?("helo", max_results: 5)).to be true
      expect(cache.key?("helo", max_results: 10)).to be false
    end
  end

  describe "#invalidate_word" do
    it "removes all cached entries for a word" do
      cache.write("helo", ["hello"], max_results: 5)
      cache.write("helo", %w[hello help], max_results: 10)
      cache.write("helo", %w[hello help held], max_results: 15)

      cache.invalidate_word("helo")

      expect(cache.key?("helo", max_results: 5)).to be false
      expect(cache.key?("helo", max_results: 10)).to be false
      expect(cache.key?("helo", max_results: 15)).to be false
    end

    it "does not affect other words" do
      cache.write("helo", ["hello"])
      cache.write("teh", ["the"])

      cache.invalidate_word("helo")

      expect(cache.key?("helo")).to be false
      expect(cache.key?("teh")).to be true
    end

    it "returns self for chaining" do
      result = cache.invalidate_word("helo")
      expect(result).to be(cache)
    end
  end

  describe "inheritance from LookupCache" do
    it "supports LRU eviction" do
      small_cache = described_class.new(max_size: 3)

      small_cache.write("key1", ["val1"])
      small_cache.write("key2", ["val2"])
      small_cache.write("key3", ["val3"])
      small_cache.write("key4", ["val4"])

      expect(small_cache.key?("key1")).to be false
      expect(small_cache.key?("key4")).to be true
    end

    it "provides stats" do
      cache.write("helo", ["hello"])
      cache.read("helo")
      cache.read("missing")

      stats = cache.stats
      expect(stats[:hits]).to eq(1)
      expect(stats[:misses]).to eq(1)
    end

    it "supports clear" do
      cache.write("helo", ["hello"])
      cache.clear

      expect(cache.read("helo")).to be_nil
    end
  end
end
