# frozen_string_literal: true

require "spec_helper"
require "kotoshu/languages/tr/language"

RSpec.describe Kotoshu::Languages::Turkish do
  let(:language) { described_class.new }

  describe "dotless-i case folding" do
    it "folds I to ı and İ to i" do
      expect(language.normalize_word("İZMİR")).to eq("izmir")
      expect(language.normalize_word("ISTANBUL")).to eq("ıstanbul")
      expect(language.normalize_word("DIŞARIDA")).to eq("dışarıda")
    end

    it "keeps already-lowercase Turkish words unchanged" do
      expect(language.normalize_word("ışık")).to eq("ışık")
      expect(language.normalize_word("içinde")).to eq("içinde")
    end

    it "does not fold like the Unicode default (regression guard)" do
      expect(language.normalize_word("ISTANBUL")).not_to eq("istanbul")
    end

    it "honors the downcase option" do
      expect(language.normalize("IŞIK", downcase: false)).to eq("IŞIK")
    end
  end

  describe "tokenization" do
    it "splits a real Turkish sentence" do
      expect(language.tokenize("Bu güzel kitap okulda.")).to include("güzel", "kitap", "okulda")
    end

    it "keeps dotless-i words as single tokens" do
      expect(language.tokenize("ışık ağaç gözlük")).to contain_exactly("ışık", "ağaç", "gözlük")
    end
  end

  describe "registry" do
    it "registers tr and tr-TR" do
      expect(Kotoshu::Language.get("tr")).to eq(described_class)
      expect(Kotoshu::Language.get("tr-TR")).to eq(described_class)
    end
  end
end
