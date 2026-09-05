# frozen_string_literal: true

require "spec_helper"
require "kotoshu/languages/uk/language"

RSpec.describe Kotoshu::Languages::Ukrainian do
  let(:language) { described_class.new }

  describe "Cyrillic tokenizer" do
    it "keeps Ukrainian-script words" do
      expect(language.tokenize("привіт")).to contain_exactly("привіт")
    end

    it "splits a real Ukrainian sentence" do
      expect(language.tokenize("Привіт, Україно!")).to contain_exactly("Привіт", "Україно")
    end

    it "keeps Ukrainian apostrophe names as one token" do
      expect(language.tokenize("Мар'яна")).to contain_exactly("Мар'яна")
    end

    it "has the four Ukrainian-only letters in real words" do
      expect(language.tokenize("інтерв'ю єдиний ґрунт")).to include("інтерв'ю", "єдиний", "ґрунт")
    end

    it "rejects tokens without Cyrillic letters" do
      expect(language.tokenize("hello 42")).to be_empty
    end

    it "is a CyrillicTokenizer" do
      expect(language.tokenizer).to be_a(Kotoshu::Language::Tokenizer::CyrillicTokenizer)
    end
  end

  describe "normalization" do
    it "folds uppercase Ukrainian words" do
      expect(language.normalize_word("УКРАЇНА")).to eq("україна")
    end
  end

  describe "registry" do
    it "registers uk and uk-UA" do
      expect(Kotoshu::Language.get("uk")).to eq(described_class)
      expect(Kotoshu::Language.get("uk-UA")).to eq(described_class)
    end
  end
end
