# frozen_string_literal: true

require "spec_helper"
require "kotoshu/resource_bundle"

RSpec.describe Kotoshu::ResourceBundle do
  describe "#initialize" do
    it "accepts keyword arguments" do
      bundle = described_class.new(
        language: "en",
        dictionary: nil,
        frequency: nil,
        model: nil,
        rules: nil,
        cached: true,
        source_urls: ["https://example.com"]
      )

      expect(bundle.language).to eq("en")
      expect(bundle.dictionary).to be_nil
      expect(bundle.cached).to eq(true)
      expect(bundle.source_urls).to eq(["https://example.com"])
    end

    it "defaults to nil for all resource fields" do
      bundle = described_class.new(language: "en")

      expect(bundle.language).to eq("en")
      expect(bundle.dictionary).to be_nil
      expect(bundle.frequency).to be_nil
      expect(bundle.model).to be_nil
      expect(bundle.rules).to be_nil
      expect(bundle.cached).to be_nil
      expect(bundle.source_urls).to be_nil
    end
  end

  describe "#cached?" do
    it "returns true when cached is true" do
      bundle = described_class.new(language: "en", cached: true)
      expect(bundle.cached?).to eq(true)
    end

    it "returns false when cached is false" do
      bundle = described_class.new(language: "en", cached: false)
      expect(bundle.cached?).to eq(false)
    end

    it "returns false when cached is nil" do
      bundle = described_class.new(language: "en")
      expect(bundle.cached?).to eq(false)
    end
  end

  describe "resource presence predicates" do
    it "reports presence of a dictionary" do
      dict = Struct.new(:name).new("dummy")
      bundle = described_class.new(language: "en", dictionary: dict)

      expect(bundle.has_frequency?).to eq(false)
      expect(bundle.has_model?).to eq(false)
      expect(bundle.has_rules?).to eq(false)
    end

    it "reports presence of frequency data" do
      bundle = described_class.new(language: "en", frequency: { top_50: [] })
      expect(bundle.has_frequency?).to eq(true)
    end

    it "reports presence of a model" do
      bundle = described_class.new(language: "en", model: Object.new)
      expect(bundle.has_model?).to eq(true)
    end

    it "reports presence of rules" do
      bundle = described_class.new(language: "en", rules: [])
      expect(bundle.has_rules?).to eq(true)
    end
  end

  describe "Struct equality" do
    it "compares by value" do
      a = described_class.new(language: "en", cached: true)
      b = described_class.new(language: "en", cached: true)
      c = described_class.new(language: "de", cached: true)

      expect(a).to eq(b)
      expect(a).not_to eq(c)
    end
  end
end
