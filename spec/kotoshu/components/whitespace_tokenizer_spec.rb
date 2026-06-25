# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/components/whitespace_tokenizer'

RSpec.describe Kotoshu::Components::WhitespaceTokenizer do
  let(:tokenizer) { described_class.new }

  it_behaves_like 'a tokenizer' do
    subject { tokenizer }
  end

  describe '#tokenize' do
    it 'splits on whitespace and separates punctuation' do
      result = tokenizer.tokenize("Hello, world!")

      expect(result.map { |t| t[:token] }).to eq(['Hello', ',', 'world', '!'])
    end

    it 'includes position information' do
      result = tokenizer.tokenize("Hello world")

      expect(result[0][:position]).to eq(0)
      expect(result[0][:length]).to eq(5)
    end

    it 'handles multiple spaces' do
      result = tokenizer.tokenize("hello   world")

      expect(result.map { |t| t[:token] }).to eq(['hello', 'world'])
    end

    it 'handles tabs' do
      result = tokenizer.tokenize("hello\tworld")

      expect(result.map { |t| t[:token] }).to eq(['hello', 'world'])
    end

    it 'handles newlines' do
      result = tokenizer.tokenize("hello\nworld")

      expect(result.map { |t| t[:token] }).to eq(['hello', 'world'])
    end

    it 'preserves contractions' do
      result = tokenizer.tokenize("don't stop")

      expect(result.map { |t| t[:token] }).to include("don't")
    end

    it 'handles numbers' do
      result = tokenizer.tokenize("123 test")

      expect(result.map { |t| t[:token] }).to eq(['123', 'test'])
    end

    it 'handles special characters' do
      result = tokenizer.tokenize("test@example.com")

      expect(result.map { |t| t[:token] }).to eq(['test', '@', 'example', '.', 'com'])
    end
  end

  describe '#tokenize_to_strings' do
    it 'returns just the token strings' do
      result = tokenizer.tokenize_to_strings("Hello, world!")

      expect(result).to eq(['Hello', ',', 'world', '!'])
    end
  end

  describe '#word_char?' do
    it 'returns true for letters' do
      expect(tokenizer.word_char?('a')).to be true
      expect(tokenizer.word_char?('Z')).to be true
    end

    it 'returns true for numbers' do
      expect(tokenizer.word_char?('5')).to be true
    end

    it 'returns true for underscore' do
      expect(tokenizer.word_char?('_')).to be true
    end

    it 'returns false for punctuation' do
      expect(tokenizer.word_char?('.')).to be false
      expect(tokenizer.word_char?(',')).to be false
    end

    it 'returns false for spaces' do
      expect(tokenizer.word_char?(' ')).to be false
    end
  end

  describe '#punctuation?' do
    it 'returns true for punctuation' do
      expect(tokenizer.punctuation?('.')).to be true
      expect(tokenizer.punctuation?(',')).to be true
      expect(tokenizer.punctuation?('!')).to be true
    end

    it 'returns false for word characters' do
      expect(tokenizer.punctuation?('a')).to be false
      expect(tokenizer.punctuation?('5')).to be false
    end
  end

  describe '#pattern' do
    it 'returns the token pattern' do
      expect(tokenizer.pattern).to be_a(Regexp)
    end

    it 'can use a custom pattern' do
      custom_pattern = /[A-Z]+|[a-z]+/
      custom_tokenizer = described_class.new(pattern: custom_pattern)

      expect(custom_tokenizer.pattern).to eq(custom_pattern)
    end
  end
end
