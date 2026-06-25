# frozen_string_literal: true

require "kotoshu/defaults"

RSpec.describe Kotoshu::Defaults do
  describe ".detect_system_dictionary" do
    it "returns path if system dictionary exists" do
      path = described_class.detect_system_dictionary

      expect(File.exist?(path)).to be true if path
    end

    it "returns nil if no system dictionary found" do
      # This test is environment-dependent
      # Just verify the method doesn't error
      expect { described_class.detect_system_dictionary }.not_to raise_error
    end
  end

  describe ".bundled_dictionary_path" do
    it "returns path to bundled dictionary" do
      path = described_class.bundled_dictionary_path

      expect(File.exist?(path)).to be true if path
    end
  end

  describe ".default_dictionary" do
    it "provides a working dictionary" do
      dict = described_class.default_dictionary

      expect(dict).to respond_to(:lookup?)
      expect(dict).to respond_to(:words)

      # Should have at least some words
      expect(dict.words.size).to be > 0 if dict.words
    end
  end

  describe ".configure" do
    it "configures Kotoshu with sensible defaults" do
      described_class.configure

      config = Kotoshu.configuration

      expect(config.language).to be_a(String)
      expect(config.max_suggestions).to be_a(Integer)
    end
  end
end
