# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/components/pos_tagger'

RSpec.describe Kotoshu::Components::PosTagger do
  # Abstract base class tests - don't use shared examples
  describe '#tag' do
    it 'raises NotImplementedError when called directly' do
      tagger = described_class.new

      expect { tagger.tag([]) }.to raise_error(NotImplementedError)
    end
  end

  describe '#tag_word' do
    it 'raises NotImplementedError when called directly' do
      tagger = described_class.new

      expect { tagger.tag_word('test') }.to raise_error(NotImplementedError)
    end
  end
end
