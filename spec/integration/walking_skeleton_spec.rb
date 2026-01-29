# frozen_string_literal: true

require "spec_helper"

RSpec.describe "Walking Skeleton Integration", "# Walking Skeleton - End-to-End Integration" do
  describe "full spellchecking workflow" do
    let(:spellchecker) do
      Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )
    end

    it "checks a single word" do
      result = spellchecker.check_word("hello")

      expect(result.correct?).to be true
      expect(result.word).to eq("hello")
    end

    it "detects misspelled word with suggestions" do
      result = spellchecker.check_word("helo")

      expect(result.correct?).to be false
      expect(result.word).to eq("helo")
      expect(result.has_suggestions?).to be true
      expect(result.suggestions.words).to include("hello")
    end

    it "checks text with multiple words" do
      result = spellchecker.check("hello world ruby")

      expect(result.success?).to be true
      expect(result.word_count).to eq(3)
    end

    it "detects errors in text" do
      result = spellchecker.check("hello wrold ruby")

      expect(result.failed?).to be true
      expect(result.errors.size).to eq(1)
      expect(result.errors.first.word).to eq("wrold")
    end

    it "checks file for errors" do
      result = spellchecker.check_file("spec/fixtures/words.txt")

      expect(result.file).to eq("spec/fixtures/words.txt")
      expect(result.word_count).to be > 0
    end

    it "uses repository for dictionary management" do
      repo = Kotoshu::Dictionary::Repository.new
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")

      repo.register(:en_US, dict)
      expect(repo.registered?(:en_US)).to be true
      expect(repo[:en_US]).to eq(dict)
    end

    it "iterates through repository" do
      repo = Kotoshu::Dictionary::Repository.new
      dict1 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US")
      dict2 = Kotoshu::Dictionary::PlainText.new("spec/fixtures/empty.txt", language_code: "en-US")

      repo.register(:main, dict1)
      repo.register(:empty, dict2)

      keys = []
      repo.each { |key, _| keys << key }
      expect(keys).to contain_exactly(:main, :empty)
    end

    it "performs case-insensitive lookup by default" do
      expect(spellchecker.correct?("hello")).to be true
      expect(spellchecker.correct?("HELLO")).to be true
      expect(spellchecker.correct?("Hello")).to be true
    end

    it "performs case-sensitive lookup when configured" do
      dict = Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "en-US", case_sensitive: true)
      checker = Kotoshu::Spellchecker.new(dictionary: dict)

      expect(checker.correct?("hello")).to be true
      expect(checker.correct?("HELLO")).to be false
    end

    it "handles empty dictionary" do
      checker = Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/empty.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )

      expect(checker.correct?("hello")).to be false
      expect(checker.dictionary.empty?).to be true
    end

    it "checks entire directory" do
      results = spellchecker.check_directory("spec/fixtures", pattern: "*.txt")

      expect(results).to be_an(Array)
      expect(results.size).to eq(2) # words.txt and empty.txt
    end

    it "uses Word VALUE object" do
      word1 = Kotoshu::Models::Word.new("hello")
      word2 = Kotoshu::Models::Word.new("hello")

      expect(word1).to eq(word2)
      expect(word1.hash).to eq(word2.hash)
      expect(word1).to be_frozen
    end

    it "parses Word from dictionary line" do
      word = Kotoshu::Models::Word.from_dic_line("hello/NV")

      expect(word.text).to eq("hello")
      expect(word.flags).to eq(["N", "V"])
    end

    it "creates SuggestionSet from words" do
      suggestions = Kotoshu::Suggestions::SuggestionSet.from_words(%w[hello help], source: :test)

      expect(suggestions.size).to eq(2)
      expect(suggestions.words).to contain_exactly("hello", "help")
    end

    it "merges suggestion sets" do
      set1 = Kotoshu::Suggestions::SuggestionSet.from_words(%w[hello], source: :test1)
      set2 = Kotoshu::Suggestions::SuggestionSet.from_words(%w[help], source: :test2)

      merged = set1.dup.merge!(set2)

      expect(merged.size).to eq(2)
      expect(merged.words).to contain_exactly("hello", "help")
    end

    it "tokenizes text correctly" do
      tokens = spellchecker.tokenize("Hello, world!")

      expect(tokens.size).to eq(2)
      expect(tokens.map(&:first)).to eq(["Hello", "world"])
    end

    it "reloads dictionary" do
      result = spellchecker.reload_dictionary

      expect(result).to eq(spellchecker)
      expect(spellchecker.dictionary).to be_a(Kotoshu::Dictionary::PlainText)
    end
  end

  describe "configuration management" do
    it "creates configuration with defaults" do
      config = Kotoshu::Configuration.new

      expect(config.language).to eq("en-US")
      expect(config.max_suggestions).to eq(10)
      expect(config.case_sensitive).to be false
    end

    it "creates configuration with custom settings" do
      config = Kotoshu::Configuration.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-GB",
        max_suggestions: 20
      )

      expect(config.dictionary_path).to eq("spec/fixtures/words.txt")
      expect(config.dictionary_type).to eq(:plain_text)
      expect(config.language).to eq("en-GB")
      expect(config.max_suggestions).to eq(20)
    end

    it "loads dictionary from configuration" do
      config = Kotoshu::Configuration.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )

      dict = config.dictionary

      expect(dict).to be_a(Kotoshu::Dictionary::PlainText)
      expect(dict.size).to be > 0
    end

    it "uses global configuration instance" do
      Kotoshu::Configuration.reset

      Kotoshu::Configuration.instance.dictionary_path = "spec/fixtures/words.txt"
      Kotoshu::Configuration.instance.dictionary_type = :plain_text

      expect(Kotoshu::Configuration.instance.dictionary_path).to eq("spec/fixtures/words.txt")

      Kotoshu::Configuration.reset
    end
  end

  describe "error handling" do
    let(:spellchecker) do
      Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )
    end

    it "handles nil input gracefully" do
      expect(spellchecker.correct?(nil)).to be false
      expect(spellchecker.suggest(nil).empty?).to be true
      expect(spellchecker.check(nil).success?).to be true
      expect(spellchecker.tokenize(nil)).to eq([])
    end

    it "handles empty input gracefully" do
      expect(spellchecker.correct?("")).to be false
      expect(spellchecker.suggest("").empty?).to be true
      expect(spellchecker.check("").success?).to be true
      expect(spellchecker.tokenize("")).to eq([])
    end

    it "raises error for non-existent file" do
      expect {
        spellchecker.check_file("non-existent.txt")
      }.to raise_error(Kotoshu::DictionaryNotFoundError)
    end

    it "raises error for non-existent directory" do
      expect {
        spellchecker.check_directory("non-existent-dir")
      }.to raise_error(Kotoshu::DictionaryNotFoundError)
    end
  end

  describe "WordResult value object" do
    it "creates correct result" do
      result = Kotoshu::Models::Result::WordResult.correct("hello")

      expect(result.correct?).to be true
      expect(result.word).to eq("hello")
      expect(result.has_suggestions?).to be false
    end

    it "creates incorrect result with suggestions" do
      suggestions = Kotoshu::Suggestions::SuggestionSet.from_words(%w[hello help], source: :test)
      result = Kotoshu::Models::Result::WordResult.incorrect("helo", suggestions: suggestions)

      expect(result.correct?).to be false
      expect(result.word).to eq("helo")
      expect(result.has_suggestions?).to be true
      expect(result.top_suggestions(2)).to eq(%w[hello help])
    end

    it "provides first suggestion" do
      suggestions = Kotoshu::Suggestions::SuggestionSet.from_words(%w[hello help], source: :test)
      result = Kotoshu::Models::Result::WordResult.incorrect("helo", suggestions: suggestions)

      expect(result.first_suggestion).to eq("hello")
    end

    it "converts to hash" do
      result = Kotoshu::Models::Result::WordResult.correct("hello")

      hash = result.to_h

      expect(hash).to eq({
        word: "hello",
        correct: true,
        position: nil,
        suggestion_count: 0,
        suggestions: [],
        metadata: {}
      })
    end

    it "supports value equality" do
      result1 = Kotoshu::Models::Result::WordResult.correct("hello")
      result2 = Kotoshu::Models::Result::WordResult.correct("hello")

      expect(result1).to eq(result2)
      expect(result1.hash).to eq(result2.hash)
    end
  end

  describe "DocumentResult value object" do
    let(:spellchecker) do
      Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",
        dictionary_type: :plain_text,
        language: "en-US"
      )
    end

    it "returns success for correct text" do
      result = spellchecker.check("hello world")

      expect(result.success?).to be true
      expect(result.failed?).to be false
      expect(result.errors).to eq([])
    end

    it "returns errors for incorrect text" do
      result = spellchecker.check("hello wrold")

      expect(result.failed?).to be true
      expect(result.success?).to be false
      expect(result.errors.size).to eq(1)
    end

    it "includes word count" do
      result = spellchecker.check("hello world ruby")

      expect(result.word_count).to eq(3)
    end

    it "tracks error positions" do
      result = spellchecker.check("hello wrold")

      expect(result.errors.first.position).to eq(6)
    end
  end
end
