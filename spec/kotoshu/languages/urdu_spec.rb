# frozen_string_literal: true

require "kotoshu"

RSpec.describe Kotoshu::Languages::Urdu do
  let(:lang) { described_class.new }

  it "registers ur and ur-PK" do
    expect(lang.code).to eq("ur")
    expect(lang).to be_rtl
    expect(lang.script_type).to eq(:arabic)
  end

  it "tokenizes whitespace-delimited Urdu, dropping the full stop" do
    expect(lang.tokenizer.tokenize("یہ ایک آزمائشی جملہ ۔")).to eq(
      %w[یہ ایک آزمائشی جملہ]
    )
  end

  describe "normalizer" do
    it "canonicalizes Arabic yeh and kaf to the Urdu codepoints" do
      expect(lang.normalizer.normalize("يكتاب")).to eq("یکتاب")
    end

    it "strips tatweel" do
      expect(lang.normalizer.normalize("کتـاب")).to eq("کتاب")
    end
  end

  describe "keyboard" do
    let(:layout) { Kotoshu::Keyboard::Layouts::UrduPhonetic.new }

    it "registers the CRULP phonetic grid for ur" do
      expect(Kotoshu::Keyboard::Registry.layout_for("ur").name).to eq("Urdu-Phonetic")
    end

    it "distance: identical keys are zero, adjacent neighbors are one" do
      expect(layout.distance("ق", "ق")).to eq(0)
      expect(layout.distance("ق", "و")).to eq(1)
    end

    it "omitted keys report unknown distance rather than a wrong one" do
      # ش sits on the CRULP row deliberately not encoded (chart sources
      # conflict) — distance must be unknown, not a wrong number
      expect(layout.distance("ق", "ش")).to eq(Float::INFINITY)
    end
  end
end
