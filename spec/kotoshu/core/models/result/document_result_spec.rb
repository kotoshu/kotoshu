# frozen_string_literal: true

require "kotoshu"

# Direct spec for Models::Result::DocumentResult — the per-document
# check result that aggregates WordResult errors.
#
# DocumentResult is a lutaml-model Serializable that wraps a file path,
# word count, and an Array<WordResult> of errors. It is the result
# shape returned by Spellchecker#check_file and the higher-level
# Kotoshu.check_file facade.
RSpec.describe Kotoshu::Models::Result::DocumentResult do
  let(:word_result_class) { Kotoshu::Models::Result::WordResult }

  let(:errors) do
    [
      word_result_class.incorrect("hellp", suggestions: [Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1)]),
      word_result_class.incorrect("hellp", suggestions: [Kotoshu::Suggestions::Suggestion.new(word: "hello", distance: 1)]),
      word_result_class.incorrect("wrld", suggestions: [Kotoshu::Suggestions::Suggestion.new(word: "world", distance: 1)])
    ]
  end

  describe ".success" do
    it "builds a result with no errors" do
      result = described_class.success(file: "doc.txt", word_count: 100)
      expect(result).to be_success
      expect(result.errors).to be_empty
    end
  end

  describe ".failure" do
    it "builds a result with the given errors" do
      result = described_class.failure(file: "doc.txt", errors: errors, word_count: 100)
      expect(result).to be_failed
      expect(result.error_count).to eq(3)
    end
  end

  describe "#initialize" do
    it "accepts file, errors, word_count, and metadata" do
      result = described_class.new(file: "doc.txt", errors: errors, word_count: 50, metadata: { lang: "en" })
      expect(result.file).to eq("doc.txt")
      expect(result.word_count).to eq(50)
      expect(result.errors.size).to eq(3)
      expect(result.metadata[:lang]).to eq("en")
    end

    it "defaults sensibly" do
      result = described_class.new
      expect(result.file).to be_nil
      expect(result.word_count).to eq(0)
      expect(result.errors).to be_empty
      expect(result.metadata).to eq({})
    end
  end

  describe "#success? / #failed?" do
    it "is success when errors are empty" do
      expect(described_class.new).to be_success
      expect(described_class.new).not_to be_failed
    end

    it "is failed when errors are present" do
      expect(described_class.new(errors: errors)).to be_failed
      expect(described_class.new(errors: errors)).not_to be_success
    end
  end

  describe "#error_count / #unique_error_count" do
    it "counts total and unique errors" do
      result = described_class.new(errors: errors)
      expect(result.error_count).to eq(3)
      expect(result.unique_error_count).to eq(2)
    end
  end

  describe "#has_error_for? / #errors_for" do
    it "reports whether a word has any error entries" do
      result = described_class.new(errors: errors)
      expect(result.has_error_for?("hellp")).to be true
      expect(result.has_error_for?("zzz")).to be false
    end

    it "returns the matching WordResult entries" do
      result = described_class.new(errors: errors)
      matches = result.errors_for("hellp")
      expect(matches.size).to eq(2)
      expect(matches).to all(be_a(word_result_class))
    end
  end

  describe "#each_error" do
    it "yields each error" do
      result = described_class.new(errors: errors)
      yielded = []
      result.each_error { |e| yielded << e }
      expect(yielded.size).to eq(3)
    end

    it "returns an Enumerator when no block is given" do
      result = described_class.new(errors: errors)
      expect(result.each_error).to be_an(Enumerator)
    end
  end

  describe "#each_unique_error" do
    it "yields (word, [WordResult, ...]) pairs grouped by word" do
      result = described_class.new(errors: errors)
      pairs = []
      result.each_unique_error { |word, group| pairs << [word, group] }
      by_word = pairs.to_h
      expect(by_word["hellp"].size).to eq(2)
      expect(by_word["wrld"].size).to eq(1)
    end

    it "returns an Enumerator when no block is given" do
      result = described_class.new(errors: errors)
      expect(result.each_unique_error).to be_an(Enumerator)
    end
  end

  describe "#first_errors" do
    it "returns the first n errors" do
      result = described_class.new(errors: errors)
      expect(result.first_errors(2).size).to eq(2)
    end

    it "defaults to 10" do
      result = described_class.new(errors: errors)
      expect(result.first_errors.size).to eq(3)
    end
  end

  describe "#error_summary" do
    it "builds a Hash of word => occurrence count" do
      result = described_class.new(errors: errors)
      summary = result.error_summary
      expect(summary["hellp"]).to eq(2)
      expect(summary["wrld"]).to eq(1)
    end

    it "is empty for a successful result" do
      expect(described_class.new.error_summary).to eq({})
    end
  end

  describe "#== / #eql? / #hash" do
    it "equals another DocumentResult with same file and errors" do
      a = described_class.new(file: "x", errors: errors)
      b = described_class.new(file: "x", errors: errors)
      expect(a).to eq(b)
      expect(a.hash).to eq(b.hash)
    end

    it "differs when the file differs" do
      a = described_class.new(file: "x")
      b = described_class.new(file: "y")
      expect(a).not_to eq(b)
    end

    it "returns false when compared to a non-DocumentResult" do
      expect(described_class.new).not_to eq("not a result")
    end
  end

  describe "#to_s / #inspect" do
    it "reports 'no errors' for a successful result with a file" do
      result = described_class.success(file: "doc.txt", word_count: 100)
      expect(result.to_s).to include("doc.txt")
      expect(result.to_s).to include("No spelling errors")
      expect(result.to_s).to include("100 words")
    end

    it "reports 'no errors' for a successful result without a file" do
      result = described_class.success(word_count: 50)
      expect(result.to_s).to include("No spelling errors")
      expect(result.to_s).to include("50 words")
    end

    it "reports counts for a failed result" do
      result = described_class.new(file: "doc.txt", errors: errors, word_count: 200)
      expect(result.to_s).to include("3 spelling error")
      expect(result.to_s).to include("2 unique")
      expect(result.to_s).to include("200 words")
    end

    it "aliases inspect to to_s" do
      result = described_class.new
      expect(result.inspect).to eq(result.to_s)
    end
  end

  describe ".merge" do
    it "combines multiple DocumentResults into one" do
      a = described_class.new(errors: errors, word_count: 100)
      b = described_class.success(word_count: 50)
      merged = described_class.merge([a, b])
      expect(merged.error_count).to eq(3)
      expect(merged.word_count).to eq(150)
      expect(merged.file).to be_nil
    end

    it "returns an empty result when the array is empty" do
      expect(described_class.merge([])).to be_success
    end
  end
end
