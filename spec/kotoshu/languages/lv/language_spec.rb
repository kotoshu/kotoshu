# frozen_string_literal: true

require "spec_helper"

# Latvian (plan 100, batch 3): thin Latin composition; ā č ē ģ ī ķ ļ ņ
# š ū ž are dead-key / AltGr sequences over the US QWERTY grid.
RSpec.describe Kotoshu::Languages::Latvian do
  it "registers lv and lv-LV in the language registry" do
    expect(Kotoshu::Language.get("lv")).to eq(described_class)
    expect(Kotoshu::Language.get("lv-LV")).to eq(described_class)
    expect(Kotoshu::Language.registered?("lv")).to be true
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("lv")
    expect(language.name).to eq("Latvian")
  end

  it "extracts Latvian words including ā ē ī ū š ž" do
    language = described_class.new
    words = language.tokenize("skaista grāmata skolā šodien")
    expect(words).to include("skaista", "grāmata", "skolā", "šodien")
  end

  it "keeps diacritic words as single tokens" do
    language = described_class.new
    expect(language.tokenize("žāvēts šķīvis")).to contain_exactly("žāvēts", "šķīvis")
  end

  it "folds uppercase Latvian with plain Latin downcase" do
    language = described_class.new
    expect(language.normalize_word("ŠODIEN")).to eq("šodien")
    expect(language.normalize_word("GRĀMATA")).to eq("grāmata")
  end

  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("lv")
  end

  it "resolves to the Latvian QWERTY layout" do
    layout = Kotoshu::Keyboard.layout_for("lv")
    expect(layout.name).to eq("Latvian-QWERTY")
    expect(layout.supports_language?("lv")).to be true
    expect(layout.distance("k", "l")).to eq(1)
  end
end
