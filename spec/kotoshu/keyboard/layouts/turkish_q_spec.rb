# frozen_string_literal: true

require "spec_helper"
require "kotoshu/keyboard"

RSpec.describe Kotoshu::Keyboard::Layouts::TurkishQ do
  let(:layout) { described_class.new }

  describe "Turkish-specific keys" do
    it "places the dotless ı where QWERTY has i" do
      expect(layout.position("ı")).to eq([1, 7])
    end

    it "places i on the semicolon key position" do
      expect(layout.position("i")).to eq([2, 10])
    end

    it "has all six Turkish letters as real keys" do
      %w[ı ğ ü ş ö ç].each { |key| expect(layout.position(key)).not_to be_nil }
    end

    it "has no semicolon or bracket keys" do
      expect(layout.position(";")).to be_nil
      expect(layout.position("[")).to be_nil
    end
  end

  describe "adjacency" do
    it "makes ı adjacent to u and o on the top row" do
      expect(layout.adjacent_keys("ı")).to include("u", "o")
    end

    it "makes ş adjacent to l and i on the home row" do
      expect(layout.adjacent_keys("ş")).to include("l", "i")
    end

    it "gives ğ and ü distance 1" do
      expect(layout.distance("ğ", "ü")).to eq(1)
    end

    it "gives the classic Turkish typo pair ı/o distance 1" do
      expect(layout.distance("ı", "o")).to eq(1)
    end
  end

  describe "language support" do
    it "supports tr and tr-TR" do
      expect(layout.supports_language?("tr")).to be true
      expect(layout.supports_language?("tr-TR")).to be true
    end

    it "does not support other languages" do
      expect(layout.supports_language?("en")).to be false
      expect(layout.supports_language?("ru")).to be false
    end
  end

  describe "registry integration" do
    it "is returned by layout_for for Turkish" do
      expect(Kotoshu::Keyboard.layout_for("tr")).to be_a(described_class)
      expect(Kotoshu::Keyboard.layout_for("tr-TR").name).to eq("Turkish-Q")
    end

    it "is found by name" do
      expect(Kotoshu::Keyboard.layout_by_name("Turkish-Q")).to be_a(described_class)
    end
  end
end
