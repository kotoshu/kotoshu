# frozen_string_literal: true

require "spec_helper"

# Estonian (plan 100, batch 3): thin Latin composition; ä ö õ ü š ž
# are dead-key / AltGr sequences over the US QWERTY grid.
RSpec.describe Kotoshu::Languages::Estonian do
  it "registers et and et-EE in the language registry" do
    expect(Kotoshu::Language.get("et")).to eq(described_class)
    expect(Kotoshu::Language.get("et-EE")).to eq(described_class)
    expect(Kotoshu::Language.registered?("et")).to be true
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("et")
    expect(language.name).to eq("Estonian")
  end

  it "extracts Estonian words including õ ä ö ü" do
    language = described_class.new
    words = language.tokenize("ilus raamat õppekool Pärnus")
    expect(words).to include("ilus", "raamat", "õppekool", "Pärnus")
  end

  it "keeps õ ä ö ü words as single tokens" do
    language = described_class.new
    expect(language.tokenize("õnn süda värvi")).to contain_exactly("õnn", "süda", "värvi")
  end

  it "folds uppercase Estonian with plain Latin downcase" do
    language = described_class.new
    expect(language.normalize_word("ÕNN")).to eq("õnn")
    expect(language.normalize_word("VÄRVI")).to eq("värvi")
  end

  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("et")
  end

  it "resolves to the Estonian QWERTY layout" do
    layout = Kotoshu::Keyboard.layout_for("et")
    expect(layout.name).to eq("Estonian-QWERTY")
    expect(layout.supports_language?("et")).to be true
    expect(layout.distance("k", "l")).to eq(1)
  end
end
