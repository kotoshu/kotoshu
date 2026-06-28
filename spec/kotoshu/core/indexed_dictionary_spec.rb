# frozen_string_literal: true

require "kotoshu"
require "tempfile"

# Direct spec for Core::IndexedDictionary — the multi-index dictionary
# model that backs prefix/suffix/exact lookups across Kotoshu.
#
# This is a foundational type used by suggestions, dictionary backends,
# and the trie bridge. It had no direct spec — only exercised
# indirectly via PlainText and integration tests.
RSpec.describe Kotoshu::Core::IndexedDictionary do
  let(:words) { %w[apple Apple banana cherry application ban] }
  let(:dict) { described_class.new(words) }

  describe "#initialize" do
    it "accepts an empty word list" do
      expect(described_class.new.size).to eq(0)
    end

    it "counts every word including duplicates" do
      expect(described_class.new(%w[a a a]).size).to eq(3)
    end

    it "is empty when no words are provided" do
      expect(described_class.new).to be_empty
    end

    it "is not empty when words are provided" do
      expect(dict).not_to be_empty
    end
  end

  describe "#add_word" do
    it "increments size" do
      d = described_class.new
      expect { d.add_word("hello") }.to change(d, :size).by(1)
    end

    it "returns self for chaining" do
      d = described_class.new
      expect(d.add_word("hello")).to be(d)
    end

    it "makes the new word findable by has_word?" do
      d = described_class.new
      d.add_word("hello")
      expect(d.has_word?("hello")).to be true
    end

    it "indexes the word for prefix search" do
      d = described_class.new
      d.add_word("monster")
      expect(d.find_by_prefix("mon")).to include("monster")
    end

    it "indexes the word for suffix search" do
      d = described_class.new
      d.add_word("running")
      expect(d.find_by_suffix("ing")).to include("running")
    end
  end

  describe "#add_words" do
    it "appends multiple words" do
      d = described_class.new
      d.add_words(%w[one two three])
      expect(d.size).to eq(3)
      expect(d.all_words).to eq(%w[one two three])
    end

    it "returns self for chaining" do
      d = described_class.new
      expect(d.add_words(%w[one])).to be(d)
    end
  end

  describe "#has_word? (case-sensitive)" do
    it "finds an exact word" do
      expect(dict.has_word?("apple")).to be true
    end

    it "distinguishes case" do
      expect(dict.has_word?("Apple")).to be true
      expect(dict.has_word?("APPLE")).to be false
    end

    it "returns false for a missing word" do
      expect(dict.has_word?("durian")).to be false
    end
  end

  describe "#has_word_ignorecase?" do
    it "matches regardless of case" do
      expect(dict.has_word_ignorecase?("apple")).to be true
      expect(dict.has_word_ignorecase?("APPLE")).to be true
      expect(dict.has_word_ignorecase?("ApPlE")).to be true
    end

    it "returns false for a missing word" do
      expect(dict.has_word_ignorecase?("durian")).to be false
    end
  end

  describe "#lookup" do
    it "returns the entry hash for an exact match" do
      entry = dict.lookup("apple")
      expect(entry).to be_a(Hash)
      expect(entry[:word]).to eq("apple")
    end

    it "stamps the index" do
      entry = dict.lookup("banana")
      expect(entry[:index]).to eq(2)
    end

    it "returns nil for a missing word" do
      expect(dict.lookup("durian")).to be_nil
    end

    it "returns nil for a wrong-case word" do
      expect(dict.lookup("APPLE")).to be_nil
    end
  end

  describe "#lookup_ignorecase" do
    it "finds the entry regardless of case" do
      entry = dict.lookup_ignorecase("APPLE")
      expect(entry[:word]).to eq("apple")
    end

    it "returns nil for a missing word" do
      expect(dict.lookup_ignorecase("durian")).to be_nil
    end
  end

  describe "#find_by_prefix" do
    it "returns words starting with the prefix" do
      result = dict.find_by_prefix("app")
      expect(result).to include("apple", "application")
    end

    it "returns an empty array for no matches" do
      expect(dict.find_by_prefix("zzz")).to eq([])
    end

    it "returns a duplicate (caller can mutate without breaking the index)" do
      result = dict.find_by_prefix("app")
      result << "INJECTED"
      expect(dict.find_by_prefix("app")).not_to include("INJECTED")
    end

    it "honours ignore_case: true" do
      result = dict.find_by_prefix("APP", ignore_case: true)
      expect(result).to include("apple", "Apple", "application")
    end
  end

  describe "#find_by_suffix" do
    it "returns words ending with the suffix" do
      result = dict.find_by_suffix("ana")
      expect(result).to include("banana")
    end

    it "returns an empty array for no matches" do
      expect(dict.find_by_suffix("zzz")).to eq([])
    end

    it "returns a duplicate (caller can mutate without breaking the index)" do
      result = dict.find_by_suffix("ana")
      result << "INJECTED"
      expect(dict.find_by_suffix("ana")).not_to include("INJECTED")
    end

    it "honours ignore_case: true" do
      result = dict.find_by_suffix("PLE", ignore_case: true)
      expect(result).to include("apple", "Apple")
    end
  end

  describe "#find_by_pattern" do
    it "returns words matching the regex" do
      result = dict.find_by_pattern(/^a.+e$/i)
      expect(result).to include("apple", "Apple")
    end

    it "returns an empty array when nothing matches" do
      expect(dict.find_by_pattern(/^zzz/)).to eq([])
    end
  end

  describe "#find_by_length" do
    it "returns words of exactly that length" do
      result = dict.find_by_length(3)
      expect(result).to include("ban")
    end

    it "returns an empty array when no words match" do
      expect(dict.find_by_length(100)).to eq([])
    end
  end

  describe "#find_by_length_range" do
    it "returns words within the inclusive range" do
      result = dict.find_by_length_range(min_length: 3, max_length: 5)
      expect(result).to include("apple", "Apple", "ban")
      expect(result).not_to include("application")
    end
  end

  describe "#all_words" do
    it "returns every word in insertion order" do
      expect(dict.all_words).to eq(words)
    end
  end

  describe "#random_words" do
    it "returns the requested count" do
      expect(dict.random_words(count: 3).size).to eq(3)
    end

    it "returns words that exist in the dictionary" do
      5.times do
        sample = dict.random_words(count: 1).first
        expect(dict.all_words).to include(sample)
      end
    end

    it "returns an empty array for an empty dictionary" do
      expect(described_class.new.random_words(count: 3)).to eq([])
    end
  end

  describe "#count_by_first_letter" do
    it "groups words by uppercased first letter" do
      counts = dict.count_by_first_letter
      expect(counts["A"]).to eq(3) # apple, Apple, application
      expect(counts["B"]).to eq(2) # banana, ban
      expect(counts["C"]).to eq(1) # cherry
    end

    it "returns an empty hash for an empty dictionary" do
      expect(described_class.new.count_by_first_letter).to eq({})
    end
  end

  describe "#count_by_length" do
    it "groups words by length" do
      counts = dict.count_by_length
      expect(counts[3]).to eq(1)  # ban
      expect(counts[5]).to eq(2)  # apple, Apple
      expect(counts[6]).to eq(2)  # banana, cherry
      expect(counts[11]).to eq(1) # application
    end
  end

  describe "#each_word" do
    it "yields every word when a block is given" do
      yielded = []
      dict.each_word { |w| yielded << w }
      expect(yielded).to eq(words)
    end

    it "returns an Enumerator when no block is given" do
      expect(dict.each_word).to be_an(Enumerator)
    end
  end

  describe "#each_with_index" do
    it "yields word and index pairs" do
      yielded = []
      dict.each_with_index { |w, i| yielded << [w, i] }
      expect(yielded.first).to eq(["apple", 0])
      expect(yielded.last).to eq(["ban", 5])
    end

    it "returns an Enumerator when no block is given" do
      expect(dict.each_with_index).to be_an(Enumerator)
    end
  end

  describe "#statistics" do
    it "reports total and unique word counts" do
      stats = dict.statistics
      expect(stats[:total_words]).to eq(6)
      expect(stats[:unique_words]).to eq(6)
    end

    it "reports min/max/avg lengths" do
      stats = dict.statistics
      expect(stats[:min_length]).to eq(3)
      expect(stats[:max_length]).to eq(11)
      expect(stats[:avg_length]).to be > 0
    end

    it "nests count_by_first_letter and count_by_length" do
      stats = dict.statistics
      expect(stats[:count_by_first_letter]).to be_a(Hash)
      expect(stats[:count_by_length]).to be_a(Hash)
    end

    it "reports zero lengths for an empty dictionary" do
      stats = described_class.new.statistics
      expect(stats[:total_words]).to eq(0)
      expect(stats[:min_length]).to eq(0)
      expect(stats[:max_length]).to eq(0)
      expect(stats[:avg_length]).to eq(0)
    end
  end

  describe "#to_s / #inspect" do
    it "includes the size" do
      expect(dict.to_s).to eq("IndexedDictionary(size: 6)")
    end

    it "aliases inspect to to_s" do
      expect(dict.inspect).to eq(dict.to_s)
    end
  end

  describe "#to_trie" do
    it "returns a Trie containing all words" do
      trie = dict.to_trie
      expect(trie).to respond_to(:all_words)
      dict.all_words.each do |w|
        expect(trie.all_words).to include(w)
      end
    end
  end

  describe ".from_file" do
    it "builds a dictionary from a word-list file, ignoring blanks and comments" do
      Tempfile.create(["dict", ".txt"]) do |f|
        f.puts "alpha"
        f.puts ""
        f.puts "# comment"
        f.puts "beta"
        f.close
        d = described_class.from_file(f.path)
        expect(d.all_words).to eq(%w[alpha beta])
      end
    end
  end
end
