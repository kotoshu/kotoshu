# frozen_string_literal: true

require "spec_helper"

# Serbian Latin (plan 110): the last named language gap. The
# dictionaries manifest stages a distinct sr-Latn dictionary (the
# data chose the wiring over folding onto the Cyrillic sr
# dictionary), so the module is a thin Latin composition like its
# Croatian sibling, and the sr-Latn code must survive ResourceManager
# language normalization for the staged Latin files to be reachable.
RSpec.describe Kotoshu::Languages::SerbianLatin do
  it "registers sr-Latn in the language registry" do
    expect(Kotoshu::Language.get("sr-Latn")).to eq(described_class)
    expect(Kotoshu::Language.registered?("sr-Latn")).to be true
  end

  it "does not touch the Cyrillic sr registrations" do
    expect(Kotoshu::Language.get("sr")).to eq(Kotoshu::Languages::Serbian)
    expect(Kotoshu::Language.get("sr-RS")).to eq(Kotoshu::Languages::Serbian)
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("sr-Latn")
    expect(language.name).to eq("Serbian (Latin)")
  end

  it "reports the latin script type" do
    expect(described_class.new.script_type).to eq(:latin)
  end

  it "extracts Serbian Latin words including the digraph letters" do
    language = described_class.new
    words = language.tokenize("lepa ljubav u žurci — škola i đačko")
    expect(words).to include("lepa", "ljubav", "žurci", "škola", "đačko")
  end

  it "is in the downloadable spelling list under its own code" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("sr-Latn")
  end

  it "counts as full feature through the sr base it shares" do
    expect(Kotoshu::Cache::LanguageCache.full_feature_languages).to include("sr")
  end

  it "resolves to the South-Slavic QWERTZ grid ahead of Serbian Cyrillic" do
    layout = Kotoshu::Keyboard.layout_for("sr-Latn")
    expect(layout.name).to eq("Serbian-Latin-QWERTZ")
    expect(layout.supports_language?("sr-Latn")).to be true
    expect(layout.key_positions).to include("š" => [1, 10], "đ" => [1, 11], "ž" => [2, 11])
    expect(layout.distance("š", "đ")).to eq(1)
  end
end
