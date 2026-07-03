# frozen_string_literal: true

require "kotoshu"

# Direct spec for the Arabic and Hebrew language modules (TODO.impl/55
# Phase 2). These modules register with Language::Registry, wire the
# RTL normalizers, and provide minimal tokenizers.
RSpec.describe "RTL language modules" do
  before { Kotoshu::Language::Registry.restore_autoload! }

  describe Kotoshu::Languages::Arabic do
    describe "registration" do
      it "registers ar and ar-SA" do
        expect(Kotoshu::Language::Registry.get("ar")).to eq(described_class)
        expect(Kotoshu::Language::Registry.get("ar-SA")).to eq(described_class)
      end
    end

    describe "instance" do
      subject(:instance) { described_class.instance }

      it "reports script_type :arabic" do
        expect(instance.script_type).to eq(:arabic)
      end

      it "is RTL" do
        expect(instance.rtl?).to be true
      end

      it "uses the Arabic normalizer" do
        expect(instance.normalizer).to be_a(Kotoshu::Language::Normalizer::Arabic)
      end

      it "uses a Tokenizer that handles Arabic text" do
        expect(instance.tokenizer).to be_a(described_class::Tokenizer)
      end

      it "uses Custom dictionary class (no bundled Hunspell dicts yet)" do
        expect(instance.dictionary_class).to eq(Kotoshu::Dictionary::Custom)
      end
    end

    describe described_class::Tokenizer do
      let(:tokenizer) { described_class.new }

      it "tokenizes Arabic text by splitting on whitespace" do
        tokens = tokenizer.tokenize("مرحبا بالعالم")
        expect(tokens).to include("مرحبا", "بالعالم")
      end

      it "returns [] for nil" do
        expect(tokenizer.tokenize(nil)).to eq([])
      end

      it "returns [] for empty string" do
        expect(tokenizer.tokenize("")).to eq([])
      end

      it "splits on Arabic punctuation (، ؛ ؟)" do
        tokens = tokenizer.tokenize("مرحبا، بالعالم؟")
        expect(tokens).to include("مرحبا", "بالعالم")
      end

      it "filters pure numbers" do
        tokens = tokenizer.tokenize("12345 مرحبا")
        expect(tokens).to include("مرحبا")
        expect(tokens).not_to include("12345")
      end
    end

    describe "normalization integration" do
      it "normalizer strips tashkeel from input" do
        norm = described_class.instance.normalizer
        expect(norm.normalize_word("كِتَابٌ")).to eq("كتاب")
      end
    end
  end

  describe Kotoshu::Languages::Hebrew do
    describe "registration" do
      it "registers he and he-IL" do
        expect(Kotoshu::Language::Registry.get("he")).to eq(described_class)
        expect(Kotoshu::Language::Registry.get("he-IL")).to eq(described_class)
      end
    end

    describe "instance" do
      subject(:instance) { described_class.instance }

      it "reports script_type :hebrew" do
        expect(instance.script_type).to eq(:hebrew)
      end

      it "is RTL" do
        expect(instance.rtl?).to be true
      end

      it "uses the Hebrew normalizer" do
        expect(instance.normalizer).to be_a(Kotoshu::Language::Normalizer::Hebrew)
      end

      it "uses a Tokenizer that handles Hebrew text" do
        expect(instance.tokenizer).to be_a(described_class::Tokenizer)
      end

      it "uses Custom dictionary class" do
        expect(instance.dictionary_class).to eq(Kotoshu::Dictionary::Custom)
      end
    end

    describe described_class::Tokenizer do
      let(:tokenizer) { described_class.new }

      it "tokenizes Hebrew text by splitting on whitespace" do
        tokens = tokenizer.tokenize("שלום עולם")
        expect(tokens).to include("שלום", "עולם")
      end

      it "returns [] for nil" do
        expect(tokenizer.tokenize(nil)).to eq([])
      end

      it "returns [] for empty string" do
        expect(tokenizer.tokenize("")).to eq([])
      end

      it "filters pure numbers" do
        tokens = tokenizer.tokenize("12345 שלום")
        expect(tokens).to include("שלום")
        expect(tokens).not_to include("12345")
      end
    end

    describe "normalization integration" do
      it "normalizer strips niqqud from input" do
        norm = described_class.instance.normalizer
        expect(norm.normalize_word("שָׁלוֹם")).to eq("שלום")
      end
    end
  end
end

RSpec.describe Kotoshu::Languages::Persian do
  before { Kotoshu::Language::Registry.restore_autoload! }

  describe "registration" do
    it "registers fa and fa-IR" do
      expect(Kotoshu::Language::Registry.get("fa")).to eq(described_class)
      expect(Kotoshu::Language::Registry.get("fa-IR")).to eq(described_class)
    end
  end

  describe "instance" do
    subject(:instance) { described_class.instance }

    it "reports script_type :arabic (Persian uses Arabic script)" do
      expect(instance.script_type).to eq(:arabic)
    end

    it "is RTL" do
      expect(instance.rtl?).to be true
    end

    it "uses the Persian normalizer" do
      expect(instance.normalizer).to be_a(Kotoshu::Language::Normalizer::Persian)
    end

    it "uses a Persian Tokenizer" do
      expect(instance.tokenizer).to be_a(described_class::Tokenizer)
    end

    it "uses Custom dictionary class" do
      expect(instance.dictionary_class).to eq(Kotoshu::Dictionary::Custom)
    end
  end

  describe described_class::Tokenizer do
    let(:tokenizer) { described_class.new }

    it "tokenizes Persian text by splitting on whitespace" do
      tokens = tokenizer.tokenize("سلام دنیا")
      expect(tokens).to include("سلام", "دنیا")
    end

    it "returns [] for nil" do
      expect(tokenizer.tokenize(nil)).to eq([])
    end

    it "filters pure numbers" do
      tokens = tokenizer.tokenize("12345 سلام")
      expect(tokens).to include("سلام")
      expect(tokens).not_to include("12345")
    end
  end

  describe "normalization integration" do
    it "normalizer maps Arabic Yeh to Persian Yeh" do
      norm = described_class.instance.normalizer
      expect(norm.normalize_word("سيل")).to eq("سیل")
    end
  end
end
