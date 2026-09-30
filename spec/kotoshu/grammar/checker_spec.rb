# frozen_string_literal: true

require "spec_helper"
require "yaml"
require "kotoshu"

RSpec.describe Kotoshu::Grammar::Checker do
  let(:checker) { described_class.new(language: "en") }

  describe "golden agreement cases" do
    {
      "He go to school." => "EN_SV_AGREEMENT_3SG",
      "She make a mistake." => "EN_SV_AGREEMENT_3SG",
      "They was late." => "EN_WAS_PLURAL",
      "They goes to school." => "EN_SV_AGREEMENT_PLURAL"
    }.each do |sentence, rule_id|
      it "fires #{rule_id} on #{sentence.inspect}" do
        errors = checker.check(sentence)
        expect(errors.map { |e| e[:rule_id] }).to include(rule_id)
      end
    end

    it "suggests the correct 3sg form" do
      errors = checker.check("He go to school.")
      expect(errors.first[:suggestions]).to eq(["goes"])
    end

    it "suggests the base form for plural subjects" do
      errors = checker.check("They goes to school.")
      expect(errors.first[:suggestions]).to eq(["go"])
    end

    it "suggests the span correction for replace suggestions" do
      errors = checker.check("They was late.")
      expect(errors.first[:suggestions]).to eq(["They were"])
    end

    it "stays quiet on grammatical text" do
      expect(checker.check("He goes to school. They were late. She made a mistake.")).to be_empty
    end

    it "stays quiet when a modal licenses the base form" do
      expect(checker.check("He can go to school.")).to be_empty
    end
  end

  describe "word confusion" do
    it "flags could-of with a replacement" do
      errors = checker.check("I could of gone.")
      could_of = errors.find { |e| e[:rule_id] == "EN_COULD_OF" }
      expect(could_of).to be_truthy
      expect(could_of[:suggestions]).to eq(["could have"])
    end

    it "maps errors to character offsets" do
      text = "He go to school."
      errors = checker.check(text)
      span = text[errors.first[:start_offset]..errors.first[:end_offset]]
      expect(span).to eq("He go")
    end

    it "keeps offsets correct across sentences" do
      text = "First sentence. They was late."
      errors = checker.check(text)
      span = text[errors.first[:start_offset]..errors.first[:end_offset]]
      expect(span).to eq("They was")
    end
  end

  describe "clitic tokenization offsets" do
    it "splits clitics with exact spans" do
      checker.check("Harry's book")
      tokens = checker.send(:tokenize_with_offsets, "Harry's book", 0)
      expect(tokens.map { |t| t[:word] }).to eq(["Harry", "'s", "book"])
      expect(tokens[1][:start_offset]).to eq(5)
      expect(tokens[2][:start_offset]).to eq(8)
    end
  end

  describe "rule loading" do
    it "loads the bundled rule set" do
      expect(checker.rules.length).to be >= 20
      expect(checker.rules.map(&:id)).to include("EN_SV_AGREEMENT_3SG")
      expect(checker.rules.map(&:id)).to include("EN_COULD_OF")
    end

    it "excludes default-off rules unless asked" do
      all = described_class.new(language: "en", include_disabled: true)
      expect(all.rules.length).to be >= checker.rules.length
    end
  end

  describe "morphology templates" do
    let(:rule) do
      Kotoshu::Grammar::PatternRule.new(
        id: "TEST_MORPH", category: "test", language: "en",
        pattern: [{ "word" => "x" }], message: "test",
        suggestions: [{ "template" => "{{0|3sg}}" }]
      )
    end

    def suggest(word)
      rule.suggestions_for([{ word: word, pos: :VERB_BASE, index: 0 }]).first
    end

    it "inflects regular verbs" do
      expect(suggest("make")).to eq("makes")
      expect(suggest("walk")).to eq("walks")
    end

    it "inflects s/sh/ch/x/z endings with es" do
      expect(suggest("push")).to eq("pushes")
      expect(suggest("match")).to eq("matches")
      expect(suggest("pass")).to eq("passes")
    end

    it "inflects irregular verbs from the tagger table" do
      expect(suggest("go")).to eq("goes")
      expect(suggest("have")).to eq("has")
      expect(suggest("be")).to eq("is")
    end

    it "uninflects back to the base form" do
      base = Kotoshu::Grammar::PatternRule.new(
        id: "TEST_BASE", category: "test", language: "en",
        pattern: [{ "word" => "x" }], message: "test",
        suggestions: [{ "template" => "{{0|base}}" }]
      )
      expect(base.suggestions_for([{ word: "goes", pos: :VERB_3SG, index: 0 }]).first).to eq("go")
      expect(base.suggestions_for([{ word: "makes", pos: :VERB_3SG, index: 0 }]).first).to eq("make")
    end
  end

  describe "facade" do
    it "exposes Kotoshu.grammar_check" do
      errors = Kotoshu.grammar_check("He go to school.")
      expect(errors).to be_any
      expect(errors.first).to include(:rule_id, :start_offset, :message, :suggestions)
    end
  end
end

RSpec.describe "grammar rule example gates" do
  let(:checker) { Kotoshu::Grammar::Checker.new(language: "en") }

  it "every bad example fires its rule and every good example stays quiet" do
    missed = []
    false_positives = []
    checker.rules.each do |rule|
      rule.examples.each do |example|
        if example["bad"]
          fired = checker.check(example["bad"]).any? { |e| e[:rule_id] == rule.id }
          missed << "#{rule.id}: #{example['bad']}" unless fired
        elsif example["good"]
          fired = checker.check(example["good"]).any? { |e| e[:rule_id] == rule.id }
          false_positives << "#{rule.id}: #{example['good']}" if fired
        end
      end
    end
    expect(missed).to be_empty, "rules did not fire on their own bad examples:\n#{missed.join("\n")}"
    expect(false_positives).to be_empty, "rules fired on their own good examples:\n#{false_positives.join("\n")}"
  end

  it "rule ids are unique across the bundle" do
    ids = checker.rules.map(&:id)
    expect(ids.length).to eq(ids.uniq.length)
  end
end

RSpec.describe "multilingual starter rule sets (de/es/fr)" do
  %w[de es fr].each do |lang|
    describe lang do
      let(:checker) { Kotoshu::Grammar::Checker.new(language: lang) }

      it "loads at least 10 rules" do
        expect(checker.rules.length).to be >= 10
      end

      it "every bad example fires and every good example stays quiet" do
        missed = []
        false_positives = []
        checker.rules.each do |rule|
          rule.examples.each do |example|
            if example["bad"]
              missed << "#{rule.id}: #{example['bad']}" unless checker.check(example["bad"]).any? { |e| e[:rule_id] == rule.id }
            elsif example["good"]
              false_positives << "#{rule.id}: #{example['good']}" if checker.check(example["good"]).any?
            end
          end
        end
        expect(missed).to be_empty, "missed:\n#{missed.join("\n")}"
        expect(false_positives).to be_empty, "FP:\n#{false_positives.join("\n")}"
      end
    end
  end
end
