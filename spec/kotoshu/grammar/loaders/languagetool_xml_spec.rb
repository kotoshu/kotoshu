# frozen_string_literal: true

require "spec_helper"
require "kotoshu/grammar"

RSpec.describe Kotoshu::Grammar::Loaders::PosMapper do
  it "maps exact LT tags" do
    expect(described_class.map("VBZ")).to eq(:VERB_3SG)
    expect(described_class.map("NNS")).to eq(:PLUR_NOUN)
    expect(described_class.map("NNP")).to eq(:PROPER_NOUN)
    expect(described_class.map("MD")).to eq(:MODAL)
    expect(described_class.map("PRP$")).to eq(:DET)
  end

  it "maps prefix regex patterns to group tags" do
    expect(described_class.map("NN.*", regexp: true)).to eq(:NOUN)
    expect(described_class.map("VB.*", regexp: true)).to eq(:VERB)
    expect(described_class.map("W.*", regexp: true)).to eq(:WH)
  end

  it "maps alternations to arrays" do
    expect(described_class.map("DT|PRP\\$", regexp: true)).to eq(:DET)
    expect(described_class.map("NNPS?|NNS", regexp: true)).to contain_exactly(:PROPER_NOUN, :PLUR_NOUN)
  end

  it "maps char classes and optional segments" do
    expect(described_class.map("VB[DZ]", regexp: true)).to eq(:VERB)
    expect(described_class.map("VBP?", regexp: true)).to eq(:VERB_BASE)
    expect(described_class.map("NNP?S", regexp: true)).to eq(:NOUN)
  end

  it "returns nil for unmappable tags" do
    expect(described_class.map("POS")).to be_nil
    expect(described_class.map("garbage", regexp: true)).to be_nil
    expect(described_class.map(nil)).to be_nil
  end
end

RSpec.describe Kotoshu::Grammar::Loaders::LanguageToolXml do
  let(:fixture_xml) do
    <<~XML
      <?xml version="1.0" encoding="UTF-8"?>
      <rules lang="en">
        <category name="Capitalization" type="typo">
          <rulegroup id="CAP_TEST" name="test group">
            <rule>
              <pattern>
                <token case_sensitive="yes">harry</token>
              </pattern>
              <message>Name should be capitalized: <suggestion>Harry</suggestion></message>
              <example correction="Harry">It was <marker>harry</marker> who did it.</example>
              <example>Harry is here.</example>
            </rule>
            <rule>
              <pattern case_sensitive="yes">
                <token>ca</token>
                <token postag="PRP"/>
              </pattern>
              <message>Did you mean <suggestion>can</suggestion>?</message>
              <example correction="can">What <marker>ca</marker> I do?</example>
            </rule>
          </rulegroup>
          <rule id="STANDALONE" name="standalone rule">
            <pattern>
              <token>in</token>
              <token>this</token>
              <token>from</token>
            </pattern>
            <message>Did you mean <suggestion>in this <match no="3"/></suggestion>?</message>
            <example correction="in this form">It is <marker>in this from</marker> place.</example>
          </rule>
          <rule id="ANTIPAT" name="suppressed rule">
            <antipattern case_sensitive="yes">
              <token regexp="yes">Middle|MIDDLE</token>
              <token regexp="yes">Ages|AGES</token>
            </antipattern>
            <pattern>
              <token>the</token>
            </pattern>
            <message>test</message>
            <example correction="x">The <marker>the</marker> middle ages here.</example>
          </rule>
        </category>
      </rules>
    XML
  end

  let(:loader) { described_class.new(fixture_xml) }
  let(:rules) { loader.rules }
  let(:ids) { rules.map { |r| r["id"] } }

  it "converts rules inside rulegroups with prefixed ids" do
    expect(ids).to include("CAP_TEST_0")
    expect(ids).to include("CAP_TEST_1")
    expect(ids).to include("STANDALONE")
  end

  it "gives unnamed sub-rules unique positional ids" do
    expect(ids.length).to eq(ids.uniq.length)
  end

  it "converts word tokens" do
    rule = rules.find { |r| r["id"] == "CAP_TEST_0" }
    expect(rule["pattern"]).to eq([{ "word" => "harry", "case_sensitive" => true }])
    expect(rule["message"]).to include('"Harry"')
    expect(rule["suggestions"]).to eq(["Harry"])
  end

  it "propagates pattern-level case sensitivity to tokens" do
    rule = rules.find { |r| r["id"] == "CAP_TEST_1" }
    expect(rule["pattern"].first["case_sensitive"]).to be(true)
    expect(rule["pattern"][1]["pos"]).to eq(:PRON)
  end

  it "converts three-word patterns with word tokens" do
    rule = rules.find { |r| r["id"] == "STANDALONE" }
    expect(rule["pattern"]).to eq([{ "word" => "in" }, { "word" => "this" }, { "word" => "from" }])
  end

  it "converts suggestion matches to templates" do
    rule = rules.find { |r| r["id"] == "STANDALONE" }
    expect(rule["suggestions"]).to eq(["in this {{2}}"])
  end

  it "converts antipatterns with case sensitivity" do
    rule = rules.find { |r| r["id"] == "ANTIPAT" }
    expect(rule["unless_pattern"]).not_to be_nil
    expect(rule["unless_pattern"].first.first["case_sensitive"]).to be(true)
  end

  it "carries source and license metadata" do
    expect(rules.first["source"]).to eq("languagetool")
    expect(rules.first["license"]).to eq("LGPL-2.1+")
  end

  it "records examples with bad/good/correction" do
    rule = rules.find { |r| r["id"] == "CAP_TEST_0" }
    bad = rule["examples"].find { |e| e["bad"] }
    good = rule["examples"].find { |e| e["good"] }
    expect(bad["bad"]).to eq("It was harry who did it.")
    expect(bad["correction"]).to eq("Harry")
    expect(good["good"]).to eq("Harry is here.")
  end

  it "counts skips in stats" do
    expect(loader.stats).to include(converted: 4, skipped: 0)
  end

  describe "converted rules run through the engine" do
    it "fires on the bad example and stays quiet on the good one" do
      rule = Kotoshu::Grammar::PatternRule.from_yaml(rules.find { |r| r["id"] == "CAP_TEST_0" })
      bad = rule.examples.find { |e| e["bad"] }["bad"]
      good = rule.examples.find { |e| e["good"] }["good"]
      expect(rule.check(bad)).to be_any
      expect(rule.check(good)).to be_empty
    end

    it "fires on the bad example with a correction" do
      rule = Kotoshu::Grammar::PatternRule.from_yaml(rules.find { |r| r["id"] == "STANDALONE" })
      errors = rule.check("It is in this from place.")
      expect(errors).to be_any
      expect(errors.first[:suggestions]).to eq(["in this from"])
    end

    it "suppresses on case-sensitive antipatterns" do
      rule = Kotoshu::Grammar::PatternRule.from_yaml(rules.find { |r| r["id"] == "ANTIPAT" })
      expect(rule.check("the Middle Ages here")).to be_empty
      expect(rule.check("the middle ages here")).to be_any
    end
  end
end
