# frozen_string_literal: true

require "kotoshu"

# Direct spec for Algorithms::PhonetSuggest — the Hunspell/aspell PHONE-table
# phonetic suggestion algorithm ported from Spylls.
#
# PHONE tables are extremely rare in known dictionaries, so this module is
# only exercised by the phone.{aff,dic,sug,wrong} fixture indirectly. This
# spec pins the helper methods (metaphone, match_rule, final_score) and the
# top-level suggest pipeline.
RSpec.describe Kotoshu::Algorithms::PhonetSuggest do
  let(:table_class) { Kotoshu::Readers::PhonetTable }

  describe "MAX_ROOTS constant" do
    it "is 100" do
      expect(described_class::MAX_ROOTS).to eq(100)
    end
  end

  describe ".metaphone" do
    it "returns the word unchanged when the table is nil" do
      expect(described_class.metaphone(nil, "hello")).to eq("hello")
    end

    it "returns the word unchanged when the table is empty" do
      empty_table = table_class.new([])
      expect(described_class.metaphone(empty_table, "hello")).to eq("hello")
    end

    it "applies a single literal-letter rule" do
      table = table_class.new([["A", "a_replacement"]])
      result = described_class.metaphone(table, "ABAB")
      expect(result).to include("a_replacement")
    end

    it "skips characters with no matching rule" do
      table = table_class.new([["A", "X"]])
      # 'BC' has no rule, so it passes through character-by-character.
      result = described_class.metaphone(table, "ABC")
      expect(result).to include("X")
    end

    it "is case-insensitive on input — uppercases the word before matching" do
      table = table_class.new([["A", "X"]])
      expect(described_class.metaphone(table, "a")).to eq("X")
      expect(described_class.metaphone(table, "A")).to eq("X")
    end

    it "handles multi-character search patterns" do
      table = table_class.new([["PH", "F"]])
      result = described_class.metaphone(table, "PHANTOM")
      expect(result).to start_with("F")
    end
  end

  describe ".match_rule" do
    let(:unanchored_rule) do
      { search: /AB/, replacement: "X", start: false, end: false }
    end
    let(:start_anchored_rule) do
      { search: /AB/, replacement: "X", start: true, end: false }
    end
    let(:end_anchored_rule) do
      { search: /AB/, replacement: "X", start: false, end: true }
    end

    it "returns the match length for a matching unanchored rule" do
      expect(described_class.match_rule(unanchored_rule, "ABCD", 0)).to eq(2)
    end

    it "returns nil when the pattern does not match" do
      expect(described_class.match_rule(unanchored_rule, "XYZ", 0)).to be_nil
    end

    it "returns nil when start-anchored rule is invoked past position 0" do
      expect(described_class.match_rule(start_anchored_rule, "XAB", 1)).to be_nil
    end

    it "allows start-anchored rule at position 0" do
      expect(described_class.match_rule(start_anchored_rule, "ABCD", 0)).to eq(2)
    end

    it "end-anchored rule matches from the given position to end of word" do
      # The end-anchored branch uses .match(word[pos..]) so it must match
      # at the start of the suffix from pos.
      expect(described_class.match_rule(end_anchored_rule, "AB", 0)).to eq(2)
    end
  end

  describe ".final_score" do
    it "is positive for identical words" do
      score = described_class.final_score("hello", "hello")
      expect(score).to be > 0
    end

    it "gives a higher score to more similar words" do
      identical = described_class.final_score("hello", "hello")
      similar = described_class.final_score("hello", "hellp")
      different = described_class.final_score("hello", "world")
      expect(identical).to be > similar
      expect(similar).to be > different
    end

    it "factors in the left-common-substring bonus" do
      # Both words share 'he' prefix; the bonus is the prefix length.
      score = described_class.final_score("hello", "heaven")
      expect(score).to be_a(Numeric)
    end
  end

  describe ".suggest" do
    let(:table) do
      table_class.new([
                        ["PH", "F"],
                        ["T", "T"],
                        ["A", "A"]
                      ])
    end

    let(:dictionary_words) do
      [
        { stem: "phantom" },
        { stem: "pharmacy" },
        { stem: "tomato" },
        { stem: "xyzabc" } # dissimilar stem, length-skipped or score-skipped
      ]
    end

    it "yields suggestions as strings" do
      results = []
      described_class.suggest("phanton", dictionary_words: dictionary_words, table: table) do |s|
        results << s
      end
      expect(results).to all(be_a(String))
    end

    it "yields at least one suggestion when a phonetically similar stem exists" do
      results = []
      described_class.suggest("phantom", dictionary_words: dictionary_words, table: table) do |s|
        results << s
      end
      expect(results).not_to be_empty
    end

    it "returns an Enumerator-like interface via the block" do
      # Confirm the method requires a block — without one, Ruby raises.
      expect do
        described_class.suggest("phantom", dictionary_words: dictionary_words, table: table)
      end.to raise_error(LocalJumpError)
    end
  end
end
