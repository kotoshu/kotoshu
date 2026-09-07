# frozen_string_literal: true

require "spec_helper"

# Norwegian Bokmål (models registry v1.3.0): the module registers nb
# AND the `no` alias — fastText publishes Bokmål-dominated cc.no
# vectors that ship as `nb`, so Norwegian users typing either code
# land on the same module. Thin Latin composition like da/sv.
RSpec.describe Kotoshu::Languages::NorwegianBokmal do
  it "registers nb, nb-NO, no, and no-NO in the language registry" do
    %w[nb nb-NO no no-NO].each do |code|
      expect(Kotoshu::Language.get(code)).to eq(described_class)
      expect(Kotoshu::Language.registered?(code)).to be true
    end
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("nb")
    expect(language.name).to eq("Norwegian Bokmål")
  end

  it "extracts Norwegian words including å æ ø via the Latin tokenizer" do
    language = described_class.new
    words = language.tokenizer.tokenize("årsaften går over ærlige ører")
    expect(words).to include("årsaften", "går", "over", "ærlige", "ører")
  end

  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("nb")
  end

  it "resolves as the Swedish and Danish modules do" do
    expect(Kotoshu::Language.get("da")).to eq(Kotoshu::Languages::Danish)
    expect(Kotoshu::Language.get("sv")).to eq(Kotoshu::Languages::Swedish)
    # Nynorsk is wired since plan 107 (its own module, not an alias).
    expect(Kotoshu::Language.get("nn")).to eq(Kotoshu::Languages::NorwegianNynorsk)
  end
end
