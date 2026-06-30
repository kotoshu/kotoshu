# frozen_string_literal: true

require "kotoshu"

# Property-based tests for Kotoshu::Core::Trie::Trie (TODO.impl/56 T4.3).
#
# Properties tested:
# 1. Insertion is order-independent — the same set of words produces
#    the same trie regardless of insertion order.
# 2. Lookup is total — every inserted word is found; every
#    non-inserted word is not found.
# 3. all_words is the exact set inserted (order-independent).
# 4. Round-trip: insert(word) then lookup(word) always returns true.
#
# We use RSpec's built-in iteration (no external property-testing
# library needed) with a fixed random seed for determinism. Each
# property runs on multiple random input sets.
RSpec.describe Kotoshu::Core::Trie::Trie, "property-based tests" do
  # Deterministic pseudo-random generator so the suite is reproducible.
  let(:rng) { Random.new(42) }

  def random_words(count, max_len = 8, alphabet = ("a".."e").to_a)
    Array.new(count) do
      Array.new(rng.rand(1..max_len)) { alphabet.sample(random: rng) }.join
    end.uniq
  end

  # ---- Property 1: Insertion is order-independent ---------------------

  describe "insertion order independence" do
    it "same words in different orders produce identical lookup results" do
      5.times do
        words = random_words(20)
        trie_a = described_class.new
        trie_b = described_class.new

        words.each { |w| trie_a.insert(w) }
        words.reverse.each { |w| trie_b.insert(w) }

        words.each do |w|
          expect(trie_a.lookup(w)).to eq(trie_b.lookup(w)),
                                      "lookup mismatch for #{w}"
        end
      end
    end

    it "all_words is the same set regardless of insertion order" do
      5.times do
        words = random_words(15)
        trie_a = described_class.new
        trie_b = described_class.new

        words.shuffle(random: rng).each { |w| trie_a.insert(w) }
        words.sort.reverse.each { |w| trie_b.insert(w) }

        expect(trie_a.all_words.sort).to eq(trie_b.all_words.sort)
      end
    end
  end

  # ---- Property 2: Lookup is total -----------------------------------

  describe "lookup totality" do
    it "every inserted word is found" do
      5.times do
        words = random_words(30)
        trie = described_class.new
        words.each { |w| trie.insert(w) }

        words.each do |w|
          expect(trie.lookup(w)).to be_truthy,
                                    "inserted word #{w} not found"
        end
      end
    end

    it "non-inserted words are not found" do
      5.times do
        inserted = random_words(20)
        trie = described_class.new
        inserted.each { |w| trie.insert(w) }

        # Generate words that may or may not be in the set.
        candidates = random_words(30)
        non_inserted = candidates - inserted

        non_inserted.each do |w|
          expect(trie.lookup(w)).to be_falsey,
                                    "non-inserted word #{w} was found"
        end
      end
    end
  end

  # ---- Property 3: all_words matches the inserted set ----------------

  describe "all_words completeness" do
    it "all_words returns exactly the inserted set" do
      5.times do
        words = random_words(25).sort
        trie = described_class.new
        words.each { |w| trie.insert(w) }

        expect(trie.all_words.sort).to eq(words)
      end
    end
  end

  # ---- Property 4: Round-trip ----------------------------------------

  describe "round-trip" do
    it "insert then lookup always succeeds" do
      5.times do
        words = random_words(10)
        trie = described_class.new

        words.each do |w|
          trie.insert(w)
          expect(trie.lookup(w)).to be_truthy
        end
      end
    end

    it "has_prefix? is true for every prefix of every inserted word" do
      3.times do
        words = random_words(10, 5)
        trie = described_class.new
        words.each { |w| trie.insert(w) }

        words.each do |w|
          (1..w.length).each do |len|
            prefix = w[0, len]
            # Every prefix of an inserted word should be found (the
            # trie stores intermediate nodes).
            expect(trie).to have_prefix(prefix),
                            "prefix #{prefix} of #{w} not found"
          end
        end
      end
    end
  end

  # ---- Property 5: Edge cases ----------------------------------------

  describe "edge cases" do
    it "empty trie has no words" do
      trie = described_class.new
      expect(trie.all_words).to eq([])
      expect(trie.lookup("anything")).to be_falsey
    end

    it "single-word trie" do
      trie = described_class.new
      trie.insert("hello")
      expect(trie.lookup("hello")).to be_truthy
      expect(trie.all_words).to contain_exactly("hello")
    end

    it "duplicate insert is idempotent" do
      trie = described_class.new
      trie.insert("hello")
      trie.insert("hello")
      expect(trie.all_words).to contain_exactly("hello")
    end
  end
end
