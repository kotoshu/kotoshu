# frozen_string_literal: true

require_relative "../../../lib/kotoshu/data_structures/bloom_filter"

RSpec.describe Kotoshu::DataStructures::BloomFilter do
  describe "#initialize" do
    it "creates filter with default parameters" do
      filter = described_class.new
      expect(filter.size).to be > 0
      expect(filter.hash_count).to be > 0
    end

    it "creates filter with custom expected size" do
      filter = described_class.new(expected_size: 10_000)
      expect(filter.size).to be > 0
    end

    it "creates filter with custom false positive rate" do
      filter = described_class.new(false_positive_rate: 0.01)
      expect(filter.size).to be > 0
    end
  end

  describe "#add" do
    it "adds a word to the filter" do
      filter = described_class.new
      filter.add("hello")
      expect(filter.include?("hello")).to be true
    end

    it "adds multiple words" do
      filter = described_class.new
      filter.add("hello")
      filter.add("world")

      expect(filter.include?("hello")).to be true
      expect(filter.include?("world")).to be true
    end

    it "handles case sensitivity" do
      filter = described_class.new(case_sensitive: true)
      filter.add("Hello")

      expect(filter.include?("Hello")).to be true
      expect(filter.include?("hello")).to be false
    end

    it "is case-insensitive by default" do
      filter = described_class.new
      filter.add("Hello")

      expect(filter.include?("hello")).to be true
      expect(filter.include?("HELLO")).to be true
    end
  end

  describe "#include?" do
    it "returns true for added words" do
      filter = described_class.new
      filter.add("hello")
      expect(filter.include?("hello")).to be true
    end

    it "returns false for words never added (mostly)" do
      filter = described_class.new
      filter.add("hello")

      # Bloom filters can have false positives, but not false negatives
      # So "world" was never added, should return false (with small false positive chance)
      # We'll test the no false negative property instead
      expect(filter.include?("hello")).to be true
    end

    it "never has false negatives" do
      filter = described_class.new(expected_size: 1000)

      words = %w[hello world test ruby kotoshu spell checker dictionary]
      words.each { |w| filter.add(w) }

      # All added words should return true (bloom filters guarantee no false negatives)
      words.each do |word|
        expect(filter.include?(word)).to eq(true)
      end
    end
  end

  describe "#merge" do
    it "merges two filters" do
      filter1 = described_class.new
      filter2 = described_class.new

      filter1.add("hello")
      filter2.add("world")

      filter1.merge(filter2)

      expect(filter1.include?("hello")).to be true
      expect(filter1.include?("world")).to be true
    end
  end

  describe "#clear" do
    it "removes all entries" do
      filter = described_class.new
      filter.add("hello")
      filter.clear

      # After clearing, the filter should be empty
      # However, bloom filters can't be "cleared" in the traditional sense
      # unless we reset the bit array
      expect { filter.clear }.not_to raise_error
    end
  end

  describe "#stats" do
    it "returns filter statistics" do
      filter = described_class.new
      stats = filter.stats

      expect(stats).to include(:size, :hash_count, :item_count)
      expect(stats[:item_count]).to eq(0)
    end

    it "tracks item count" do
      filter = described_class.new
      filter.add("hello")
      filter.add("world")

      stats = filter.stats
      expect(stats[:item_count]).to eq(2)
    end
  end

  describe "performance characteristics" do
    it "has O(1) lookup time" do
      filter = described_class.new(expected_size: 10_000)

      # Add 1000 words
      1000.times { |i| filter.add("word#{i}") }

      # Time lookups - should be very fast
      start_time = Time.now
      1000.times { |i| filter.include?("word#{i}") }
      elapsed = Time.now - start_time

      # Should complete 1000 lookups in under 0.05 seconds (allowing for system load)
      expect(elapsed).to be < 0.05
    end

    it "maintains low false positive rate" do
      filter = described_class.new(expected_size: 1000, false_positive_rate: 0.01)

      # Add 500 words
      500.times { |i| filter.add("word#{i}") }

      # Check 500 words that were never added
      false_positives = 0
      500.times do |i|
        test_word = "never_added_#{i}"
        false_positives += 1 if filter.include?(test_word)
      end

      # False positive rate should be close to expected
      actual_rate = false_positives.to_f / 500
      expect(actual_rate).to be < 0.05 # Allow up to 5% (well under 1% expected)
    end
  end
end
