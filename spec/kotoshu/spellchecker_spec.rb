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
      expect(result.suggestions).to all(be_a(Kotoshu::Suggestions::Suggestion))
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

    it "skips suggestion generation when suggestions is false" do
      result = spellchecker.check("hello wrold", suggestions: false)

      expect(result.failed?).to be true
      expect(result.errors.first.word).to eq("wrold")
      expect(result.errors.first.suggestions.to_a).to be_empty
    end

    it "skips the sweep for occurrences the filter declines" do
      budget = { "wrold" => 1 }
      filter = lambda do |word|
        if budget[word].positive?
          budget[word] -= 1
          false
        else
          true
        end
      end

      result = spellchecker.check("wrold wrold", suggestions_filter: filter)

      expect(result.errors.size).to eq(2)
      first, second = result.errors
      expect(first.suggestions.to_a).to be_empty
      expect(second.suggestions.to_a).not_to be_empty
    end

    it "still skips everything when suggestions is false alongside a filter" do
      result = spellchecker.check("wrold", suggestions: false, suggestions_filter: ->(_) { true })

      expect(result.errors.first.suggestions.to_a).to be_empty
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
      expect do
        spellchecker.check_file("non-existent.txt")
      end.to raise_error(Kotoshu::DictionaryNotFoundError, /non-existent\.txt/)
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
      expect do
        spellchecker.check_directory("non-existent-dir")
      end.to raise_error(Kotoshu::DictionaryNotFoundError, /non-existent-dir/)
    end

    it "raises error for non-directory path" do
      expect do
        spellchecker.check_directory("spec/fixtures/words.txt")
      end.to raise_error(Kotoshu::DictionaryNotFoundError)
    end

    it "respects file pattern" do
      results = spellchecker.check_directory("spec/fixtures", pattern: "*.txt")

      expect(results.size).to eq(2) # words.txt and empty.txt
    end
  end

  describe "#tokenize script-aware extraction (plan 91)" do
    def spellchecker_for(language)
      Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",

        dictionary_type: :plain_text,

        language: language
      )
    end

    it "extracts Greek words for el" do
      tokens = spellchecker_for("el").tokenize("Η ελληνική γλώσσα είναι όμορφη")

      expect(tokens.map(&:first)).to eq(["Η", "ελληνική", "γλώσσα", "είναι", "όμορφη"])
    end

    it "keeps the in-word apostrophe for uk" do
      tokens = spellchecker_for("uk").tokenize("Маряна Павличко")

      expect(tokens.map(&:first)).to eq(["Маряна", "Павличко"])
    end

    it "extracts nothing for el from wrong-script words" do
      expect(spellchecker_for("el").tokenize("hello привіт")).to eq([])
    end

    it "extracts nothing for uk from wrong-script words" do
      expect(spellchecker_for("uk").tokenize("hello ελληνικά")).to eq([])
    end

    it "keeps Latin capitals and accents for sv" do
      tokens = spellchecker_for("sv").tokenize("Året på Älvsjö äng")

      expect(tokens.map(&:first)).to eq(["Året", "på", "Älvsjö", "äng"])
    end

    it "still splits digits away from words for sv" do
      tokens = spellchecker_for("sv").tokenize("42abc")

      expect(tokens.map(&:first)).to eq(["abc"])
    end

    it "extracts nothing from pure Japanese text on the per-character path" do
      # CJK has no per-character word segmentation; the Japanese

      # morphological (suika) path handles ja elsewhere. The guard is

      # that the spellchecker reports no bogus tokens and never raises.

      expect(spellchecker_for("ja").tokenize("すももももももものうち")).to eq([])
    end

    it "follows the resource bundle language when a shared config is passed" do
      # Facade shape used by kotoshu check -l LANG: spellchecker_for
      # passes the global Configuration next to the resolved bundle,
      # so the bundle, not the config default, pins the language.
      bundle = Kotoshu::ResourceBundle.new(
        language: "el",
        dictionary: Kotoshu::Dictionary::PlainText.new("spec/fixtures/words.txt", language_code: "el")
      )
      config = Kotoshu::Configuration.new(language: "en-US")
      spellchecker = described_class.new(resource_bundle: bundle, config: config)
      expect(spellchecker.tokenize("ελληνικά text").map(&:first)).to eq(["ελληνικά"])
    end

    it "keeps the historical ASCII extraction for en" do
      tokens = spellchecker_for("en").tokenize("hello world, don't stop")

      expect(tokens.map(&:first)).to eq(["hello", "world", "don't", "stop"])
    end

    it "keeps the historical ASCII extraction for de" do
      # German has no script tokenizer override yet, so the ASCII

      # fallback applies exactly as before (plan 91 regression guard).

      tokens = spellchecker_for("de").tokenize("Schöne Grüße 42abc")

      expect(tokens.map(&:first)).to eq(["Sch", "ne", "Gr", "e", "abc"])
    end
  end

  describe "#tokenize module-less script fallback (plan 107)" do
    def spellchecker_for(language)
      Kotoshu::Spellchecker.new(
        dictionary_path: "spec/fixtures/words.txt",

        dictionary_type: :plain_text,

        language: language
      )
    end

    it "extracts accented Latin words for module-less staged languages" do
      tokens = spellchecker_for("is").tokenize("Þetta er íslenskur texti")
      expect(tokens.map(&:first)).to eq(["Þetta", "er", "íslenskur", "texti"])

      tokens = spellchecker_for("cy").tokenize("Mae hwn yn Gymraeg")
      expect(tokens.map(&:first)).to eq(["Mae", "hwn", "yn", "Gymraeg"])

      tokens = spellchecker_for("gd").tokenize("Seo teacs Gàidhlig")
      expect(tokens.map(&:first)).to eq(["Seo", "teacs", "Gàidhlig"])
    end

    it "extracts Cyrillic words for module-less mk" do
      tokens = spellchecker_for("mk").tokenize("ова е македонски текст")
      expect(tokens.map(&:first)).to eq(["ова", "е", "македонски", "текст"])
    end

    it "extracts eojeol runs through the ko module tokenizer (plan 108)" do
      tokens = spellchecker_for("ko").tokenize("한국어 텍스트입니다")
      expect(tokens.map(&:first)).to eq(["한국어", "텍스트입니다"])
    end

    it "keeps Devanagari matras attached through the ne module tokenizer (plan 108)" do
      tokens = spellchecker_for("ne").tokenize("यो नेपाली पाठ हो")
      expect(tokens.map(&:first)).to eq(["यो", "नेपाली", "पाठ", "हो"])
    end

    it "extracts Armenian words for module-less hyw" do
      tokens = spellchecker_for("hyw").tokenize("հայերէն լեզու")
      expect(tokens.map(&:first)).to eq(["հայերէն", "լեզու"])
    end

    it "keeps the ASCII fallback for unknown languages" do
      tokens = spellchecker_for("xx").tokenize("Schöne Grüße")
      expect(tokens.map(&:first)).to eq(["Sch", "ne", "Gr", "e"])
    end

    it "still prefers a registered module over the script fallback" do
      # et has a module; the module tokenizer must win, byte-identical
      # to before plan 107 (both are the Latin tokenizer here, but the
      # registry path is what resolves it).
      expect(spellchecker_for("et").tokenize("õppekool Pärnus").map(&:first))
        .to eq(["õppekool", "Pärnus"])
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
