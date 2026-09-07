# frozen_string_literal: true

require "spec_helper"

# Slovenian (plan 100, batch 3): thin Latin composition on the
# South-Slavic QWERTZ grid shared with Croatian.
RSpec.describe Kotoshu::Languages::Slovenian do
  it "registers sl and sl-SI in the language registry" do
    expect(Kotoshu::Language.get("sl")).to eq(described_class)
    expect(Kotoshu::Language.get("sl-SI")).to eq(described_class)
    expect(Kotoshu::Language.registered?("sl")).to be true
  end

  it "reports its canonical code and name" do
    language = described_class.new
    expect(language.code).to eq("sl")
    expect(language.name).to eq("Slovenian")
  end

  it "extracts Slovenian words including č š ž" do
    language = described_class.new
    words = language.tokenize("lep dan v mestu prijatelju šoli")
    expect(words).to include("lep", "mestu", "šoli")
  end

  it "keeps č š ž words as single tokens" do
    language = described_class.new
    expect(language.tokenize("šola čaj žival")).to contain_exactly("šola", "čaj", "žival")
  end

  it "folds uppercase Slovenian with plain Latin downcase" do
    language = described_class.new
    expect(language.normalize_word("ŠOLA")).to eq("šola")
    expect(language.normalize_word("ČAJ")).to eq("čaj")
  end

  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("sl")
  end

  it "resolves to the Slovenian QWERTZ layout (the shared South-Slavic grid)" do
    layout = Kotoshu::Keyboard.layout_for("sl")
    expect(layout.name).to eq("Slovenian-QWERTZ")
    expect(layout.supports_language?("sl")).to be true
    expect(layout.key_positions).to include("č" => [2, 9], "ž" => [2, 11])
    expect(layout.distance("š", "đ")).to eq(1)
  end
end
