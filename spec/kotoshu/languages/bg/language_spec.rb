# frozen_string_literal: true

require "spec_helper"

# Bulgarian (plan 100, batch 3): Cyrillic composition like Ukrainian —
# Cyrillic tokenizer, base normalizer. The Bulgarian-only letters ъ ь
# are real keys on the Bulgarian BDS grid, not JCUKEN positions.
RSpec.describe Kotoshu::Languages::Bulgarian do
  it "registers bg and bg-BG in the language registry" do
    expect(Kotoshu::Language.get("bg")).to eq(described_class)
    expect(Kotoshu::Language.get("bg-BG")).to eq(described_class)
    expect(Kotoshu::Language.registered?("bg")).to be true
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("bg")
    expect(language.name).to eq("Bulgarian")
  end

  it "reports the cyrillic script type" do
    expect(described_class.new.script_type).to eq(:cyrillic)
  end

  it "extracts Bulgarian words including ъ" do
    language = described_class.new
    words = language.tokenize("голяма къща в града")
    expect(words).to include("голяма", "къща", "града")
  end

  it "folds uppercase Bulgarian with plain Cyrillic downcase" do
    language = described_class.new
    expect(language.normalize_word("КЪЩА")).to eq("къща")
    expect(language.normalize_word("ГРАД")).to eq("град")
  end

  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("bg")
  end

  it "resolves to the Bulgarian BDS layout ahead of JCUKEN" do
    layout = Kotoshu::Keyboard.layout_for("bg")
    expect(layout.name).to eq("Bulgarian-BDS")
    expect(layout.supports_language?("bg")).to be true
    expect(layout.key_positions).to include("ъ" => [3, 2], "ь" => [2, 0])
    expect(layout.distance("ь", "я")).to eq(1)
    expect(Kotoshu::Keyboard.layout_for("ru").name).to eq("JCUKEN")
  end
end
