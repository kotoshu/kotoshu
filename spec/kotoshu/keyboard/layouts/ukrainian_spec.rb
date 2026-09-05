# frozen_string_literal: true

require "spec_helper"
require "kotoshu/keyboard"

RSpec.describe Kotoshu::Keyboard::Layouts::Ukrainian do
  let(:layout) { described_class.new }

  describe "Ukrainian-specific keys" do
    it "places і where Russian JCUKEN has ы" do
      expect(layout.position("і")).to eq([2, 1])
    end

    it "has all four Ukrainian-only letters as real keys" do
      %w[і ї є ґ].each { |key| expect(layout.position(key)).not_to be_nil }
    end

    it "places ґ two keys right of х, beside ї" do
      expect(layout.position("ґ")).to eq([1, 12])
      expect(layout.distance("ї", "ґ")).to eq(1)
    end

    it "has no Russian-only keys" do
      %w[ы ъ э ё].each { |key| expect(layout.position(key)).to be_nil }
    end
  end

  describe "adjacency" do
    it "keeps the JCUKEN top-row order ц у к" do
      expect(layout.distance("ц", "у")).to eq(1)
      expect(layout.distance("у", "к")).to eq(1)
    end

    it "makes і adjacent to ф and в" do
      expect(layout.adjacent_keys("і")).to include("ф", "в")
    end

    it "gives the common typo pair и/т distance 1" do
      expect(layout.distance("и", "т")).to eq(1)
    end
  end

  describe "language support" do
    it "supports uk and uk-UA" do
      expect(layout.supports_language?("uk")).to be true
      expect(layout.supports_language?("uk-UA")).to be true
    end

    it "does not support Russian" do
      expect(layout.supports_language?("ru")).to be false
    end
  end

  describe "registry integration" do
    it "is returned by layout_for for Ukrainian" do
      expect(Kotoshu::Keyboard.layout_for("uk")).to be_a(described_class)
      expect(Kotoshu::Keyboard.layout_for("uk-UA").name).to eq("Ukrainian-JCUKEN")
    end
  end
end
