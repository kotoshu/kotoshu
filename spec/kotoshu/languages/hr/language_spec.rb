# frozen_string_literal: true

require "spec_helper"

# Croatian (plan 100, batch 3): thin Latin composition on the
# South-Slavic QWERTZ grid where š đ č ć ž are real keys.
RSpec.describe Kotoshu::Languages::Croatian do
  it "registers hr and hr-HR in the language registry" do
    expect(Kotoshu::Language.get("hr")).to eq(described_class)
    expect(Kotoshu::Language.get("hr-HR")).to eq(described_class)
    expect(Kotoshu::Language.registered?("hr")).to be true
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("hr")
    expect(language.name).to eq("Croatian")
  end

  it "extracts Croatian words including the digraph letters" do
    language = described_class.new
    words = language.tokenize("lijepa đak čeka školu u gradu")
    expect(words).to include("lijepa", "đak", "čeka", "školu")
  end

  it "keeps digraph-letter words as single tokens" do
    language = described_class.new
    expect(language.tokenize("škola đak čovjek")).to contain_exactly("škola", "đak", "čovjek")
  end

  it "normalizes lowercase Croatian words to themselves" do
    language = described_class.new
    %w[knjiga prijatelj svijet].each do |word|
      expect(language.normalize_word(word)).to eq(word)
    end
  end

  it "folds uppercase Croatian with plain Latin downcase" do
    language = described_class.new
    expect(language.normalize_word("ŠKOLA")).to eq("škola")
  end

  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("hr")
  end

  it "resolves to the Croatian QWERTZ layout with the š đ č ć ž keys" do
    layout = Kotoshu::Keyboard.layout_for("hr")
    expect(layout.name).to eq("Croatian-QWERTZ")
    expect(layout.supports_language?("hr")).to be true
    expect(layout.key_positions).to include("š" => [1, 10], "đ" => [1, 11],
                                            "č" => [2, 9], "ć" => [2, 10], "ž" => [2, 11])
    expect(layout.distance("č", "ć")).to eq(1)
  end
end
