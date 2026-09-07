# frozen_string_literal: true

require "spec_helper"

# Slovak (plan 100, batch 3): thin Latin composition; the háčik
# diacritics are dead keys over the US QWERTY grid.
RSpec.describe Kotoshu::Languages::Slovak do
  it "registers sk and sk-SK in the language registry" do
    expect(Kotoshu::Language.get("sk")).to eq(described_class)
    expect(Kotoshu::Language.get("sk-SK")).to eq(described_class)
    expect(Kotoshu::Language.registered?("sk")).to be true
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("sk")
    expect(language.name).to eq("Slovak")
  end

  it "extracts Slovak words including ľ š č ť ž" do
    language = described_class.new
    words = language.tokenize("pekná žena v meste škola")
    expect(words).to include("pekná", "žena", "meste", "škola")
  end

  it "keeps diacritic words as single tokens" do
    language = described_class.new
    expect(language.tokenize("ľúbi šťastie")).to contain_exactly("ľúbi", "šťastie")
  end

  it "folds uppercase Slovak with plain Latin downcase" do
    language = described_class.new
    expect(language.normalize_word("ŠKOLA")).to eq("škola")
    expect(language.normalize_word("ŽENA")).to eq("žena")
  end

  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("sk")
  end

  it "resolves to the Slovak QWERTY layout" do
    layout = Kotoshu::Keyboard.layout_for("sk")
    expect(layout.name).to eq("Slovak-QWERTY")
    expect(layout.supports_language?("sk")).to be true
    expect(layout.distance("a", "s")).to eq(1)
  end
end
