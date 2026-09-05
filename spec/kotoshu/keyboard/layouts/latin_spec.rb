# frozen_string_literal: true

require "spec_helper"
require "kotoshu/keyboard"

# The parameterized Latin layout family (plan 84, Track A): one
# family over the qwerty/qwertz base grids with per-language
# declarations, instead of near-duplicate per-language files.
RSpec.describe Kotoshu::Keyboard::Layouts::Latin do
  let(:qwerty) { Kotoshu::Keyboard::Layouts::QWERTY.new }
  let(:qwertz) { Kotoshu::Keyboard::Layouts::QWERTZ.new }

  shared_examples "a Latin family member" do |codes|
    it "is registered for its language" do
      codes.each do |code|
        expect(Kotoshu::Keyboard.layout_for(code)).to be_a(described_class)
      end
    end

    it "freezes its composed grid" do
      expect(layout.key_positions).to be_frozen
      expect(layout.language_codes).to eq(codes)
    end
  end

  describe Kotoshu::Keyboard::Layouts::Latin::Italian do
    let(:layout) { described_class.new }

    include_examples "a Latin family member", %w[it it-IT]

    it "reuses the QWERTY base grid coordinates" do
      expect(layout.distance("q", "w")).to eq(1)
      expect(layout.position("z")).to eq(qwerty.position("z"))
    end

    it "reports an Italian name" do
      expect(layout.name).to eq("Italian-QWERTY")
    end
  end

  describe Kotoshu::Keyboard::Layouts::Latin::Dutch do
    let(:layout) { described_class.new }

    include_examples "a Latin family member", %w[nl nl-NL]
  end

  describe Kotoshu::Keyboard::Layouts::Latin::Polish do
    let(:layout) { described_class.new }

    include_examples "a Latin family member", %w[pl pl-PL]

    it "keeps Polish diacritics off the physical grid" do
      %w[ą ć ę ł ń ó ś ź ż].each { |key| expect(layout.position(key)).to be_nil }
    end
  end

  describe Kotoshu::Keyboard::Layouts::Latin::Czech do
    let(:layout) { described_class.new }

    include_examples "a Latin family member", %w[cs cs-CZ]

    it "reuses the QWERTZ base grid (z/y swap)" do
      expect(layout.position("z")).to eq(qwertz.position("z"))
      expect(layout.distance("y", "x")).to eq(1)
    end

    it "keeps háček letters off the physical grid" do
      %w[č š ř ž ď ť ň].each { |key| expect(layout.position(key)).to be_nil }
    end
  end

  describe Kotoshu::Keyboard::Layouts::Latin::Hungarian do
    let(:layout) { described_class.new }

    include_examples "a Latin family member", %w[hu hu-HU]

    it "reuses the QWERTZ base grid" do
      expect(layout.position("z")).to eq(qwertz.position("z"))
    end
  end

  describe Kotoshu::Keyboard::Layouts::Latin::Romanian do
    let(:layout) { described_class.new }

    include_examples "a Latin family member", %w[ro ro-RO]
  end

  describe Kotoshu::Keyboard::Layouts::Latin::Catalan do
    let(:layout) { described_class.new }

    include_examples "a Latin family member", %w[ca ca-ES]
  end

  describe Kotoshu::Keyboard::Layouts::Latin::Vietnamese do
    let(:layout) { described_class.new }

    include_examples "a Latin family member", %w[vi vi-VN]
  end

  describe "the Nordic members" do
    describe Kotoshu::Keyboard::Layouts::Latin::Danish do
      let(:layout) { described_class.new }

      include_examples "a Latin family member", %w[da da-DK]

      it "has real å æ ø keys" do
        expect(layout.position("å")).to eq([1, 10])
        expect(layout.position("æ")).to eq([2, 9])
        expect(layout.position("ø")).to eq([2, 10])
      end

      it "drops the US bracket and semicolon keys they replace" do
        %w[[ ] ; '].each { |key| expect(layout.position(key)).to be_nil }
      end

      it "makes æ adjacent to ø" do
        expect(layout.distance("æ", "ø")).to eq(1)
      end
    end

    describe Kotoshu::Keyboard::Layouts::Latin::Norwegian do
      let(:layout) { described_class.new }

      include_examples "a Latin family member", %w[nb nb-NO]

      it "shares the Danish physical grid" do
        expect(layout.key_positions).to eq(Kotoshu::Keyboard::Layouts::Latin::Danish.new.key_positions)
      end
    end

    describe Kotoshu::Keyboard::Layouts::Latin::Swedish do
      let(:layout) { described_class.new }

      include_examples "a Latin family member", %w[sv sv-SE]

      it "has real å ä ö keys where Danish has æ ø" do
        expect(layout.position("å")).to eq([1, 10])
        expect(layout.position("ä")).to eq([2, 9])
        expect(layout.position("ö")).to eq([2, 10])
        expect(layout.position("æ")).to be_nil
      end

      it "makes the classic ä/ö slip distance 1" do
        expect(layout.distance("ä", "ö")).to eq(1)
      end
    end
  end

  describe "family hygiene" do
    it "does not change the existing language mappings" do
      expect(Kotoshu::Keyboard.layout_for("en").name).to eq("QWERTY")
      expect(Kotoshu::Keyboard.layout_for("de").name).to eq("QWERTZ")
      expect(Kotoshu::Keyboard.layout_for("fr").name).to eq("AZERTY")
      expect(Kotoshu::Keyboard.layout_for("ru").name).to eq("JCUKEN")
    end

    it "gives uk the dedicated grid instead of the base JCUKEN claim" do
      # Base JCUKEN blanket-claims uk; the registry resolves uk to the
      # Ukrainian layout (registered first) so ґ є і ї have keys.
      expect(Kotoshu::Keyboard.layout_for("uk").name).to eq("Ukrainian-JCUKEN")
      expect(Kotoshu::Keyboard.layout_for("ru").name).to eq("JCUKEN")
    end
  end
end
