# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/suggestions'

# Direct spec for FrequencyProvider — extracted from
# EditDistanceStrategy in TODO 56 T5.1 step 3 Phase A so the
# strategy constructor stops performing disk IO and network
# access on every instantiation.
RSpec.describe Kotoshu::Suggestions::FrequencyProvider do
  let(:provider) { described_class.new }

  describe '#tiers_for' do
    it 'returns a hash with :top_50, :top_200, :top_1000 keys' do
      tiers = provider.tiers_for('en')
      expect(tiers).to be_a(Hash)
      expect(tiers.keys).to contain_exactly(:top_50, :top_200, :top_1000)
    end

    it 'returns Set instances for each tier' do
      tiers = provider.tiers_for('en')
      expect(tiers[:top_50]).to be_a(Set)
      expect(tiers[:top_200]).to be_a(Set)
      expect(tiers[:top_1000]).to be_a(Set)
    end

    it 'memoizes per-language — second call returns the same object' do
      first = provider.tiers_for('en')
      second = provider.tiers_for('en')
      expect(second).to be(first)
    end

    it 'returns EMPTY_TIERS for an unknown language' do
      tiers = provider.tiers_for('xx')
      expect(tiers[:top_50]).to be_empty
      expect(tiers[:top_200]).to be_empty
      expect(tiers[:top_1000]).to be_empty
    end

    it 'caches per-language independently (different languages → different tiers)' do
      en = provider.tiers_for('en')
      xx = provider.tiers_for('xx')
      expect(en).not_to be(xx)
    end
  end

  describe 'EMPTY_TIERS' do
    it 'is frozen' do
      expect(described_class::EMPTY_TIERS).to be_frozen
    end

    it 'has empty sets for all three tiers' do
      expect(described_class::EMPTY_TIERS[:top_50]).to be_empty
      expect(described_class::EMPTY_TIERS[:top_200]).to be_empty
      expect(described_class::EMPTY_TIERS[:top_1000]).to be_empty
    end
  end
end
