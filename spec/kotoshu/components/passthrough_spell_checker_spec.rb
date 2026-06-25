# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/components/passthrough_spell_checker'

RSpec.describe Kotoshu::Components::PassthroughSpellChecker do
  it_behaves_like 'a spell checker' do
    subject { described_class.new }
  end

  describe '#check' do
    it 'always returns found: true' do
      checker = described_class.new

      result = checker.check('any text')
      expect(result).to eq(found: true, stem: nil, flags: [])
    end

    it 'handles empty string' do
      checker = described_class.new

      result = checker.check('')
      expect(result).to eq(found: true, stem: nil, flags: [])
    end

    it 'handles nil' do
      checker = described_class.new

      result = checker.check(nil)
      expect(result).to eq(found: true, stem: nil, flags: [])
    end
  end

  describe '#suggest' do
    it 'always returns empty array' do
      checker = described_class.new

      result = checker.suggest('test')
      expect(result).to eq([])
    end
  end

  describe '#correct?' do
    it 'always returns true' do
      checker = described_class.new

      expect(checker.correct?('anything')).to be true
    end
  end

  describe '#reason' do
    it 'returns the reason' do
      reason = 'Language does not use spell checking'
      checker = described_class.new(reason: reason)

      expect(checker.reason).to eq(reason)
    end

    it 'has a default reason' do
      checker = described_class.new

      expect(checker.reason).to eq('Language does not use spell checking')
    end
  end

  describe '#passthrough?' do
    it 'returns true' do
      checker = described_class.new

      expect(checker.passthrough?).to be true
    end
  end
end
