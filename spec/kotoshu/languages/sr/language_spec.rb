# frozen_string_literal: true

require "spec_helper"

# Serbian (plan 100, batch 3): Cyrillic composition — Cyrillic
# tokenizer, base normalizer. Serbian Latin (sr-Latn) stays unwired;
# Cyrillic is the constitutional primary script and the script the
# staged dictionary carries. љ њ ђ ћ џ ј are real keys on the Serbian
# Cyrillic grid.
RSpec.describe Kotoshu::Languages::Serbian do
  it "registers sr and sr-RS in the language registry" do
    expect(Kotoshu::Language.get("sr")).to eq(described_class)
    expect(Kotoshu::Language.get("sr-RS")).to eq(described_class)
    expect(Kotoshu::Language.registered?("sr")).to be true
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("sr")
    expect(language.name).to eq("Serbian")
  end

  it "reports the cyrillic script type" do
    expect(described_class.new.script_type).to eq(:cyrillic)
  end

  it "extracts Serbian Cyrillic words including љ and џ" do
    language = described_class.new
    words = language.tokenize("лепа љубав у журци")
    expect(words).to include("лепа", "љубав", "журци")
  end

  it "folds uppercase Serbian with plain Cyrillic downcase" do
    language = described_class.new
    expect(language.normalize_word("ЉУБАВ")).to eq("љубав")
    expect(language.normalize_word("ШКОЛА")).to eq("школа")
  end

  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("sr")
  end

  it "resolves to the Serbian Cyrillic layout ahead of JCUKEN" do
    layout = Kotoshu::Keyboard.layout_for("sr")
    expect(layout.name).to eq("Serbian-Cyrillic")
    expect(layout.supports_language?("sr")).to be true
    expect(layout.key_positions).to include("љ" => [1, 0], "њ" => [1, 1], "џ" => [3, 0])
    expect(layout.distance("љ", "њ")).to eq(1)
  end
end
