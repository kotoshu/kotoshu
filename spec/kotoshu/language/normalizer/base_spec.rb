# frozen_string_literal: true

RSpec.describe Kotoshu::Language::Normalizer::Base do
  let(:normalizer) { described_class.new }

  describe "#normalize" do
    it "strips leading and trailing whitespace" do
      result = normalizer.normalize("  hello  ")

      expect(result).to eq("hello")
    end

    it "collapses multiple whitespace" do
      result = normalizer.normalize("hello    world")

      expect(result).to eq("hello world")
    end

    it "downcases by default" do
      result = normalizer.normalize("HELLO WORLD")

      expect(result).to eq("hello world")
    end

    it "handles nil" do
      result = normalizer.normalize(nil)

      expect(result).to eq("")
    end

    it "handles empty string" do
      result = normalizer.normalize("")

      expect(result).to eq("")
    end

    context "with downcase: false" do
      it "preserves case" do
        result = normalizer.normalize("HELLO", downcase: false)

        expect(result).to eq("HELLO")
      end
    end

    context "with strip_punct: true" do
      it "removes punctuation" do
        result = normalizer.normalize("Hello, world!", strip_punct: true)

        expect(result).to eq("hello world")
      end
    end

    context "with collapse_ws: false" do
      it "preserves multiple spaces" do
        result = normalizer.normalize("hello   world", collapse_ws: false)

        expect(result).to eq("hello   world")
      end
    end

    it "combines options" do
      result = normalizer.normalize("  HELLO,   WORLD!  ", downcase: false, strip_punct: true)

      expect(result).to eq("HELLO WORLD")
    end
  end

  describe "#normalize_word" do
    it "normalizes single word" do
      result = normalizer.normalize_word("  HELLO  ")

      expect(result).to eq("hello")
    end
  end

  describe "#normalized_eql?" do
    it "returns true for equal strings" do
      result = normalizer.normalized_eql?("HELLO", "hello")

      expect(result).to be true
    end

    it "returns true for strings with different whitespace" do
      result = normalizer.normalized_eql?("hello  world", "hello world")

      expect(result).to be true
    end

    it "returns false for different words" do
      result = normalizer.normalized_eql?("hello", "world")

      expect(result).to be false
    end
  end

  describe "#strip_punctuation" do
    it "removes punctuation" do
      result = normalizer.strip_punctuation("Hello, world!")

      expect(result).to eq("Hello world")
    end

    it "preserves letters and numbers" do
      result = normalizer.strip_punctuation("abc123")

      expect(result).to eq("abc123")
    end

    it "preserves whitespace" do
      result = normalizer.strip_punctuation("hello,  world!")

      expect(result).to eq("hello  world")
    end
  end

  describe "#remove_accents" do
    it "removes accents from characters" do
      result = normalizer.remove_accents("café résumé")

      expect(result).to eq("cafe resume")
    end

    it "handles German umlauts" do
      result = normalizer.remove_accents("äöüß")

      expect(result).to include("a")
      expect(result).to include("o")
      expect(result).to include("u")
    end

    it "preserves non-accented characters" do
      result = normalizer.remove_accents("hello")

      expect(result).to eq("hello")
    end
  end

  describe "#normalize_quotes" do
    it "converts curly quotes to straight" do
      # Using escape sequences for curly quotes
      text = "\u201Chello\u201D \u2018world\u2019"
      result = normalizer.normalize_quotes(text)

      expect(result).to eq('"hello" \'world\'')
    end

    it "converts backticks" do
      result = normalizer.normalize_quotes("`hello`")

      expect(result).to eq("'hello'")
    end
  end

  describe "#normalize_whitespace" do
    it "collapses multiple spaces" do
      result = normalizer.normalize_whitespace("hello    world")

      expect(result).to eq("hello world")
    end

    it "converts various space characters" do
      result = normalizer.normalize_whitespace("hello\u00A0world")

      expect(result).to eq("hello world")
    end

    it "strips leading and trailing" do
      result = normalizer.normalize_whitespace("  hello world  ")

      expect(result).to eq("hello world")
    end
  end
end
