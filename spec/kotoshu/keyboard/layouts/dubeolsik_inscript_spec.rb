# frozen_string_literal: true

require "spec_helper"
require "kotoshu/keyboard"

# Dubeolsik — the standard Korean 2-set layout (plan 108), keyed on
# jamo per KS X 5002. The grid models the physical keys the IME reads
# jamo from, so typo proximity lands on the unit Korean slips operate
# on.
RSpec.describe Kotoshu::Keyboard::Layouts::Dubeolsik do
  let(:layout) { described_class.new }

  describe "KS X 5002 mapping" do
    it "maps the three letter rows in 2-set order" do
      # Top row: ㅂ ㅈ ㄷ ㄱ ㅅ ㅛ ㅕ ㅑ ㅐ ㅔ (q..p)
      expect(layout.position("ㅂ")).to eq([0, 0])
      expect(layout.position("ㅅ")).to eq([0, 4])
      expect(layout.position("ㅔ")).to eq([0, 9])
      # Home row: ㅁ ㄴ ㅇ ㄹ ㅎ ㅗ ㅓ ㅏ ㅣ (a..l)
      expect(layout.position("ㅁ")).to eq([1, 0])
      expect(layout.position("ㅎ")).to eq([1, 4])
      expect(layout.position("ㅣ")).to eq([1, 8])
      # Bottom row: ㅋ ㅌ ㅊ ㅍ ㅠ ㅜ ㅡ (z..m)
      expect(layout.position("ㅋ")).to eq([2, 0])
      expect(layout.position("ㅡ")).to eq([2, 6])
    end

    it "places the shifted fortis consonants on their base keys" do
      expect(layout.position("ㅃ")).to eq(layout.position("ㅂ"))
      expect(layout.position("ㅆ")).to eq(layout.position("ㅅ"))
      expect(layout.position("ㄲ")).to eq(layout.position("ㄱ"))
      expect(layout.position("ㅉ")).to eq(layout.position("ㅈ"))
      expect(layout.position("ㄸ")).to eq(layout.position("ㄷ"))
    end

    it "covers every base key: lead consonants and the ten simple vowels" do
      leads = %w[ㄱ ㄲ ㄴ ㄷ ㄸ ㄹ ㅁ ㅂ ㅃ ㅅ ㅆ ㅇ ㅈ ㅉ ㅊ ㅋ ㅌ ㅍ ㅎ]
      simple_vowels = %w[ㅏ ㅑ ㅓ ㅕ ㅗ ㅛ ㅜ ㅠ ㅡ ㅣ ㅐ ㅔ ㅒ ㅖ]
      (leads + simple_vowels).each { |jamo| expect(layout.position(jamo)).not_to be_nil, jamo }
    end

    it "has no composed vowels — the IME builds ㅘ ㅙ ㅚ from two keys" do
      %w[ㅘ ㅙ ㅚ ㅝ ㅞ ㅟ ㅢ].each { |jamo| expect(layout.position(jamo)).to be_nil, jamo }
    end

    it "has no syllables or Latin on the grid" do
      expect(layout.position("한")).to be_nil
      expect(layout.position("a")).to be_nil
    end
  end

  describe "adjacency" do
    it "makes the vertical vowel neighbors distance 1" do
      # ㅛ (y) and ㅗ (h) share a column across rows — a classic slip
      expect(layout.distance("ㅛ", "ㅗ")).to eq(1)
      expect(layout.distance("ㅕ", "ㅓ")).to eq(1)
      expect(layout.distance("ㅑ", "ㅏ")).to eq(1)
    end

    it "makes horizontal neighbors on the home row distance 1" do
      expect(layout.distance("ㅏ", "ㅓ")).to eq(1)
      expect(layout.adjacent_keys("ㅏ")).to include("ㅓ", "ㅣ")
    end
  end

  describe "language support" do
    it "supports ko and ko-KR" do
      expect(layout.supports_language?("ko")).to be true
      expect(layout.supports_language?("ko-KR")).to be true
      expect(Kotoshu::Keyboard.layout_for("ko")).to be_a(described_class)
      expect(Kotoshu::Keyboard.layout_for("ko").name).to eq("Dubeolsik")
    end
  end
end

# Devanagari InScript (plan 108): mirrored from the models repo eval
# harness grid and drift-checked against it.
RSpec.describe Kotoshu::Keyboard::Layouts::DevanagariInScript do
  let(:layout) { described_class.new }

  describe "InScript mapping" do
    it "maps the InScript rows" do
      expect(layout.position("ौ")).to eq([1, 0])
      expect(layout.position("ब")).to eq([1, 5])
      expect(layout.position("क")).to eq([2, 7])
      expect(layout.position("य")).to eq([3, 9])
      expect(layout.position("्")).to eq([2, 2]) # virama
    end

    it "carries matras as real keys" do
      %w[ा ि ी ु ू े ै ो ौ ं].each { |key| expect(layout.position(key)).not_to be_nil, key }
    end

    it "makes adjacent keys distance 1" do
      expect(layout.distance("ा", "ी")).to eq(1)
      expect(layout.adjacent_keys("क")).to include("र", "त")
    end
  end

  describe "language support" do
    it "supports ne and ne-NP" do
      expect(layout.supports_language?("ne")).to be true
      expect(layout.supports_language?("ne-NP")).to be true
      expect(Kotoshu::Keyboard.layout_for("ne")).to be_a(described_class)
      expect(Kotoshu::Keyboard.layout_for("ne").name).to eq("DevanagariInScript")
    end
  end
end
