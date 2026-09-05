# frozen_string_literal: true

require "spec_helper"
require "kotoshu/keyboard"

RSpec.describe Kotoshu::Keyboard::Layouts::GreekPhonetic do
  let(:layout) { described_class.new }

  describe "phonetic mapping" do
    it "maps each Greek letter to the Latin letter it transliterates to" do
      expect(layout.position("σ")).to eq([1, 1]) # on the w/sigma key
      expect(layout.position("α")).to eq([2, 0]) # on a
      expect(layout.position("ε")).to eq([1, 2]) # on e
      expect(layout.position("ω")).to eq([3, 3]) # on v/omega position
    end

    it "has the full 24-letter Greek alphabet" do
      alphabet = %w[α β γ δ ε ζ η θ ι κ λ μ ν ξ ο π ρ σ τ υ φ χ ψ ω]
      alphabet.each { |key| expect(layout.position(key)).not_to be_nil }
    end

    it "has no accented vowels — accents are dead keys" do
      %w[ά έ ή ί ό ύ ώ].each { |key| expect(layout.position(key)).to be_nil }
    end
  end

  describe "adjacency" do
    it "makes σ adjacent to ε on the top row" do
      expect(layout.distance("σ", "ε")).to eq(1)
    end

    it "makes κ adjacent to λ and ξ" do
      expect(layout.adjacent_keys("κ")).to include("λ", "ξ")
    end

    it "gives the common typo pair ο/π distance 1" do
      expect(layout.distance("ο", "π")).to eq(1)
    end
  end

  describe "language support" do
    it "supports el and el-GR" do
      expect(layout.supports_language?("el")).to be true
      expect(layout.supports_language?("el-GR")).to be true
    end
  end

  describe "registry integration" do
    it "is returned by layout_for for Greek" do
      expect(Kotoshu::Keyboard.layout_for("el")).to be_a(described_class)
      expect(Kotoshu::Keyboard.layout_for("el-GR").name).to eq("Greek-Phonetic")
    end
  end
end
