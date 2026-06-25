# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/components/synthesizer'

RSpec.describe Kotoshu::Components::Synthesizer do
  describe '#synthesize' do
    it 'raises NotImplementedError when called directly' do
      synthesizer = described_class.new

      expect { synthesizer.synthesize('run', 'VERB') }.to raise_error(NotImplementedError)
    end
  end

  describe '#synthesize_all' do
    it 'calls synthesize for each POS type' do
      synthesizer = described_class.new

      # Each call should raise NotImplementedError
      expect { synthesizer.synthesize_all('run') }.to raise_error(NotImplementedError)
    end
  end
end
