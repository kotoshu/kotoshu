# frozen_string_literal: true

RSpec.describe Kotoshu::Language::Tokenizer::Base do
  let(:test_tokenizer) do
    Class.new(described_class) do
      def word_boundary_regex
        /[a-zA-Z]/
      end

      def word_chars
        "a-zA-Z"
      end
    end.new
  end

  describe "#tokenize" do
    it "raises NotImplementedError" do
      expect do
        test_tokenizer.tokenize("test")
      end.to raise_error(NotImplementedError)
    end
  end

  describe "#word_char?" do
    it "returns true for word characters" do
      expect(test_tokenizer.word_char?("a")).to be true
      expect(test_tokenizer.word_char?("Z")).to be true
    end

    it "returns false for non-word characters" do
      expect(test_tokenizer.word_char?("1")).to be false
      expect(test_tokenizer.word_char?(" ")).to be false
      expect(test_tokenizer.word_char?(".")).to be false
    end
  end

  describe "#skip_token?" do
    it "returns true for empty string" do
      expect(test_tokenizer.send(:skip_token?, "")).to be true
    end

    it "returns true for pure numbers" do
      expect(test_tokenizer.send(:skip_token?, "123")).to be true
    end

    it "returns false for normal words" do
      expect(test_tokenizer.send(:skip_token?, "hello")).to be false
    end
  end

  describe "#normalize" do
    it "returns input unchanged by default" do
      expect(test_tokenizer.normalize("Hello")).to eq("Hello")
    end
  end

  describe "#tokenize_with_positions" do
    it "returns empty array for nil" do
      expect(test_tokenizer.tokenize_with_positions(nil)).to eq([])
    end

    it "returns empty array for empty string" do
      expect(test_tokenizer.tokenize_with_positions("")).to eq([])
    end

    it "handles text with only whitespace" do
      result = test_tokenizer.tokenize_with_positions("   \n\n  ")

      expect(result).to eq([])
    end
  end
end
