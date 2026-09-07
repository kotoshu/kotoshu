# frozen_string_literal: true

require "spec_helper"

# Korean module (plan 108): full-feature wiring over the staged ko
# dictionary — eojeol-aware Hangul tokenizer, Dubeolsik grid.
RSpec.describe Kotoshu::Languages::Korean do
  it "registers ko and ko-KR in the language registry" do
    expect(Kotoshu::Language.get("ko")).to eq(described_class)
    expect(Kotoshu::Language.get("ko-KR")).to eq(described_class)
    expect(Kotoshu::Language.registered?("ko")).to be true
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("ko")
    expect(language.name).to eq("Korean")
  end

  it "extracts eojeol through the Hangul tokenizer" do
    language = described_class.new
    expect(language.tokenizer.tokenize("한국어 텍스트입니다"))
      .to contain_exactly("한국어", "텍스트입니다")
  end

  it "is left-to-right hangul" do
    language = described_class.new
    expect(language.script_type).to eq(:hangul)
    expect(language.rtl?).to be false
  end

  it "resolves to the Dubeolsik layout" do
    layout = Kotoshu::Keyboard.layout_for("ko")
    expect(layout.name).to eq("Dubeolsik")
    expect(layout.supports_language?("ko")).to be true
    expect(layout.distance("ㅛ", "ㅗ")).to eq(1)
  end

  it "is in the downloadable spelling list and counts as full feature" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("ko")
    expect(Kotoshu::Cache::LanguageCache.full_feature_languages).to include("ko")
  end
end

# Nepali module (plan 108): full-feature wiring over the staged ne
# dictionary — grapheme-aware Devanagari tokenizer, InScript grid.
RSpec.describe Kotoshu::Languages::Nepali do
  it "registers ne and ne-NP in the language registry" do
    expect(Kotoshu::Language.get("ne")).to eq(described_class)
    expect(Kotoshu::Language.get("ne-NP")).to eq(described_class)
    expect(Kotoshu::Language.registered?("ne")).to be true
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("ne")
    expect(language.name).to eq("Nepali")
  end

  it "extracts words with matras and conjuncts attached" do
    language = described_class.new
    expect(language.tokenizer.tokenize("यो नेपाली पाठ हो"))
      .to contain_exactly("यो", "नेपाली", "पाठ", "हो")
    expect(language.tokenizer.tokenize("विद्यालय खोला"))
      .to contain_exactly("विद्यालय", "खोला")
  end

  it "is left-to-right devanagari" do
    language = described_class.new
    expect(language.script_type).to eq(:devanagari)
    expect(language.rtl?).to be false
  end

  it "resolves to the Devanagari InScript layout" do
    layout = Kotoshu::Keyboard.layout_for("ne")
    expect(layout.name).to eq("DevanagariInScript")
    expect(layout.supports_language?("ne")).to be true
    expect(layout.distance("ा", "ी")).to eq(1)
  end

  it "is in the downloadable spelling list and counts as full feature" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("ne")
    expect(Kotoshu::Cache::LanguageCache.full_feature_languages).to include("ne")
  end
end
