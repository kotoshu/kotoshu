# frozen_string_literal: true

require "kotoshu/fluent_checker"

RSpec.describe Kotoshu::Spellchecker::FluentChecker do
  let(:spellchecker) { Kotoshu::Spellchecker.new(dictionary: Kotoshu::Dictionary::PlainText.from_words(%w[hello world], language_code: "en")) }
  let(:fluent) { described_class.new(spellchecker: spellchecker) }

  describe "#initialize" do
    it "creates fluent checker with spellchecker" do
      expect(fluent.spellchecker).to eq(spellchecker)
    end

    it "stores options" do
      f = described_class.new(spellchecker: spellchecker, options: { max_suggestions: 5 })
      expect(f.options[:max_suggestions]).to eq(5)
    end
  end

  describe "#check" do
    it "checks text for errors" do
      result = fluent.check("hello world")
      expect(result).to be_a(Kotoshu::Models::Result::DocumentResult)
    end

    it "finds misspelled words" do
      result = fluent.check("hello wrld")
      expect(result.errors.size).to eq(1)
    end
  end

  describe "#ignore_words" do
    it "stores ignore pattern" do
      pattern = %r{https?://\S+}
      result = fluent.ignore_words(pattern)
      expect(result.options[:ignore_patterns]).to include(pattern)
    end

    it "returns self for chaining" do
      result = fluent.ignore_words(/test/).max_suggestions(5)
      expect(result).to be(fluent)
    end
  end

  describe "#max_suggestions" do
    it "sets max suggestions option" do
      result = fluent.max_suggestions(5)
      expect(result.options[:max_suggestions]).to eq(5)
    end

    it "returns self for chaining" do
      result = fluent.max_suggestions(5)
      expect(result).to be(result)
    end
  end

  describe "#on_progress" do
    it "sets progress callback" do
      called = false
      fluent.on_progress { called = true }
      expect(fluent).to be(fluent)
    end
  end

  describe "#on_error" do
    it "sets error callback" do
      called = false
      fluent.on_error { called = true }
      expect(fluent).to be(fluent)
    end
  end
end
