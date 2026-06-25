# frozen_string_literal: true

require "tempfile"
require_relative "../../../lib/kotoshu/embeddings/vocabulary"

RSpec.describe Vocabulary do
  let(:word_to_index) do
    {
      "hello" => 0,
      "world" => 1,
      "test" => 2,
      "example" => 3,
      "kotoshu" => 4
    }
  end

  let(:language_code) { "en" }

  describe "#initialize" do
    it "creates vocabulary from word_to_index hash" do
      vocab = described_class.new(
        language_code: language_code,
        word_to_index: word_to_index
      )
      expect(vocab.language_code).to eq(language_code)
      expect(vocab.size).to eq(5)
    end

    it "builds reverse mapping automatically" do
      vocab = described_class.new(
        language_code: language_code,
        word_to_index: word_to_index
      )
      expect(vocab.get_word(0)).to eq("hello")
      expect(vocab.get_word(1)).to eq("world")
    end

    it "raises error for empty word_to_index" do
      expect {
        described_class.new(language_code: language_code, word_to_index: {})
      }.to raise_error(ArgumentError, /cannot be empty/)
    end
  end

  describe ".from_file" do
    let(:vocab_file) do
      Tempfile.new(["vocab", ".json"])
    end

    after do
      vocab_file.close
      vocab_file.unlink
    end

    it "loads vocabulary from JSON file (array format)" do
      data = ["hello", "world", "test", "example"]
      File.write(vocab_file.path, JSON.generate(data))

      vocab = described_class.from_file(vocab_file.path, language_code: "en")
      expect(vocab.size).to eq(4)
      expect(vocab.lookup("hello")).to eq(0)
      expect(vocab.lookup("world")).to eq(1)
    end

    it "loads vocabulary from JSON file (hash format)" do
      data = { "hello" => 0, "world" => 1, "test" => 2 }
      File.write(vocab_file.path, JSON.generate(data))

      vocab = described_class.from_file(vocab_file.path, language_code: "en")
      expect(vocab.size).to eq(3)
      expect(vocab.lookup("hello")).to eq(0)
    end

    it "auto-detects language from filename" do
      data = ["hello", "world"]
      File.write(vocab_file.path, JSON.generate(data))

      # Rename to include language code
      new_path = vocab_file.path.sub(/\.json$/, ".en.vocab.json")
      File.rename(vocab_file.path, new_path)

      vocab = described_class.from_file(new_path)
      expect(vocab.language_code).to eq("en")
    end

    it "raises ArgumentError for non-existent file" do
      expect {
        described_class.from_file("/nonexistent/file.json")
      }.to raise_error(ArgumentError, /File not found/)
    end
  end

  describe ".from_words" do
    it "creates vocabulary from array of words" do
      words = ["hello", "world", "test"]
      vocab = described_class.from_words(words, language_code: "en")

      expect(vocab.size).to eq(3)
      expect(vocab.lookup("hello")).to eq(0)
      expect(vocab.lookup("world")).to eq(1)
      expect(vocab.lookup("test")).to eq(2)
    end
  end

  describe "#lookup" do
    let(:vocab) do
      described_class.new(language_code: language_code, word_to_index: word_to_index)
    end

    it "returns index for existing word" do
      expect(vocab.lookup("hello")).to eq(0)
      expect(vocab.lookup("world")).to eq(1)
    end

    it "returns nil for non-existent word" do
      expect(vocab.lookup("nonexistent")).to be_nil
    end
  end

  describe "#get_word" do
    let(:vocab) do
      described_class.new(language_code: language_code, word_to_index: word_to_index)
    end

    it "returns word for valid index" do
      expect(vocab.get_word(0)).to eq("hello")
      expect(vocab.get_word(1)).to eq("world")
    end

    it "returns nil for invalid index" do
      expect(vocab.get_word(999)).to be_nil
    end
  end

  describe "#include?" do
    let(:vocab) do
      described_class.new(language_code: language_code, word_to_index: word_to_index)
    end

    it "returns true for existing word" do
      expect(vocab.include?("hello")).to be true
    end

    it "returns false for non-existent word" do
      expect(vocab.include?("nonexistent")).to be false
    end
  end

  describe "#size" do
    it "returns vocabulary size" do
      vocab = described_class.new(language_code: language_code, word_to_index: word_to_index)
      expect(vocab.size).to eq(5)
    end
  end

  describe "#valid_index?" do
    let(:vocab) do
      described_class.new(language_code: language_code, word_to_index: word_to_index)
    end

    it "returns true for valid indices" do
      expect(vocab.valid_index?(0)).to be true
      expect(vocab.valid_index?(4)).to be true
    end

    it "returns false for invalid indices" do
      expect(vocab.valid_index?(-1)).to be false
      expect(vocab.valid_index?(999)).to be false
      expect(vocab.valid_index?("0")).to be false
    end
  end

  describe "#common_words" do
    let(:vocab) do
      described_class.new(language_code: language_code, word_to_index: word_to_index)
    end

    it "returns first N words" do
      words = vocab.common_words(n: 3)
      expect(words.length).to eq(3)
      expect(words).to eq(["hello", "world", "test"])
    end
  end

  describe "#to_h" do
    let(:vocab) do
      described_class.new(language_code: language_code, word_to_index: word_to_index)
    end

    it "returns word_to_index mapping" do
      hash = vocab.to_h
      expect(hash).to eq(word_to_index)
    end

    it "returns a copy (not the original)" do
      hash = vocab.to_h
      hash["new_word"] = 100
      expect(vocab.include?("new_word")).to be false
    end
  end

  describe "#words" do
    let(:vocab) do
      described_class.new(language_code: language_code, word_to_index: word_to_index)
    end

    it "returns enumerator of all words" do
      words = vocab.words.to_a
      expect(words.length).to eq(5)
      expect(words).to contain_exactly("hello", "world", "test", "example", "kotoshu")
    end
  end

  describe "#empty?" do
    it "returns false for non-empty vocabulary" do
      vocab = described_class.new(language_code: language_code, word_to_index: word_to_index)
      expect(vocab.empty?).to be false
    end
  end

  describe "#sample" do
    let(:vocab) do
      described_class.new(language_code: language_code, word_to_index: word_to_index)
    end

    it "returns sample of words" do
      sample = vocab.sample(n: 3)
      expect(sample.length).to eq(3)
      sample.each do |word|
        expect(vocab.include?(word)).to be true
      end
    end
  end

  describe "#sub_vocabulary" do
    let(:vocab) do
      described_class.new(language_code: language_code, word_to_index: word_to_index)
    end

    it "creates sub-vocabulary with subset of words" do
      sub_vocab = vocab.sub_vocabulary(["hello", "world"])
      expect(sub_vocab.size).to eq(2)
      expect(sub_vocab.include?("hello")).to be true
      expect(sub_vocab.include?("world")).to be true
      expect(sub_vocab.include?("test")).to be false
    end
  end

  describe "#words_starting_with" do
    let(:vocab) do
      described_class.new(language_code: language_code, word_to_index: word_to_index)
    end

    it "finds words starting with prefix" do
      words = vocab.words_starting_with("hel")
      expect(words).to eq(["hello"])
    end

    it "returns empty array if no matches" do
      words = vocab.words_starting_with("xyz")
      expect(words).to eq([])
    end
  end

  describe "#save_to_file" do
    let(:vocab) do
      described_class.new(language_code: language_code, word_to_index: word_to_index)
    end

    let(:temp_file) { Tempfile.new(["vocab", ".json"]) }

    after do
      temp_file.close
      temp_file.unlink
    end

    it "saves vocabulary to file" do
      vocab.save_to_file(temp_file.path)

      loaded = described_class.from_file(temp_file.path, language_code: language_code)
      expect(loaded.size).to eq(vocab.size)
      expect(loaded.lookup("hello")).to eq(0)
    end
  end

  describe "#to_s" do
    let(:vocab) do
      described_class.new(language_code: language_code, word_to_index: word_to_index)
    end

    it "returns informative string representation" do
      str = vocab.to_s
      expect(str).to include("Vocabulary")
      expect(str).to include("en")
      expect(str).to include("5")
    end
  end
end
