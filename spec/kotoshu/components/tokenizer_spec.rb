# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/components/tokenizer'

RSpec.describe Kotoshu::Components::Tokenizer do
  # Abstract base class tests - don't use shared examples
  describe '#tokenize' do
    it 'raises NotImplementedError when called directly' do
      tokenizer = described_class.new

      expect { tokenizer.tokenize('test') }.to raise_error(NotImplementedError)
    end
  end

  describe '#tokenize_to_strings' do
    it 'raises NotImplementedError when called directly' do
      tokenizer = described_class.new

      expect { tokenizer.tokenize_to_strings('test') }.to raise_error(NotImplementedError)
    end
  end
end
