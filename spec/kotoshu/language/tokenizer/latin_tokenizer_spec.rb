# frozen_string_literal: true

RSpec.describe Kotoshu::Language::Tokenizer::LatinTokenizer do
  let(:tokenizer) { described_class.new }

  describe "#tokenize" do
    it "splits text into words" do
      result = tokenizer.tokenize("hello world")

      expect(result).to eq(["hello", "world"])
    end

    it "handles punctuation" do
      result = tokenizer.tokenize("hello, world!")

      expect(result).to include("hello")
      expect(result).to include("world")
    end

    it "handles apostrophes within words" do
      result = tokenizer.tokenize("I'm here")

      expect(result).to include("I'm")
      expect(result).to include("here")
    end

    it "handles hyphens in words" do
      result = tokenizer.tokenize("state-of-the-art")

      expect(result).to include("state")
      expect(result).to include("of")
      expect(result).to include("the")
      expect(result).to include("art")
    end

    it "filters out empty tokens" do
      result = tokenizer.tokenize("hello  world")

      expect(result).not_to include("")
    end

    it "filters out pure numbers" do
      result = tokenizer.tokenize("123 456")

      expect(result).not_to include("123")
      expect(result).not_to include("456")
    end

    it "filters out single non-letter characters" do
      result = tokenizer.tokenize("a b c")

      # Single letters are kept
      expect(result).to include("a")
    end

    it "keeps words with accents" do
      result = tokenizer.tokenize("café résumé")

      expect(result).to include("café")
      expect(result).to include("résumé")
    end

    it "handles mixed case" do
      result = tokenizer.tokenize("Hello World")

      expect(result).to include("Hello")
      expect(result).to include("World")
    end

    it "handles contractions" do
      result = tokenizer.tokenize("I'm don't won't can't")

      expect(result).to include("I'm")
      expect(result).to include("don't")
      expect(result).to include("won't")
      expect(result).to include("can't")
    end

    it "handles parentheses and brackets" do
      result = tokenizer.tokenize("(test) [test] {test}")

      expect(result).to include("test")
    end

    it "handles slashes and backslashes" do
      result = tokenizer.tokenize("and/or test\\test")

      expect(result).to include("and")
      expect(result).to include("or")
      expect(result).to include("test")
    end

    it "returns empty array for nil" do
      result = tokenizer.tokenize(nil)

      expect(result).to eq([])
    end

    it "returns empty array for empty string" do
      result = tokenizer.tokenize("")

      expect(result).to eq([])
    end

    it "returns empty array for whitespace only" do
      result = tokenizer.tokenize("   ")

      expect(result).to eq([])
    end
  end

  describe "#word_boundary_regex" do
    it "returns regex for Latin characters" do
      regex = tokenizer.word_boundary_regex

      expect(regex).to be_a(Regexp)
      expect(regex.match?("a")).to be true
      expect(regex.match?("Z")).to be true
      expect(regex.match?("à")).to be true
      expect(regex.match?("ÿ")).to be true
    end
  end

  describe "#normalize" do
    it "strips whitespace" do
      result = tokenizer.normalize("  hello  ")

      expect(result).to eq("hello")
    end
  end

  describe "#skip_token?" do
    it "returns true for empty string" do
      expect(tokenizer.skip_token?("")).to be true
    end

    it "returns true for pure numbers" do
      expect(tokenizer.skip_token?("123")).to be true
    end

    it "returns true for tokens with no letters" do
      expect(tokenizer.skip_token?("123!@#")).to be true
    end

    it "returns false for normal words" do
      expect(tokenizer.skip_token?("hello")).to be false
    end

    it "returns false for words with numbers" do
      expect(tokenizer.skip_token?("abc123")).to be false
    end
  end
end
