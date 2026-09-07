# frozen_string_literal: true

require "spec_helper"

# Lithuanian (plan 100, batch 3): thin Latin composition; ą č ę ė į š
# ų ū ž are dead-key / AltGr sequences over the US QWERTY grid.
RSpec.describe Kotoshu::Languages::Lithuanian do
  it "registers lt and lt-LT in the language registry" do
    expect(Kotoshu::Language.get("lt")).to eq(described_class)
    expect(Kotoshu::Language.get("lt-LT")).to eq(described_class)
    expect(Kotoshu::Language.registered?("lt")).to be true
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("lt")
    expect(language.name).to eq("Lithuanian")
  end

  it "extracts Lithuanian words including ą ė į ū ž" do
    language = described_class.new
    words = language.tokenize("graži knyga mokykloje šiandien")
    expect(words).to include("graži", "knyga", "mokykloje", "šiandien")
  end

  it "keeps diacritic words as single tokens" do
    language = described_class.new
    expect(language.tokenize("ąžuolas ūsas")).to contain_exactly("ąžuolas", "ūsas")
  end

  it "folds uppercase Lithuanian with plain Latin downcase" do
    language = described_class.new
    expect(language.normalize_word("ŠIANDIEN")).to eq("šiandien")
    expect(language.normalize_word("ĄŽUOLAS")).to eq("ąžuolas")
  end

  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("lt")
  end

  it "resolves to the Lithuanian QWERTY layout" do
    layout = Kotoshu::Keyboard.layout_for("lt")
    expect(layout.name).to eq("Lithuanian-QWERTY")
    expect(layout.supports_language?("lt")).to be true
    expect(layout.distance("k", "l")).to eq(1)
  end
end
