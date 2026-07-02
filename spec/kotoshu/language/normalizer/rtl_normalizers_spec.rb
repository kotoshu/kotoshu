# frozen_string_literal: true

require "kotoshu"

# Direct spec for the Arabic and Hebrew normalizers (TODO.impl/55
# Phase 1).
#
# RTL scripts (Arabic, Hebrew, Persian, Urdu) have multiple Unicode
# representations of the same visual character: presentation forms,
# diacritics, decorative marks. Without normalization, a user typing
# the same word in two different editors might produce two distinct
# strings that won't match a dictionary lookup. These normalizers
# canonicalize everything to the base form the dictionary stores.
RSpec.describe Kotoshu::Language::Normalizer::Arabic do
  let(:normalizer) { described_class.new }

  describe "#normalize" do
    it "strips tashkeel (vowel diacritics)" do
      # "كِتَابٌ" (kitābun, with harakat) → "كتاب" (bare form)
      expect(normalizer.normalize("كِتَابٌ")).to eq("كتاب")
    end

    it "strips tatweel (decorative elongation)" do
      # "كــتاب" (with tatweel) → "كتاب"
      expect(normalizer.normalize("كــتاب")).to eq("كتاب")
    end

    it "canonicalizes Presentation Forms-B to base forms" do
      # ﻛﺘﺎﺏ is "كتاب" written in Presentation Forms-B (FE70..FEFF).
      expect(normalizer.normalize("ﻛﺘﺎﺏ")).to eq("كتاب")
    end

    it "is idempotent — normalizing a bare form returns the same form" do
      bare = "كتاب"
      expect(normalizer.normalize(bare)).to eq(bare)
    end

    it "treats presentation-form input the same as base-form input" do
      bare = normalizer.normalize("كتاب")
      presented = normalizer.normalize("ﻛﺘﺎﺏ")
      expect(bare).to eq(presented)
    end

    it "returns '' for nil" do
      expect(normalizer.normalize(nil)).to eq("")
    end

    it "returns '' for empty input" do
      expect(normalizer.normalize("")).to eq("")
    end

    it "does not downcase (Arabic has no case)" do
      # Round-trip — no case conversion should happen.
      expect(normalizer.normalize("محمد")).to eq("محمد")
    end
  end

  describe "with strip_diacritics: false" do
    let(:normalizer) { described_class.new(strip_diacritics: false) }

    it "preserves tashkeel when configured to keep it" do
      input = "كِتَابٌ"
      expect(normalizer.normalize(input)).to eq(input)
    end
  end

  describe "with strip_tatweel: false" do
    let(:normalizer) { described_class.new(strip_tatweel: false) }

    it "preserves tatweel when configured to keep it" do
      expect(normalizer.normalize("كــتاب")).to eq("كــتاب")
    end
  end

  describe "#normalize_word" do
    it "normalizes a single word identically to #normalize" do
      word = "كِتَابٌ"
      expect(normalizer.normalize_word(word)).to eq(normalizer.normalize(word))
    end
  end
end

RSpec.describe Kotoshu::Language::Normalizer::Hebrew do
  let(:normalizer) { described_class.new }

  describe "#normalize" do
    it "strips niqqud (vowel points)" do
      # "שָׁלוֹם" (shalom, with niqqud) → "שלום" (bare form)
      expect(normalizer.normalize("שָׁלוֹם")).to eq("שלום")
    end

    it "strips dagesh (consonant dot) by default" do
      # "בַּיִת" (bayit with dagesh) → "בית"
      expect(normalizer.normalize("בַּיִת")).to eq("בית")
    end

    it "normalizes the maqaf (Hebrew hyphen) to ASCII hyphen" do
      expect(normalizer.normalize("עַל־יְדֵי")).to eq("על-ידי")
    end

    it "is idempotent — bare form stays bare" do
      bare = "שלום"
      expect(normalizer.normalize(bare)).to eq(bare)
    end

    it "returns '' for nil" do
      expect(normalizer.normalize(nil)).to eq("")
    end

    it "does not downcase (Hebrew has no case)" do
      expect(normalizer.normalize("שלום")).to eq("שלום")
    end
  end

  describe "with strip_dagesh: false" do
    let(:normalizer) { described_class.new(strip_dagesh: false) }

    it "preserves dagesh when configured to keep it" do
      # Note: niqqud is still stripped, but dagesh (U+05BC) remains.
      input = "בּ"
      result = normalizer.normalize(input)
      expect(result).to include(described_class::DAGESH)
    end
  end

  describe "with normalize_maqaf: false" do
    let(:normalizer) { described_class.new(normalize_maqaf: false) }

    it "preserves the maqaf" do
      result = normalizer.normalize("עַל־יְדֵי")
      expect(result).to include(described_class::MAQAF)
    end
  end

  describe "#normalize_word" do
    it "normalizes a single word identically to #normalize" do
      word = "שָׁלוֹם"
      expect(normalizer.normalize_word(word)).to eq(normalizer.normalize(word))
    end
  end
end

RSpec.describe Kotoshu::Language::Normalizer::Persian do
  let(:normalizer) { described_class.new }

  describe "#normalize" do
    it "maps Arabic Yeh to Persian Yeh" do
      # ي (Arabic, U+064A) → ی (Persian, U+06CC)
      expect(normalizer.normalize("سيل")).to eq("سیل")
    end

    it "maps Arabic Kaf to Persian Kaf" do
      # ك (Arabic, U+0643) → ک (Persian, U+06A9)
      expect(normalizer.normalize("كتاب")).to eq("کتاب")
    end

    it "strips diacritics (inherited from Arabic)" do
      expect(normalizer.normalize("كِتَاب")).to eq("کتاب")
    end

    it "is idempotent on already-Persian text" do
      persian = "سلام"
      expect(normalizer.normalize(persian)).to eq(persian)
    end

    it "returns '' for nil" do
      expect(normalizer.normalize(nil)).to eq("")
    end
  end
end
