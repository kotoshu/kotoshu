# frozen_string_literal: true

require "kotoshu"

# Direct spec for the PhraseMatcher (TODO.impl/51 Phase 1).
#
# PhraseMatcher catches multi-word confusions where each word is
# individually valid (so the spelling checker passes them) but the
# combination is a common error — typically phonetic confusions like
# "could of" → "could have".
RSpec.describe Kotoshu::Grammar::PatternMatchers::PhraseMatcher do
  def pattern(wrong_phrase:, suggestion:)
    { "conditions" => [{ "type" => "phrase_check",
                         "wrong_phrase" => wrong_phrase,
                         "suggestion" => suggestion }] }
  end

  def tok(word, position: 0)
    { token: word, position: position }
  end

  let(:rule) do
    Kotoshu::Grammar::Rule.from_yaml(
      "id" => "TEST_PHRASE",
      "name" => "test",
      "category" => "grammar",
      "severity" => "error",
      "description" => "test",
      "patterns" => [],
      "message" => "test message",
      "suggestion" => "could have"
    )
  end

  describe "#match" do
    it "flags every occurrence of the wrong phrase" do
      matcher = described_class.new(pattern(wrong_phrase: "could of",
                                            suggestion: "could have"), {})
      tokens = [tok("I", position: 0), tok("could", position: 2),
                tok("of", position: 8), tok("gone", position: 11),
                tok("had", position: 16), tok("could", position: 20),
                tok("of", position: 26)]
      errors = matcher.match(tokens, rule)
      expect(errors.length).to eq(2)
      expect(errors.map { |e| e[:position] }).to contain_exactly(2, 20)
    end

    it "is case-insensitive on the wrong phrase" do
      matcher = described_class.new(pattern(wrong_phrase: "could of",
                                            suggestion: "could have"), {})
      tokens = [tok("I"), tok("Could"), tok("Of"), tok("gone")]
      expect(matcher.match(tokens, rule).length).to eq(1)
    end

    it "returns [] when the phrase is not present" do
      matcher = described_class.new(pattern(wrong_phrase: "could of",
                                            suggestion: "could have"), {})
      tokens = [tok("I"), tok("could"), tok("have"), tok("gone")]
      expect(matcher.match(tokens, rule)).to eq([])
    end

    it "returns [] when only part of the phrase matches" do
      matcher = described_class.new(pattern(wrong_phrase: "could of",
                                            suggestion: "could have"), {})
      tokens = [tok("I"), tok("could"), tok("really"), tok("gone")]
      expect(matcher.match(tokens, rule)).to eq([])
    end

    it "carries the suggestion and context in each error" do
      matcher = described_class.new(pattern(wrong_phrase: "could of",
                                            suggestion: "could have"), {})
      tokens = [tok("I", position: 0), tok("could", position: 2), tok("of", position: 8)]
      error = matcher.match(tokens, rule).first
      expect(error[:suggestion]).to eq("could have")
      expect(error[:suggestions]).to eq(["could have"])
      expect(error[:context]).to eq("could of")
      expect(error[:rule_id]).to eq("TEST_PHRASE")
    end

    it "supports three-word phrases" do
      matcher = described_class.new(pattern(wrong_phrase: "in regards to",
                                            suggestion: "in regard to"), {})
      tokens = [tok("In", position: 0), tok("regards", position: 3),
                tok("to", position: 11), tok("your", position: 14)]
      errors = matcher.match(tokens, rule)
      expect(errors.length).to eq(1)
      expect(errors.first[:suggestion]).to eq("in regard to")
    end

    it "returns [] when the pattern has no phrase_check condition" do
      matcher = described_class.new({ "conditions" => [] }, {})
      expect(matcher.match([tok("could"), tok("of")], rule)).to eq([])
    end
  end
end
