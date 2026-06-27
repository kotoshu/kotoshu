# frozen_string_literal: true

require "spec_helper"
require "kotoshu/cli/language_resolver"

RSpec.describe Kotoshu::Cli::LanguageResolver do
  let(:en_setup?) { true } # mutated per-test below via the predicate lambda
  let(:setup_states) { { "en" => true } }

  let(:detector) do
    detected = method(:detected_value)
    obj = Object.new
    obj.define_singleton_method(:detect) { |text| detected.call(text) }
    obj
  end

  let(:setup_predicate) do
    states = setup_states
    lambda { |lang| states[lang.to_s] == true }
  end

  def detected_value(_text)
    "en"
  end

  def resolver(flag_value:, default_language: "en")
    described_class.new(
      flag_value: flag_value,
      default_language: default_language,
      detector: detector,
      setup_predicate: setup_predicate
    )
  end

  describe "explicit language code" do
    it "uses the flag value without detection" do
      result = resolver(flag_value: "de").resolve(text: "Hallo Welt")

      expect(result.language).to eq("de")
      expect(result.detected).to be_nil
      expect(result.note).to be_nil
    end

    it "does not call the detector" do
      expect(detector).not_to receive(:detect)
      resolver(flag_value: "fr").resolve(text: "Bonjour")
    end
  end

  describe "'default' keyword" do
    it "uses the configured default language" do
      result = resolver(flag_value: "default", default_language: "es")
                          .resolve(text: "Hola")

      expect(result.language).to eq("es")
      expect(result.detected).to be_nil
      expect(result.note).to be_nil
    end
  end

  describe "'auto' with successful detection" do
    it "uses the detected language when it is set up" do
      allow(self).to receive(:detected_value).and_return("en")
      result = resolver(flag_value: "auto").resolve(text: "Hello world")

      expect(result.language).to eq("en")
      expect(result.detected).to eq("en")
      expect(result.note).to eq("Detected: en.")
    end

    it "falls back when detected language is not set up" do
      allow(self).to receive(:detected_value).and_return("de")
      result = resolver(flag_value: "auto", default_language: "en")
                          .resolve(text: "Hallo Welt")

      expect(result.language).to eq("en")
      expect(result.detected).to eq("de")
      expect(result.fallback).to eq("en")
      expect(result.note).to eq("Detected: de (fallback: en).")
    end

    it "falls back when detection returns nil" do
      allow(self).to receive(:detected_value).and_return(nil)
      result = resolver(flag_value: "auto", default_language: "en")
                          .resolve(text: "")

      expect(result.language).to eq("en")
      expect(result.detected).to be_nil
      expect(result.note).to include("No language detected")
    end
  end

  describe "normalization" do
    it "strips region suffixes before checking setup" do
      allow(self).to receive(:detected_value).and_return("en-US")
      result = resolver(flag_value: "auto").resolve(text: "Hello")

      expect(result.detected).to eq("en")
    end
  end

  describe "detector failures" do
    it "swallows exceptions from the detector and falls back" do
      detector = Object.new
      detector.define_singleton_method(:detect) { raise StandardError, "boom" }
      resolver = described_class.new(
        flag_value: "auto",
        default_language: "en",
        detector: detector,
        setup_predicate: setup_predicate
      )

      result = resolver.resolve(text: "anything")
      expect(result.language).to eq("en")
      expect(result.detected).to be_nil
      expect(result.note).to include("No language detected")
    end
  end
end
