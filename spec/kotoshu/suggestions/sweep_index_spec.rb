# frozen_string_literal: true

require "kotoshu"

# Direct spec for Suggestions::SweepIndex — the per-dictionary sweep
# invariants (char lengths, Soundex codes, length buckets) that the
# suggestion strategies read instead of recomputing per word per
# sweep. The semantics here are frozen: buckets cover every word
# exactly once in original order, windows restore word-list order
# (ties in the strategies' ranking sorts depend on input order), and
# the packed Soundex codes are exactly what Algorithms::Soundex
# computes live.
RSpec.describe Kotoshu::Suggestions::SweepIndex do
  let(:words) { %w[one two three four five seventeen] }

  let(:index) { described_class.build(words) }

  describe ".build" do
    it "keeps the word list in order" do
      expect(index.words).to eq(words)
    end

    it "indexes every listed word" do
      words.each_with_index do |word, idx|
        expect(index.length(idx)).to eq(word.length)
        expect(index.soundex(idx)).to eq(Kotoshu::Algorithms::Soundex.code(word))
      end
    end

    it "counts characters, not bytes, for lengths" do
      index = described_class.build(["é"])
      expect(index.length(0)).to eq(1)
    end
  end

  describe "#indices_in_length_range" do
    it "covers every word exactly once over the full range" do
      all = index.indices_in_length_range(0, 100)
      expect(all).to eq((0...words.length).to_a)
    end

    it "selects by char length in original (word-list) order" do
      index = described_class.build(%w[ab cd xyz abcd ef])
      expect(index.indices_in_length_range(2, 2)).to eq([0, 1, 4])
      expect(index.indices_in_length_range(3, 4)).to eq([2, 3])
    end

    it "returns nothing for an empty window" do
      expect(index.indices_in_length_range(100, 99)).to eq([])
    end

    it "tolerates lengths with no bucket" do
      # Lengths -2..2 hold no words; the window must skip them silently.
      # Below 5: one(3), two(3), four(4), five(4) — in word-list order.
      expect(index.indices_in_length_range(-2, 2)).to eq([])
      expect(index.indices_in_length_range(-2, 4)).to eq([0, 1, 3, 4])
    end
  end

  describe "#words_in_length_range" do
    it "returns exactly the words the whole-list filter selects, in word-list order" do
      min = 2
      max = 5
      expected = words.select { |w| w.length >= min && w.length <= max }
      expect(index.words_in_length_range(min, max)).to eq(expected)
    end
  end

  describe "#soundex" do
    it "equals the live soundex computation for every word" do
      # Algorithms::Soundex is the one live implementation — shared by
      # PhoneticStrategy#soundex_code and this index — so this pins
      # the packing against the codes the strategy would compute.
      words.each_with_index do |word, idx|
        expect(index.soundex(idx)).to eq(Kotoshu::Algorithms::Soundex.code(word))
      end
    end

    it "packs the empty code for letter-less words" do
      index = described_class.build(["é", "Robert", "Rupert", "Ashcraft"])
      expect(index.soundex(0)).to eq("")
      expect(index.soundex(1)).to eq("R163")
      expect(index.soundex(2)).to eq("R163")
      expect(index.soundex(1)).to eq(index.soundex(2))
      expect(index.soundex(3)).not_to eq(index.soundex(1))
    end

    it "freezes the packed codes" do
      expect(index.soundex(0)).to be_frozen
    end
  end

  describe "#each_with_length" do
    it "yields every word with its memoized length in order" do
      pairs = []
      index.each_with_length { |word, length| pairs << [word, length] }
      expect(pairs).to eq(words.zip(words.map(&:length)))
    end
  end

  describe "#each_with_soundex" do
    it "yields every word with its memoized code in order" do
      pairs = []
      index.each_with_soundex { |word, code| pairs << [word, code] }
      expect(pairs).to eq(words.zip(words.map { |w| Kotoshu::Algorithms::Soundex.code(w) }))
    end
  end
end

# Dictionary integration: the memoized index on Dictionary::Base and
# its invalidation on word-list mutation. The index derives only from
# the word list, so every mutating backend must drop the memo after a
# successful add_word / remove_word (see Dictionary::Base#sweep_index).
RSpec.describe "Dictionary sweep index" do
  describe Kotoshu::Dictionary::PlainText do
    it "memoizes the index across sweeps and rebuilds it after mutation" do
      dict = Kotoshu::Dictionary::PlainText.from_words(%w[cat dog bird], language_code: "en")
      first = dict.sweep_index
      expect(dict.sweep_index).to equal(first)

      dict.add_word("hello")
      expect(dict.sweep_index).not_to equal(first)
      expect(dict.sweep_index.words).to include("hello")
      expect(dict.find_by_length_range(min_length: 5, max_length: 5)).to eq(["hello"])

      dict.remove_word("hello")
      expect(dict.sweep_index.words).not_to include("hello")
      expect(dict.sweep_index.words).to eq(dict.words)
    end
  end

  describe Kotoshu::Dictionary::Hunspell do
    let(:fixture) { File.expand_path("../../fixtures/dictionaries/hunspell/test", __dir__) }

    let(:dict) do
      described_class.new(
        aff_path: "#{fixture}.aff",
        dic_path: "#{fixture}.dic",
        language_code: "en"
      )
    end

    it "find_by_length_range returns the historical filtered list and stays fresh after mutation" do
      expected = dict.words.select { |w| w.length >= 4 && w.length <= 4 }
      expect(dict.find_by_length_range(min_length: 4, max_length: 4)).to eq(expected)

      dict.add_word("teapot")
      expect(dict.find_by_length_range(min_length: 6, max_length: 6)).to include("teapot")

      dict.remove_word("teapot")
      expect(dict.find_by_length_range(min_length: 6, max_length: 6)).not_to include("teapot")
    end

    it "keeps find_by_length_range byte-identical to a whole-list filter over every window" do
      # Hunspell uses the Dictionary::Base default — the sweep-index
      # path this port introduced — so its windowed answers must match
      # the historical whole-list select exactly, set and order.
      (-1..10).each do |min|
        (min..10).each do |max|
          expected = dict.words.select { |w| w.length >= min && w.length <= max }
          expect(dict.find_by_length_range(min_length: min, max_length: max)).to eq(expected)
        end
      end
    end

    it "feeds PhoneticStrategy codes that match the live soundex computation" do
      dict.sweep_index.words.each_with_index do |word, idx|
        expect(dict.sweep_index.soundex(idx)).to eq(Kotoshu::Algorithms::Soundex.code(word))
      end
    end

    it "surfaces words added after the index was memoized" do
      # Build the memo, then mutate: the reset must make the next
      # sweep see the added word.
      dict.find_by_length_range(min_length: 4, max_length: 4)
      dict.add_word("teapot")

      generator = Kotoshu::Suggestions::Generator.new(
        dict, algorithms: [Kotoshu::Suggestions::Strategies::EditDistanceStrategy]
      )
      expect(generator.generate("teapit").suggestions.map(&:word)).to include("teapot")
    end
  end
end
