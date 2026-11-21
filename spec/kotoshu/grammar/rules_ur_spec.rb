# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Urdu POS-keyed grammar rules" do
  let(:rules_path) { File.expand_path("../../../lib/kotoshu/grammar/rules/ur", __dir__) }
  let(:loader) { Kotoshu::Grammar::RuleLoader.new(rules_path) }
  let(:tagger) do
    Kotoshu::Grammar::UrPosTagger.new(lexicon: { "کتابیں" => "NN", "بچے" => "NN" })
  end

  it "loads the starter rule set" do
    rules = loader.load_rules
    expect(rules.map(&:id)).to include("UR_AUX_PLURAL_AGREEMENT")
  end

  it "carries runnable bad→good examples in the rule data" do
    rule = loader.load_rules.find { |r| r.id == "UR_AUX_PLURAL_AGREEMENT" }
    expect(rule.examples).not_to be_empty
    rule.examples.each do |ex|
      expect(ex["bad"]).not_to be_empty
      expect(ex["good"]).not_to be_empty
    end
  end

  def tagged(sentence)
    tagger.tag_reduced(sentence).map do |t|
      { word: t[:word], pos: t[:reduced], position: t[:index] }
    end
  end

  it "fires on the tagged bad example through the pattern matcher" do
    rule = loader.load_rules.find { |r| r.id == "UR_AUX_PLURAL_AGREEMENT" }
    expect(rule.check(tagged("کتابیں ہے"))).not_to be_empty
  end

  it "does not fire on the corrected sentence" do
    rule = loader.load_rules.find { |r| r.id == "UR_AUX_PLURAL_AGREEMENT" }
    expect(rule.check(tagged("کتابیں ہیں"))).to be_empty
  end
end
