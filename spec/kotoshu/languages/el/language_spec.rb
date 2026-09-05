# frozen_string_literal: true

require "spec_helper"
require "kotoshu/languages/el/language"

RSpec.describe Kotoshu::Languages::Greek do
  let(:language) { described_class.new }

  describe "Greek-aware normalization" do
    it "folds uppercase words with the final sigma" do
      expect(language.normalize_word("ΕΛΛΑΣ")).to eq("ελλας")
      expect(language.normalize_word("ΠΑΙΔΙΑΣ")).to eq("παιδιας")
    end

    it "keeps lowercase final sigma untouched" do
      expect(language.normalize_word("ελλάς")).to eq("ελλάς")
    end

    it "does not touch medial sigma" do
      expect(language.normalize_word("ΣΑΛΑΤΑ")).to eq("σαλατα")
    end

    it "strips accents only when asked" do
      expect(language.normalize("καλημέρα")).to eq("καλημέρα")
      expect(language.normalize("καλημέρα", strip_accents: true)).to eq("καλημερα")
    end
  end

  describe "Greek tokenizer" do
    it "keeps Greek-script words the Latin tokenizer would drop" do
      expect(language.tokenize("καλημέρα")).to contain_exactly("καλημέρα")
    end

    it "splits a real Greek sentence on Greek punctuation" do
      expect(language.tokenize("Καλημέρα, Ελλάδα!")).to contain_exactly("Καλημέρα", "Ελλάδα")
    end

    it "rejects tokens without Greek letters" do
      expect(language.tokenize("hello 123")).to be_empty
    end

    it "is a GreekTokenizer" do
      expect(language.tokenizer).to be_a(Kotoshu::Language::Tokenizer::GreekTokenizer)
    end
  end

  describe "registry" do
    it "registers el and el-GR" do
      expect(Kotoshu::Language.get("el")).to eq(described_class)
      expect(Kotoshu::Language.get("el-GR")).to eq(described_class)
    end
  end
end
