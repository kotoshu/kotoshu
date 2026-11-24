# frozen_string_literal: true

require "json"

RSpec.describe "Urdu POS scaffolding (sample-scale, issues #277-#280)" do
  SAMPLE_FILE = File.expand_path("../../../lib/kotoshu/grammar/data/ur_pos_sample_lexicon.json",
                                 __dir__)

  it "ships the sample lexicon with its provenance header" do
    raw = JSON.parse(File.read(SAMPLE_FILE))
    expect(raw["token_count"]).to eq(1_955)
    expect(raw["words"]).to be_a(Hash)
    expect(raw["words"].size).to be >= 850
    expect(raw["_provenance"]).to include("SAMPLE-SCALE")
  end

  it "covers every CLE tag attested in the sample through the REDUCED map" do
    raw = JSON.parse(File.read(SAMPLE_FILE))
    attested = raw["words"].values.uniq
    unknown = attested.reject { |t| Kotoshu::Grammar::UrPosTagger::REDUCED.key?(t) }
    expect(unknown).to be_empty
  end

  it "tags a sample sentence with zero UNKNOWN tokens" do
    sentence = "احمدپور سیال کے گاؤں کا رہائشی ، محرّم لک بھی چھوٹا زمیندار اور دس بارہ ایکڑ اراضی کا مالک تھا ۔"
    tagged = Kotoshu::Grammar::UrPosTagger.new(
      lexicon: Kotoshu::Grammar::UrPosTagger.sample_lexicon
    ).tag(sentence)
    expect(tagged.map { |t| t[:pos] }).not_to include("UNKNOWN")
    expect(tagged.map { |t| t[:pos] }).to all(be_a(String))
  end

  it "dispatches the reduced view through PosTagger for language ur" do
    tagged = Kotoshu::Grammar::PosTagger.new(language: "ur").tag("وہ گاؤں کو آیا")
    expect(tagged.map { |t| t[:pos] }).to eq(%i[PRON NOUN ADP VERB])
  end

  describe "the POS-keyed rules fire through the real dispatch" do
    let(:checker) { Kotoshu::Grammar::Checker.new(language: "ur") }

    it "loads the ur pos rules" do
      expect(checker.rules.map(&:id)).to contain_exactly(
        "UR_AUX_PLURAL_AGREEMENT", "UR_PSP_DOUBLE", "UR_FINITE_VERB_PSP"
      )
    end

    it "flags plural noun with singular auxiliary" do
      expect(checker.check("بچے ہے").map { |e| e[:rule_id] })
        .to include("UR_AUX_PLURAL_AGREEMENT")
      expect(checker.check("خاندانوں ہے").map { |e| e[:rule_id] })
        .to include("UR_AUX_PLURAL_AGREEMENT")
    end

    it "flags stacked postpositions" do
      expect(checker.check("اس کو کو پیغام پہنچا").map { |e| e[:rule_id] })
        .to include("UR_PSP_DOUBLE")
      expect(checker.check("لک کی کی شکایت").map { |e| e[:rule_id] })
        .to include("UR_PSP_DOUBLE")
    end

    it "flags finite verb directly followed by a postposition" do
      expect(checker.check("وہ آیا کو گاؤں").map { |e| e[:rule_id] })
        .to include("UR_FINITE_VERB_PSP")
    end

    it "stays quiet on the corrected forms" do
      {
        "بچے ہیں" => "UR_AUX_PLURAL_AGREEMENT",
        "خاندانوں ہیں" => "UR_AUX_PLURAL_AGREEMENT",
        "اس کو پیغام پہنچا" => "UR_PSP_DOUBLE",
        "لک کی شکایت" => "UR_PSP_DOUBLE",
        "وہ گاؤں کو آیا" => "UR_FINITE_VERB_PSP"
      }.each do |text, rule_id|
        fired = checker.check(text).map { |e| e[:rule_id] }
        expect(fired).not_to include(rule_id), "#{text} must stay quiet (fired: #{fired})"
      end
    end
  end
end
