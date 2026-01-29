require "spec_helper"

RSpec.describe Kotoshu::Dictionary::PlainText, "# Walking Skeleton - PlainText Dictionary" do
  describe "creation and loading" do
    let(:words_file) { "spec/fixtures/words.txt" }
    let(:language_code) { "en-US" }

    it "loads dictionary from file path" do
      dictionary = Kotoshu::Dictionary::PlainText.new(
        words_file,
        language_code: language_code
      )

      expect(dictionary.size).to be > 0
      expect(dictionary.language_code).to eq("en-US")
    end

    it "loads words from file system path" do
      dictionary = Kotoshu::Dictionary::PlainText.new(
        "/usr/share/dict/words",
        language_code: "en-US"
      )

      # Will fail if file doesn't exist, but structure is correct
      expect(dictionary.class).to eq(Kotoshu::Dictionary::PlainText)
    end
  end

  describe "#lookup" do
    let(:dictionary) do
      Kotoshu::Dictionary::PlainText.new(
        "spec/fixtures/words.txt",
        language_code: "en-US"
      )
    end

    context "when word exists in dictionary" do
      it "returns true for exact match" do
        expect(dictionary.lookup("hello")).to be true
        expect(dictionary.lookup("world")).to be true
        expect(dictionary.lookup("ruby")).to be true
      end

      it "returns true for case-insensitive match when configured" do
        dict = Kotoshu::Dictionary::PlainText.new(
          "spec/fixtures/words.txt",
          language_code: "en-US",
          case_sensitive: false
        )

        expect(dict.lookup("hello")).to be true
        expect(dict.lookup("HELLO")).to be true
        expect(dict.lookup("Hello")).to be true
      end

      it "returns false for case-sensitive mismatch" do
        dict = Kotoshu::Dictionary::PlainText.new(
          "spec/fixtures/words.txt",
          language_code: "en-US",
          case_sensitive: true
        )

        expect(dict.lookup("hello")).to be true
        expect(dict.lookup("HELLO")).to be false
      end
    end

    context "when word does not exist in dictionary" do
      it "returns false" do
        expect(dictionary.lookup("nonexistent")).to be false
        expect(dictionary.lookup("xyzabc")).to be false
      end
    end

    context "when dictionary is empty" do
      it "returns false for all words" do
        dict = Kotoshu::Dictionary::PlainText.new(
          "spec/fixtures/empty.txt",
          language_code: "en-US"
        )

        expect(dict.lookup("hello")).to be false
      end
    end
  end

  describe "#words" do
    let(:dictionary) do
      Kotoshu::Dictionary::PlainText.new(
        "spec/fixtures/words.txt",
        language_code: "en-US"
      )
    end

    it "returns all words as strings" do
      words = dictionary.words

      expect(words).to be_an(Array)
      expect(words).to include("hello")
      expect(words).to include("world")
    end

    it "returns empty array for empty dictionary" do
      dict = Kotoshu::Dictionary::PlainText.new(
        "spec/fixtures/empty.txt",
        language_code: "en-US"
      )

      expect(dict.words).to eq([])
    end
  end

  describe "#size" do
    it "returns word count" do
      dictionary = Kotoshu::Dictionary::PlainText.new(
        "spec/fixtures/words.txt",
        language_code: "en-US"
      )

      # File has: hello, world, ruby, test, code, spelling, dictionary, kotoshu
      expect(dictionary.size).to eq(8)
    end
  end

  describe "#empty?" do
    it "returns false for non-empty dictionary" do
      dictionary = Kotoshu::Dictionary::PlainText.new(
        "spec/fixtures/words.txt",
        language_code: "en-US"
      )

      expect(dictionary.empty?).to be false
    end

    it "returns true for empty dictionary" do
      dictionary = Kotoshu::Dictionary::PlainText.new(
        "spec/fixtures/empty.txt",
        language_code: "en-US"
      )

      expect(dictionary.empty?).to be true
    end
  end
end
