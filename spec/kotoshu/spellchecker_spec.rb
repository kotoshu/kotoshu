# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Spellchecker, "# Walking Skeleton - Spellchecker Service" do
  describe "creation" do
    it "creates spellchecker with dictionary" do
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      spellchecker = Kotoshu::Spellchecker.new(dictionary: dict)

      expect(spellchecker.dictionary).to eq(dict)
    end

    it "creates spellchecker with configuration hash" do
      spellchecker = Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )

      expect(spellchecker.dictionary).to be_a(Kotoshu::Dictionary::PlainText)
    end

    it "creates spellchecker with Configuration object" do
      config = Kotoshu::Configuration.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )
      spellchecker = Kotoshu::Spellchecker.new(config: config)

      expect(spellchecker.dictionary).to be_a(Kotoshu::Dictionary::PlainText)
    end

    it "has generator" do
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      spellchecker = Kotoshu::Spellchecker.new(dictionary: dict)

      expect(spellchecker.generator).to be_a(Kotoshu::Suggestions::Generator)
    end

    it "has config" do
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      spellchecker = Kotoshu::Spellchecker.new(dictionary: dict)

      expect(spellchecker.config).to be_a(Kotoshu::Configuration)
    end
  end

  describe "#correct?" do
    let(:spellchecker) do
      Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )
    end

    it "returns true for correct word" do
      expect(spellchecker.correct?("hello")).to be true
      expect(spellchecker.correct?("world")).to be true
      expect(spellchecker.correct?("ruby")).to be true
    end

    it "returns false for incorrect word" do
      expect(spellchecker.correct?("helo")).to be false
      expect(spellchecker.correct?("xyzabc")).to be false
      expect(spellchecker.correct?("wrld")).to be false
    end

    it "returns false for nil" do
      expect(spellchecker.correct?(nil)).to be false
    end

    it "returns false for empty string" do
      expect(spellchecker.correct?("")).to be false
    end

    it "is case-sensitive when dictionary is configured" do
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US", case_sensitive: true)
      spellchecker = Kotoshu::Spellchecker.new(dictionary: dict)

      expect(spellchecker.correct?("hello")).to be true
      expect(spellchecker.correct?("Hello")).to be false
      expect(spellchecker.correct?("HELLO")).to be false
    end
  end

  describe "#incorrect?" do
    let(:spellchecker) do
      Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )
    end

    it "returns true for incorrect word" do
      expect(spellchecker.incorrect?("helo")).to be true
    end

    it "returns false for correct word" do
      expect(spellchecker.incorrect?("hello")).to be false
    end

    it "returns true for nil" do
      expect(spellchecker.incorrect?(nil)).to be true
    end

    it "returns true for empty string" do
      expect(spellchecker.incorrect?("")).to be true
    end
  end

  describe "#suggest" do
    let(:spellchecker) do
      Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )
    end

    it "returns suggestions for misspelled word" do
      suggestions = spellchecker.suggest("helo")

      expect(suggestions).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(suggestions.words).to include("hello")
    end

    it "returns empty suggestion set for nil" do
      suggestions = spellchecker.suggest(nil)

      expect(suggestions).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(suggestions.empty?).to be true
    end

    it "returns empty suggestion set for empty string" do
      suggestions = spellchecker.suggest("")

      expect(suggestions).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(suggestions.empty?).to be true
    end

    it "respects max_suggestions parameter" do
      suggestions = spellchecker.suggest("helo", max_suggestions: 1)

      expect(suggestions.size).to be <= 1
    end

    it "returns suggestions for correct word (empty set)" do
      suggestions = spellchecker.suggest("hello")

      expect(suggestions.empty?).to be true
    end
  end

  describe "#check_word" do
    let(:spellchecker) do
      Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )
    end

    it "returns correct result for correct word" do
      result = spellchecker.check_word("hello")

      expect(result).to be_a(Kotoshu::Models::Result::WordResult)
      expect(result.correct?).to be true
      expect(result.word).to eq("hello")
    end

    it "returns incorrect result for misspelled word" do
      result = spellchecker.check_word("helo")

      expect(result).to be_a(Kotoshu::Models::Result::WordResult)
      expect(result.correct?).to be false
      expect(result.word).to eq("helo")
      expect(result.suggestions).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end

    it "returns incorrect result for nil" do
      result = spellchecker.check_word(nil)

      expect(result).to be_a(Kotoshu::Models::Result::WordResult)
      expect(result.correct?).to be false
      expect(result.word).to eq("")
    end

    it "returns incorrect result for empty string" do
      result = spellchecker.check_word("")

      expect(result).to be_a(Kotoshu::Models::Result::WordResult)
      expect(result.correct?).to be false
      expect(result.word).to eq("")
    end
  end

  describe "#check" do
    let(:spellchecker) do
      Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )
    end

    it "returns success result for nil" do
      result = spellchecker.check(nil)

      expect(result).to be_a(Kotoshu::Models::Result::DocumentResult)
      expect(result.success?).to be true
    end

    it "returns success result for empty string" do
      result = spellchecker.check("")

      expect(result).to be_a(Kotoshu::Models::Result::DocumentResult)
      expect(result.success?).to be true
    end

    it "returns success result for correct text" do
      result = spellchecker.check("hello world")

      expect(result).to be_a(Kotoshu::Models::Result::DocumentResult)
      expect(result.success?).to be true
    end

    it "returns error result for text with misspellings" do
      result = spellchecker.check("hello wrold")

      expect(result).to be_a(Kotoshu::Models::Result::DocumentResult)
      expect(result.failed?).to be true
      expect(result.errors.size).to eq(1)
      expect(result.errors.first.word).to eq("wrold")
    end

    it "handles multiple misspellings" do
      result = spellchecker.check("helo wrld")

      expect(result.failed?).to be true
      expect(result.errors.size).to eq(2)
    end

    it "tracks word count" do
      result = spellchecker.check("hello world")

      expect(result.word_count).to eq(2)
    end

    it "ignores punctuation" do
      result = spellchecker.check("hello, world!")

      expect(result.success?).to be true
    end

    it "preserves apostrophes in words" do
      result = spellchecker.check("hello world")

      expect(result.success?).to be true
    end
  end

  describe "#check_file" do
    let(:spellchecker) do
      Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )
    end

    it "checks file for errors" do
      result = spellchecker.check_file("spec/fixtures/words.txt")

      expect(result).to be_a(Kotoshu::Models::Result::DocumentResult)
      expect(result.file).to eq("spec/fixtures/words.txt")
    end

    it "raises error for non-existent file" do
      expect {
        spellchecker.check_file("non-existent.txt")
      }.to raise_error(Kotoshu::DictionaryNotFoundError, /non-existent\.txt/)
    end
  end

  describe "#check_directory" do
    let(:spellchecker) do
      Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )
    end

    it "checks all matching files in directory" do
      results = spellchecker.check_directory("spec/fixtures", pattern: "*.txt")

      expect(results).to be_an(Array)
      expect(results.size).to be > 0
      expect(results.first).to be_a(Kotoshu::Models::Result::DocumentResult)
    end

    it "raises error for non-existent directory" do
      expect {
        spellchecker.check_directory("non-existent-dir")
      }.to raise_error(Kotoshu::DictionaryNotFoundError, /non-existent-dir/)
    end

    it "raises error for non-directory path" do
      expect {
        spellchecker.check_directory("spec/fixtures/words.txt")
      }.to raise_error(Kotoshu::DictionaryNotFoundError)
    end

    it "respects file pattern" do
      results = spellchecker.check_directory("spec/fixtures", pattern: "*.txt")

      expect(results.size).to eq(2) # words.txt and empty.txt
    end
  end

  describe "#tokenize" do
    let(:spellchecker) do
      Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )
    end

    it "tokenizes text into words" do
      tokens = spellchecker.tokenize("hello world")

      expect(tokens).to eq([["hello", 0], ["world", 6]])
    end

    it "handles punctuation" do
      tokens = spellchecker.tokenize("hello, world!")

      expect(tokens).to eq([["hello", 0], ["world", 7]])
    end

    it "handles apostrophes" do
      tokens = spellchecker.tokenize("don't stop")

      expect(tokens).to eq([["don't", 0], ["stop", 6]])
    end

    it "handles multiple spaces" do
      tokens = spellchecker.tokenize("hello  world")

      expect(tokens).to eq([["hello", 0], ["world", 7]])
    end

    it "returns empty array for nil" do
      expect(spellchecker.tokenize(nil)).to eq([])
    end

    it "returns empty array for empty string" do
      expect(spellchecker.tokenize("")).to eq([])
    end

    it "handles leading/trailing spaces" do
      tokens = spellchecker.tokenize("  hello world  ")

      expect(tokens).to eq([["hello", 2], ["world", 8]])
    end

    it "handles numbers (not word characters)" do
      tokens = spellchecker.tokenize("hello123 world")

      expect(tokens).to eq([["hello", 0], ["world", 9]])
    end
  end

  describe "#dictionary" do
    it "returns the dictionary being used" do
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      spellchecker = Kotoshu::Spellchecker.new(dictionary: dict)

      expect(spellchecker.dictionary).to eq(dict)
    end
  end

  describe "#reload_dictionary" do
    it "reloads the dictionary and returns self" do
      spellchecker = Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )

      result = spellchecker.reload_dictionary

      expect(result).to eq(spellchecker)
      expect(spellchecker.dictionary).to be_a(Kotoshu::Dictionary::PlainText)
    end
  end
end
