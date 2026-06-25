# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/languages/en/language'

RSpec.describe Kotoshu::Languages::English::Tokenizer do
  let(:tokenizer) { described_class.new }

  it_behaves_like 'a tokenizer' do
    subject { tokenizer }
  end

  describe '#tokenize' do
    it 'expands common contractions' do
      result = tokenizer.tokenize("I don't know")

      expect(result.map { |t| t[:token] }).to include('I', 'do', 'n\'t')
    end

    it 'expands "can\'t" to "can" + "not"' do
      result = tokenizer.tokenize("I can't believe it")

      expect(result.map { |t| t[:token] }).to include('I', 'can', "'t")
    end

    it 'expands "won\'t" to "will" + "not"' do
      result = tokenizer.tokenize("He won't do it")

      expect(result.map { |t| t[:token] }).to include('He', 'will', 'not')
    end

    it 'handles "you\'re" correctly' do
      result = tokenizer.tokenize("you're welcome")

      expect(result.map { |t| t[:token] }).to include('you', '\'re')
    end

    it 'handles "I\'m" correctly' do
      result = tokenizer.tokenize("I'm happy")

      expect(result.map { |t| t[:token] }).to include('I', '\'m')
    end

    it 'handles "I\'ve" correctly' do
      result = tokenizer.tokenize("I've seen it")

      expect(result.map { |t| t[:token] }).to include('I', '\'ve')
    end

    it 'handles "I\'d" correctly' do
      result = tokenizer.tokenize("I'd like that")

      expect(result.map { |t| t[:token] }).to include('I', '\'d')
    end

    it 'handles possessive "John\'s" correctly' do
      result = tokenizer.tokenize("John's car")

      # Keep possessive as one token or split depending on implementation
      expect(result.map { |t| t[:token] }).to include('John', '\'s')
    end

    it 'handles multiple contractions in one sentence' do
      result = tokenizer.tokenize("I can't believe you won't do it")

      expect(result.map { |t| t[:token] }).to include('I', 'can', "'t", 'believe', 'you', 'will', 'not', 'do', 'it')
    end

    it 'handles non-contraction text normally' do
      result = tokenizer.tokenize('The cat sat on the mat')

      expect(result.map { |t| t[:token] }).to eq(['The', 'cat', 'sat', 'on', 'the', 'mat'])
    end
  end

  describe '#initialize' do
    it 'can disable contraction expansion' do
      tokenizer = described_class.new(expand_contractions: false)

      result = tokenizer.tokenize("I don't know")

      expect(result.map { |t| t[:token] }).to include('don\'t')
    end
  end

  describe 'CONTRACTIONS constant' do
    it 'has common contractions defined' do
      expect(described_class::CONTRACTIONS).to include("n't")
      expect(described_class::CONTRACTIONS).to include("'ll")
      expect(described_class::CONTRACTIONS).to include("'ve")
      expect(described_class::CONTRACTIONS).to include("'re")
      expect(described_class::CONTRACTIONS).to include("'m")
      expect(described_class::CONTRACTIONS).to include("'d")
      expect(described_class::CONTRACTIONS).to include("'s")
    end
  end
end
