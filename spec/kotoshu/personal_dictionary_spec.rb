# frozen_string_literal: true

require "kotoshu/personal_dictionary"

RSpec.describe Kotoshu::PersonalDictionary do
  describe ".add_word" do
    it "adds a word to personal dictionary" do
      described_class.add_word("Kotoshu")
      expect(described_class.words).to include("kotoshu")
    end

    it "normalizes to lowercase" do
      described_class.add_word("Kotoshu")
      expect(described_class.words).to include("kotoshu")
    end

    it "prevents duplicates" do
      described_class.add_word("test")
      described_class.add_word("TEST")
      expect(described_class.words.count("test")).to eq(1)
    end
  end

  describe ".remove_word" do
    it "removes a word from personal dictionary" do
      described_class.add_word("test")
      result = described_class.remove_word("test")
      expect(result).to be true
      expect(described_class.words).not_to include("test")
    end

    it "returns false for non-existent word" do
      result = described_class.remove_word("nonexistent")
      expect(result).to be false
    end
  end

  describe ".include?" do
    it "returns true for added words" do
      described_class.add_word("test")
      expect(described_class.include?("test")).to be true
    end

    it "is case-insensitive" do
      described_class.add_word("Test")
      expect(described_class.include?("TEST")).to be true
    end
  end

  describe ".words" do
    it "returns all personal words" do
      described_class.add_word("hello")
      described_class.add_word("world")

      words = described_class.words
      expect(words).to include("hello")
      expect(words).to include("world")
    end
  end
end
