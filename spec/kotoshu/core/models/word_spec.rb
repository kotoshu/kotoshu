# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Models::Word, "# Walking Skeleton - Word VALUE Object" do
  describe "creation" do
    it "creates word with text" do
      word = Kotoshu::Models::Word.new("hello")

      expect(word.text).to eq("hello")
    end

    it "raises error when text is nil" do
      expect {
        Kotoshu::Models::Word.new(nil)
      }.to raise_error(ArgumentError, "Text cannot be empty")
    end

    it "raises error when text is empty" do
      expect {
        Kotoshu::Models::Word.new("")
      }.to raise_error(ArgumentError, "Text cannot be empty")
    end

    it "creates word with flags" do
      word = Kotoshu::Models::Word.new("hello", flags: ["noun", "verb"])

      expect(word.flags).to eq(["noun", "verb"])
    end

    it "creates word with morphological data" do
      word = Kotoshu::Models::Word.new("hello", morphological_data: { root: "hell" })

      expect(word.morphological_data).to eq({ root: "hell" })
    end
  end

  describe "value equality" do
    it "two words with same text are equal" do
      word1 = Kotoshu::Models::Word.new("hello")
      word2 = Kotoshu::Models::Word.new("hello")

      expect(word1).to eq(word2)
      expect(word1.eql?(word2)).to be true
    end

    it "two words with same text but different flags are equal" do
      word1 = Kotoshu::Models::Word.new("hello", flags: ["noun"])
      word2 = Kotoshu::Models::Word.new("hello", flags: ["verb"])

      expect(word1).to eq(word2)
    end

    it "words with different text are not equal" do
      word1 = Kotoshu::Models::Word.new("hello")
      word2 = Kotoshu::Models::Word.new("world")

      expect(word1).not_to eq(word2)
    end

    it "words are not equal to non-words" do
      word = Kotoshu::Models::Word.new("hello")

      expect(word).not_to eq("hello")
      expect(word).not_to eq(nil)
    end
  end

  describe "hashing" do
    it "can be used as hash key" do
      word1 = Kotoshu::Models::Word.new("hello")
      word2 = Kotoshu::Models::Word.new("hello")

      hash = { word1 => "value1" }

      expect(hash[word2]).to eq("value1")
    end

    it "different words have different hash codes" do
      word1 = Kotoshu::Models::Word.new("hello")
      word2 = Kotoshu::Models::Word.new("world")

      expect(word1.hash).not_to eq(word2.hash)
    end
  end

  describe "immutability" do
    it "freezes the word on creation" do
      word = Kotoshu::Models::Word.new("hello")

      expect(word).to be_frozen
    end

    it "freezes flags array" do
      word = Kotoshu::Models::Word.new("hello", flags: ["noun"])

      expect(word.flags).to be_frozen
    end

    it "freezes morphological data hash" do
      word = Kotoshu::Models::Word.new("hello", morphological_data: { root: "hell" })

      expect(word.morphological_data).to be_frozen
    end

    it "cannot modify text after creation (frozen object)" do
      word = Kotoshu::Models::Word.new("hello")

      # Word is frozen, cannot modify
      # Since we use attr_reader, there's no setter method
      # The object itself is frozen which prevents any modification
      expect(word).to be_frozen

      # Creating a new word is the only way
      new_word = Kotoshu::Models::Word.new("world")
      expect(new_word.text).to eq("world")
    end
  end

  describe "query methods" do
    describe "#valid?" do
      it "returns true for valid word" do
        word = Kotoshu::Models::Word.new("hello")

        expect(word.valid?).to be true
      end
    end

    describe "#has_flag?" do
      it "returns true when word has the flag" do
        word = Kotoshu::Models::Word.new("hello", flags: ["noun", "verb"])

        expect(word.has_flag?("noun")).to be true
        expect(word.has_flag?("verb")).to be true
      end

      it "returns false when word does not have the flag" do
        word = Kotoshu::Models::Word.new("hello", flags: ["noun"])

        expect(word.has_flag?("verb")).to be false
      end

      it "returns false when word has no flags" do
        word = Kotoshu::Models::Word.new("hello")

        expect(word.has_flag?("noun")).to be false
      end
    end

    describe "#has_flags?" do
      it "returns true when word has flags" do
        word = Kotoshu::Models::Word.new("hello", flags: ["noun"])

        expect(word.has_flags?).to be true
      end

      it "returns false when word has no flags" do
        word = Kotoshu::Models::Word.new("hello")

        expect(word.has_flags?).to be false
      end
    end

    describe "#length" do
      it "returns word length" do
        word = Kotoshu::Models::Word.new("hello")

        expect(word.length).to eq(5)
      end
    end

    describe "#empty?" do
      it "returns false for non-empty word" do
        word = Kotoshu::Models::Word.new("hello")

        expect(word.empty?).to be false
      end
    end
  end

  describe "#to_s" do
    it "returns word text" do
      word = Kotoshu::Models::Word.new("hello")

      expect(word.to_s).to eq("hello")
    end
  end

  describe "#to_h" do
    it "returns hash representation" do
      word = Kotoshu::Models::Word.new("hello", flags: ["noun"], morphological_data: { root: "hell" })

      hash = word.to_h

      expect(hash).to eq({
        text: "hello",
        flags: ["noun"],
        morphological_data: { root: "hell" }
      })
    end
  end

  describe "#<=>" do
    it "compares words alphabetically" do
      word1 = Kotoshu::Models::Word.new("apple")
      word2 = Kotoshu::Models::Word.new("hello")

      expect(word1 <=> word2).to eq(-1)
      expect(word2 <=> word1).to eq(1)
    end

    it "returns 0 for equal words" do
      word1 = Kotoshu::Models::Word.new("hello")
      word2 = Kotoshu::Models::Word.new("hello")

      expect(word1 <=> word2).to eq(0)
    end
  end

  describe ".from_dic_line" do
    it "parses word without flags" do
      word = Kotoshu::Models::Word.from_dic_line("hello")

      expect(word.text).to eq("hello")
      expect(word.flags).to eq([])
    end

    it "parses word with flags" do
      word = Kotoshu::Models::Word.from_dic_line("hello/NV")

      expect(word.text).to eq("hello")
      expect(word.flags).to eq(["N", "V"])
    end

    it "parses word with single flag" do
      word = Kotoshu::Models::Word.from_dic_line("hello/N")

      expect(word.text).to eq("hello")
      expect(word.flags).to eq(["N"])
    end

    it "returns nil for empty line" do
      word = Kotoshu::Models::Word.from_dic_line("")

      expect(word).to be_nil
    end

    it "returns nil for nil input" do
      word = Kotoshu::Models::Word.from_dic_line(nil)

      expect(word).to be_nil
    end
  end
end
