# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# Offline mode (config.offline / KOTOSHU_OFFLINE=1) must forbid every
# download path. Downloads only happen through explicit actions
# (Kotoshu.setup, kotoshu cache download), so those paths fail loudly
# with ResourceNotCachedError instead of silently skipping.
RSpec.describe "offline mode enforcement" do
  # Real recording subclass (no doubles): counts download attempts,
  # performs none.
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

  around do |example|
    original = Kotoshu.configuration.offline
    example.run
  ensure
    Kotoshu.configuration.offline = original
  end

  describe "Cache::BaseCache#download" do
    it "raises ResourceNotCachedError before reaching download_resource when offline" do
      Dir.mktmpdir("kotoshu-offline") do |dir|
        cache = recording_cache.new(cache_path: dir)
        Kotoshu.configuration.offline = true

        expect { cache.download("en") }
          .to raise_error(Kotoshu::ResourceNotCachedError, /KOTOSHU_OFFLINE/)
        expect(cache.download_attempts).to be_empty
      end
    end

    it "propagates the offline error through get on a cache miss" do
      Dir.mktmpdir("kotoshu-offline") do |dir|
        cache = recording_cache.new(cache_path: dir)
        Kotoshu.configuration.offline = true

        expect { cache.get("en") }
          .to raise_error(Kotoshu::ResourceNotCachedError)
        expect(cache.download_attempts).to be_empty
      end
    end

    it "still reaches download_resource when online" do
      Dir.mktmpdir("kotoshu-offline") do |dir|
        cache = recording_cache.new(cache_path: dir)
        Kotoshu.configuration.offline = false

        cache.download("en")

        expect(cache.download_attempts).to eq(["en"])
      end
    end
  end

  describe "Integrity::NetHTTP.get" do
    it "refuses before opening any connection when offline" do
      Kotoshu.configuration.offline = true

      expect { Kotoshu::Integrity::NetHTTP.get("https://example.invalid/manifest.json") }
        .to raise_error(Kotoshu::Integrity::NetHTTP::HttpError, /offline/)
    end
  end

  describe "KOTOSHU_OFFLINE environment variable" do
    it "turns enforcement on for a freshly built default configuration" do
      original_env = ENV.fetch("KOTOSHU_OFFLINE", nil)
      original_instance = Kotoshu.configuration
      ENV["KOTOSHU_OFFLINE"] = "1"
      Kotoshu.configuration = Kotoshu::Configuration.default

      Dir.mktmpdir("kotoshu-offline-env") do |dir|
        cache = recording_cache.new(cache_path: dir)

        expect(Kotoshu.configuration.offline).to be true
        expect { cache.download("en") }
          .to raise_error(Kotoshu::ResourceNotCachedError)
        expect(cache.download_attempts).to be_empty
      end
    ensure
      original_env.nil? ? ENV.delete("KOTOSHU_OFFLINE") : ENV["KOTOSHU_OFFLINE"] = original_env
      Kotoshu.configuration = original_instance if original_instance
    end
  end
end
