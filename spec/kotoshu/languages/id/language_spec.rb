# frozen_string_literal: true

require "spec_helper"

# Indonesian (plan 100, batch 3): thin Latin composition — the
# language has no diacritics, so the shared Latin tokenizer and base
# normalizer cover it. Typed on the unmodified US QWERTY grid.
RSpec.describe Kotoshu::Languages::Indonesian do
  it "registers id and id-ID in the language registry" do
    expect(Kotoshu::Language.get("id")).to eq(described_class)
    expect(Kotoshu::Language.get("id-ID")).to eq(described_class)
    expect(Kotoshu::Language.registered?("id")).to be true
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("id")
    expect(language.name).to eq("Indonesian")
  end

  it "tokenizes a real Indonesian sentence" do
    language = described_class.new
    words = language.tokenize("Saya membaca buku di rumah.")
    expect(words).to include("Saya", "membaca", "buku", "rumah")
  end

  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("id")
  end

  it "resolves to the Indonesian QWERTY layout" do
    layout = Kotoshu::Keyboard.layout_for("id")
    expect(layout.name).to eq("Indonesian-QWERTY")
    expect(layout.supports_language?("id")).to be true
    expect(layout.distance("q", "w")).to eq(1)
  end
end
