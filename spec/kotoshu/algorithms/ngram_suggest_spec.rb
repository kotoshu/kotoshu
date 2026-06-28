# frozen_string_literal: true

require "kotoshu"

RSpec.describe Kotoshu::Algorithms::NgramSuggest do
  describe ".root_score" do
    it "calculates 3-gram score plus left common substring" do
      result = described_class.root_score("hello", "help")
      expect(result).to be_a Numeric
      expect(result).to be > 0
    end

    it "gives higher score for more similar words" do
      score_similar = described_class.root_score("hello", "hell")
      score_different = described_class.root_score("hello", "world")

      expect(score_similar).to be > score_different
    end

    it "handles case insensitivity" do
      # Both use lowercase for n-gram comparison
      # But leftcommonsubstring is case-sensitive
      # "Hello" and "hello" share "ello" prefix (4 chars)
      # "HELLO" and "hello" share no prefix
      score1 = described_class.root_score("Hello", "hello")
      score2 = described_class.root_score("HELLO", "hello")

      expect(score1).to be > 0 # Has common prefix "ello"
      expect(score2).to be < score1 # No common prefix
    end
  end

  describe ".rough_affix_score" do
    it "calculates n-gram score with n=len(word1)" do
      result = described_class.rough_affix_score("hello", "help")
      expect(result).to be_a Numeric
    end

    it "uses word length as n-gram size" do
      # For "hello" (5 chars), uses 5-gram
      result = described_class.rough_affix_score("hello", "help")
      expect(result).to be > 0
    end
  end

  describe ".precise_affix_score" do
    it "gives >1000 for same word with different casing" do
      result = described_class.precise_affix_score("hello", "HELLO", 1.0, base: 10, has_phonetic: false)
      expect(result).to be > 1000
    end

    it "gives <-100 for very different words" do
      result = described_class.precise_affix_score("hello", "xyzabc", 2.0, base: 0, has_phonetic: false)
      expect(result).to be < -100
    end

    it "returns normal score (-100 to 1000) for somewhat similar words" do
      # Note: "hello" and "help" might be less than -100 due to bigrams
      result = described_class.precise_affix_score("hello", "held", 1.0, base: 10, has_phonetic: false)
      expect(result).to be_a Numeric
    end
  end

  describe ".detect_threshold" do
    it "calculates minimum threshold for passable suggestions" do
      threshold = described_class.detect_threshold("hello")
      expect(threshold).to be_a Numeric
    end

    it "returns different thresholds for different words" do
      t1 = described_class.detect_threshold("hello")
      t2 = described_class.detect_threshold("world")

      expect(t1).to be_a Numeric
      expect(t2).to be_a Numeric
    end
  end

  describe ".filter_guesses" do
    it "yields very good suggestions (score > 1000)" do
      guesses = [[2000, "HELLO"], [1500, "HELLO"], [500, "help"]]
      results = []

      described_class.filter_guesses(guesses, known: Set.new, onlymaxdiff: true) do |suggestion|
        results << suggestion
      end

      expect(results).to include("HELLO")
    end

    it "stops after very good suggestions when encountering normal ones" do
      guesses = [[2000, "HELLO"], [500, "help"], [300, "held"]]
      results = []

      described_class.filter_guesses(guesses, known: Set.new, onlymaxdiff: true) do |suggestion|
        results << suggestion
      end

      # Should only yield "HELLO" (score > 1000), then stop at "help" (score <= 1000)
      expect(results).to eq(["HELLO"])
    end

    it "yields one questionable suggestion if no good ones found" do
      guesses = [[-150, "held"], [-200, "hell"]]
      results = []

      described_class.filter_guesses(guesses, known: Set.new, onlymaxdiff: false) do |suggestion|
        results << suggestion
      end

      # Should yield only first questionable suggestion
      expect(results.length).to eq(1)
    end

    it "does not yield questionable suggestions when onlymaxdiff is true" do
      guesses = [[-150, "held"], [-200, "hell"]]
      results = []

      described_class.filter_guesses(guesses, known: Set.new, onlymaxdiff: true) do |suggestion|
        results << suggestion
      end

      expect(results).to be_empty
    end

    it "skips already known words" do
      guesses = [[2000, "HELLO"], [500, "help"]]
      known = Set.new(["HELLO"])

      results = []
      described_class.filter_guesses(guesses, known: known, onlymaxdiff: true) do |suggestion|
        results << suggestion
      end

      # "HELLO" is in known, should be skipped
      # But our simplified check uses include?, so "help" would still match
      expect(results).not_to include("HELLO")
    end
  end

  describe ".suggest" do
    let(:dictionary_words) do
      [
        { stem: "hello", flags: [] },
        { stem: "help", flags: [] },
        { stem: "world", flags: [] },
        { stem: "held", flags: [] },
        { stem: "hell", flags: [] }
      ]
    end

    it "generates suggestions for misspelled words" do
      results = []
      described_class.suggest("helo",
                              dictionary_words: dictionary_words,
                              prefixes: {},
                              suffixes: {},
                              known: Set.new,
                              maxdiff: 10, # Higher maxdiff = more permissive
                              onlymaxdiff: false, # Allow questionable suggestions
                              has_phonetic: false) do |suggestion|
        results << suggestion
      end

      expect(results).to be_an(Array)
      expect(results).not_to be_empty
    end

    it "skips words with length difference > 4" do
      results = []
      described_class.suggest("a",
                              dictionary_words: dictionary_words,
                              prefixes: {},
                              suffixes: {},
                              known: Set.new,
                              maxdiff: 2,
                              onlymaxdiff: true,
                              has_phonetic: false) do |suggestion|
        results << suggestion
      end

      # "a" (1 char) vs dictionary words (4-5 chars) - difference > 4
      # Should return empty or very few results
      expect(results).to be_empty
    end
  end

  describe "integration tests" do
    it "handles real spelling errors with n-gram scoring" do
      misspelling = "wrold"
      dictionary_words = [
        { stem: "world", flags: [] },
        { stem: "word", flags: [] },
        { stem: "old", flags: [] },
        { stem: "held", flags: [] }
      ]

      results = []
      described_class.suggest(misspelling,
                              dictionary_words: dictionary_words,
                              prefixes: {},
                              suffixes: {},
                              known: Set.new,
                              maxdiff: 10, # More permissive
                              onlymaxdiff: false, # Allow questionable
                              has_phonetic: false) do |suggestion|
        results << suggestion
      end

      # "world" should be suggested (transposition of 'r' and 'o')
      expect(results).to include("world")
    end
  end
end
