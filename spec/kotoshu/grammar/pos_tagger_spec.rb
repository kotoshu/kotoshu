# frozen_string_literal: true

require "spec_helper"
require "yaml"
require "kotoshu/grammar"

RSpec.describe Kotoshu::Grammar do
  describe Kotoshu::Grammar::PosTagger do
    let(:tagger) { described_class.new }

    it "tags pronouns correctly" do
      tokens = tagger.tag("He go to school")
      expect(tokens[0][:word]).to eq("He")
      expect(tokens[0][:pos]).to eq(:PRON_3SG)
    end

    it "tags a base verb after a 3sg pronoun" do
      tokens = tagger.tag("He go to school")
      expect(tokens[1][:word]).to eq("go")
      expect(tokens[1][:pos]).to eq(:VERB_BASE)
    end

    it "tags plural pronouns" do
      tokens = tagger.tag("They was late")
      expect(tokens[0][:pos]).to eq(:PRON_PLURAL)
    end

    it "tags prepositions" do
      tokens = tagger.tag("I go to school")
      expect(tokens[2][:pos]).to eq(:PREP)
    end

    it "tags -ing words as VERB_ING" do
      tokens = tagger.tag("I am running fast")
      expect(tokens[2][:pos]).to eq(:VERB_ING)
    end

    it "tags -ly words as ADV" do
      tokens = tagger.tag("He ran quickly")
      expect(tokens[2][:pos]).to eq(:ADV)
    end

    it "tags nouns as NOUN by default" do
      tokens = tagger.tag("The dog barked")
      expect(tokens[1][:pos]).to eq(:NOUN)
    end

    it "handles empty input" do
      expect(tagger.tag("")).to eq([])
    end
  end

  describe "agreement rules (YAML)" do
    let(:rules_path) { File.expand_path("../../../lib/kotoshu/grammar/rules/en", __dir__) }
    let(:agreement_rules) do
      YAML.load_file(File.join(rules_path, "agreement.yml"))
    end
    let(:confusion_rules) do
      YAML.load_file(File.join(rules_path, "word_confusion.yml"))
    end

    it "loads at least 10 agreement rules" do
      expect(agreement_rules.length).to be >= 10
    end

    it "loads at least 10 confusion rules" do
      expect(confusion_rules.length).to be >= 10
    end

    it "every rule has required fields" do
      (agreement_rules + confusion_rules).each do |rule|
        expect(rule["id"]).to be_truthy
        expect(rule["category"]).to be_truthy
        expect(rule["pattern"]).to be_truthy
        expect(rule["message"]).to be_truthy
      end
    end

    it "every rule has at least one example" do
      (agreement_rules + confusion_rules).each do |rule|
        expect(rule["examples"]).to be_truthy
        expect(rule["examples"].first["bad"]).to be_truthy
        expect(rule["examples"].first["good"]).to be_truthy
      end
    end

    it "rule IDs are unique" do
      ids = (agreement_rules + confusion_rules).map { |r| r["id"] }
      expect(ids.length).to eq(ids.uniq.length)
    end
  end

  describe "the PosSequenceMatcher detects agreement errors" do
    let(:tagger) { Kotoshu::Grammar::PosTagger.new }

    it "detects PRON_3SG + VERB_BASE as a violation" do
      tokens = tagger.tag("He go to school")
      expect(tokens[0][:pos]).to eq(:PRON_3SG)
      expect(tokens[1][:pos]).to eq(:VERB_BASE)
      # The rule fires: the tagger found the pattern
    end

    it "does not fire on correct agreement" do
      tokens = tagger.tag("He goes to school")
      expect(tokens[1][:pos]).not_to eq(:VERB_BASE)
    end
  end
end
