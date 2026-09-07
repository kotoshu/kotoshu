# frozen_string_literal: true

require "spec_helper"

# Norwegian Nynorsk (plan 107): wired as a full-feature module the
# same week basic support opened the staged manifest, because both
# its dictionary and model are staged (`nn` in dictionaries, `nn` in
# the models registry). Thin Latin composition like the nb sibling.
RSpec.describe Kotoshu::Languages::NorwegianNynorsk do
  it "registers nn and nn-NO in the language registry" do
    expect(Kotoshu::Language.get("nn")).to eq(described_class)
    expect(Kotoshu::Language.get("nn-NO")).to eq(described_class)
    expect(Kotoshu::Language.registered?("nn")).to be true
  end

  it "does not touch the nb registrations" do
    expect(Kotoshu::Language.get("nb")).to eq(Kotoshu::Languages::NorwegianBokmal)
    expect(Kotoshu::Language.get("no")).to eq(Kotoshu::Languages::NorwegianBokmal)
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("nn")
    expect(language.name).to eq("Norwegian Nynorsk")
  end

  it "extracts Nynorsk words including å æ ø via the Latin tokenizer" do
    language = described_class.new
    words = language.tokenizer.tokenize("året går over ærlige øyre")
    expect(words).to include("året", "går", "over", "ærlige", "øyre")
  end

  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("nn")
  end

  it "counts as full feature" do
    expect(Kotoshu::Cache::LanguageCache.full_feature_languages).to include("nn")
  end
end
