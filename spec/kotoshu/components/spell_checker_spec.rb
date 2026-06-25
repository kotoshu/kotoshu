# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/components/spell_checker'

RSpec.describe Kotoshu::Components::SpellChecker do
  # Abstract base class tests - don't use shared examples
  describe '#check' do
    it 'raises NotImplementedError when called directly' do
      checker = described_class.new

      expect { checker.check('test') }.to raise_error(NotImplementedError)
    end
  end

  describe '#suggest' do
    it 'raises NotImplementedError when called directly' do
      checker = described_class.new

      expect { checker.suggest('test') }.to raise_error(NotImplementedError)
    end
  end

  describe '#correct?' do
    it 'raises NotImplementedError when called directly' do
      checker = described_class.new

      expect { checker.correct?('test') }.to raise_error(NotImplementedError)
    end
  end
end
