# frozen_string_literal: true

require 'spec_helper'
require 'kotoshu/suggestions'
require 'json'
require 'time'
require 'tmpdir'

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

  describe 'network isolation (cache-only hot path)' do
    # Real recording subclass (no doubles): counts download attempts,
    # performs none. Any recorded attempt is a hot-path violation.
    recording_cache = Class.new(Kotoshu::Cache::FrequencyCache) do
      attr_reader :download_attempts

      def initialize(**kwargs)
        super
        @download_attempts = []
      end

      def download_resource(resource_id, _dest_path)
        @download_attempts << resource_id
        nil
      end
    end

    # Kelly-format frequency.json with a sentinel word that does NOT
    # exist in the bundled YAML fallback — so assertions can tell a
    # genuine cache read apart from a silent fallback.
    def seed_cache(cache, dir, cached_at:)
      frequency_json = File.join(dir, 'source-frequency.json')
      File.write(frequency_json, JSON.generate(
                                   tiers: {
                                     top_50: { words: ['zzkellyonly'] },
                                     top_200: { words: [] },
                                     top_1000: { words: [] }
                                   }
                                 ))
      result = cache.install_local('en', path: frequency_json)
      metadata = JSON.parse(File.read(result[:metadata_path]))
      metadata['cached_at'] = cached_at.utc.iso8601
      metadata['version'] = cached_at.utc.iso8601
      File.write(result[:metadata_path], JSON.generate(metadata))
    end

    it 'never attempts a download on a cold cache (falls back to YAML tiers)' do
      Dir.mktmpdir('kotoshu-freq-cold') do |dir|
        cache = recording_cache.new(cache_path: dir)
        provider = described_class.new(frequency_cache: cache)

        tiers = provider.tiers_for('en')

        expect(cache.download_attempts).to be_empty
        expect(tiers.keys).to contain_exactly(:top_50, :top_200, :top_1000)
      end
    end

    it 'never attempts a download when the cached data is TTL-expired' do
      Dir.mktmpdir('kotoshu-freq-expired') do |dir|
        cache = recording_cache.new(cache_path: dir)
        seed_cache(cache, dir, cached_at: Time.now - (8 * 86_400))
        provider = described_class.new(frequency_cache: cache)

        provider.tiers_for('en')

        expect(cache.download_attempts).to be_empty
      end
    end

    it 'reads fresh cached tiers (not the YAML fallback) without any download attempt' do
      Dir.mktmpdir('kotoshu-freq-fresh') do |dir|
        cache = recording_cache.new(cache_path: dir)
        seed_cache(cache, dir, cached_at: Time.now)
        provider = described_class.new(frequency_cache: cache)

        tiers = provider.tiers_for('en')

        expect(cache.download_attempts).to be_empty
        expect(tiers[:top_50]).to include('zzkellyonly')
      end
    end
  end
end
