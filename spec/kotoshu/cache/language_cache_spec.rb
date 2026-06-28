# frozen_string_literal: true

require_relative "../../../lib/kotoshu/cache/language_cache"
require "fileutils"
require "tempfile"

RSpec.describe Kotoshu::Cache::LanguageCache do
  let(:temp_dir) { Dir.mktmpdir }
  let(:cache) { described_class.new(cache_path: temp_dir, cache_ttl: 3600) }

  after do
    FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
  end

  describe "#initialize" do
    it "creates a cache with default values" do
      cache = described_class.new

      expect(cache.cache_path).to end_with("kotoshu")
      expect(cache.cache_ttl).to eq(604_800) # 7 days
      expect(cache.max_cache_size).to eq(1_073_741_824) # 1 GB
    end

    it "creates a cache with custom values" do
      cache = described_class.new(
        cache_path: temp_dir,
        url_base: "https://example.com/dicts",
        cache_ttl: 7200,
        max_cache_size: 500_000_000
      )

      expect(cache.cache_path).to eq(temp_dir)
      expect(cache.url_base).to eq("https://example.com/dicts")
      expect(cache.cache_ttl).to eq(7200)
      expect(cache.max_cache_size).to eq(500_000_000)
    end

    it "creates cache directory if it doesn't exist" do
      new_cache_dir = File.join(temp_dir, "new_cache")
      expect { described_class.new(cache_path: new_cache_dir) }
        .to change { File.exist?(new_cache_dir) }
        .from(false)
        .to(true)
    end
  end

  describe "#language_path" do
    it "returns the correct path for spelling resources" do
      path = cache.language_path("en", "spelling")
      expected = File.join(temp_dir, "languages", "en", "spelling")
      expect(path).to eq(expected)
    end

    it "returns the correct path for grammar resources" do
      path = cache.language_path("de", "grammar")
      expected = File.join(temp_dir, "languages", "de", "grammar")
      expect(path).to eq(expected)
    end

    it "is consistent with resource_dir_for" do
      expect(cache.language_path("fr", "spelling"))
        .to eq(cache.resource_dir_for("fr:spelling"))
    end
  end

  describe "resource presence interface" do
    describe "#available?" do
      it "returns false for non-cached resources" do
        expect(cache.available?("en:spelling")).to be false
      end

      it "returns true when metadata + dictionary files exist" do
        lang_path = cache.language_path("en", "spelling")
        FileUtils.mkdir_p(lang_path)
        File.write(File.join(lang_path, "metadata.json"),
                   JSON.generate(version: Time.now.utc.iso8601,
                                 cached_at: Time.now.utc.iso8601))
        File.write(File.join(lang_path, "index.aff"), "AFF")
        File.write(File.join(lang_path, "index.dic"), "DIC")

        expect(cache.available?("en:spelling")).to be true
      end

      it "returns false for unsupported language" do
        expect(cache.available?("xx:spelling")).to be false
      end
    end

    describe "#cached_resources" do
      it "returns empty list for an empty cache" do
        expect(cache.cached_resources).to eq([])
      end

      it "returns resource IDs for each cached language directory" do
        lang_path = cache.language_path("en", "spelling")
        FileUtils.mkdir_p(lang_path)
        File.write(File.join(lang_path, "metadata.json"), '{"version":"x"}')

        expect(cache.cached_resources).to include("en:spelling")
      end
    end

    describe "#clear" do
      it "removes a specific cached resource" do
        lang_path = cache.language_path("en", "spelling")
        FileUtils.mkdir_p(lang_path)
        File.write(File.join(lang_path, "metadata.json"), "{}")

        expect(cache.clear("en:spelling")).to be true
        expect(File.exist?(lang_path)).to be false
      end

      it "returns false when the resource is absent" do
        expect(cache.clear("en:spelling")).to be false
      end
    end

    describe "#clear_all" do
      it "removes every cached resource" do
        lang_path = cache.language_path("en", "spelling")
        FileUtils.mkdir_p(lang_path)
        File.write(File.join(lang_path, "metadata.json"), "{}")

        cache.clear_all

        expect(File.exist?(lang_path)).to be false
      end

      it "resets statistics" do
        cache.reset_stats

        stats = cache.stats
        expect(stats[:hits]).to eq(0)
        expect(stats[:misses]).to eq(0)
      end
    end
  end

  describe "#stats" do
    it "returns the documented statistics shape" do
      stats = cache.stats

      expect(stats).to include(:hits, :misses, :total, :hit_rate,
                               :cached_resources, :size_bytes, :oldest_entry)
      expect(stats[:hits]).to eq(0)
      expect(stats[:misses]).to eq(0)
      expect(stats[:hit_rate]).to eq(0.0)
      expect(stats[:cached_resources]).to eq([])
    end

    it "includes cached resources in stats" do
      lang_path = cache.language_path("en", "spelling")
      FileUtils.mkdir_p(lang_path)

      metadata = {
        version: Time.now.utc.iso8601,
        cached_at: Time.now.utc.iso8601,
        language: "en",
        type: "spelling",
        size: 2048
      }
      File.write(File.join(lang_path, "metadata.json"), JSON.generate(metadata))

      stats = cache.stats
      expect(stats[:cached_resources]).to include("en:spelling")
    end
  end

  describe "#reset_stats" do
    it "resets hit and miss counters" do
      cache.reset_stats

      stats = cache.stats
      expect(stats[:hits]).to eq(0)
      expect(stats[:misses]).to eq(0)
    end
  end

  describe "#get_spelling" do
    context "when resources are cached and valid" do
      before do
        lang_path = cache.language_path("en", "spelling")
        FileUtils.mkdir_p(lang_path)

        metadata = {
          version: Time.now.utc.iso8601,
          cached_at: Time.now.utc.iso8601,
          language: "en",
          type: "spelling",
          checksum: "abc123",
          size: 1000
        }
        File.write(File.join(lang_path, "metadata.json"), JSON.generate(metadata))

        File.write(File.join(lang_path, "index.aff"), "AFF content")
        File.write(File.join(lang_path, "index.dic"), "DIC content")
      end

      it "returns cached spelling dictionary" do
        result = cache.get_spelling("en")

        expect(result[:cached]).to be true
        expect(result[:aff_path]).to end_with("languages/en/spelling/index.aff")
        expect(result[:dic_path]).to end_with("languages/en/spelling/index.dic")
        expect(result[:metadata]["language"]).to eq("en")
      end
    end

    context "when resources are not cached" do
      it "raises DictionaryNotFoundError for invalid URL", :network do
        cache_with_invalid_url = described_class.new(
          cache_path: temp_dir,
          url_base: "https://invalid-url-that-does-not-exist.local"
        )

        expect {
          cache_with_invalid_url.get_spelling("en")
        }.to raise_error(Kotoshu::DictionaryNotFoundError)
      end
    end
  end

  describe "#get_grammar" do
    context "when resources are cached and valid" do
      before do
        lang_path = cache.language_path("en", "grammar")
        FileUtils.mkdir_p(lang_path)

        metadata = {
          version: Time.now.utc.iso8601,
          cached_at: Time.now.utc.iso8601,
          language: "en",
          type: "grammar",
          checksum: "def456",
          size: 500
        }
        File.write(File.join(lang_path, "metadata.json"), JSON.generate(metadata))

        File.write(File.join(lang_path, "rules.yaml"), "rules: []")
      end

      it "returns cached grammar rules" do
        result = cache.get_grammar("en")

        expect(result[:cached]).to be true
        expect(result[:rules_path]).to end_with("languages/en/grammar")
        expect(result[:metadata]["type"]).to eq("grammar")
      end
    end
  end

  describe "#clean" do
    before do
      lang_path = cache.language_path("en", "spelling")
      FileUtils.mkdir_p(lang_path)

      metadata = {
        version: (Time.now.utc - 48_000).iso8601, # expired (>1 hour TTL)
        cached_at: (Time.now.utc - 48_000).iso8601,
        language: "en",
        type: "spelling",
        size: 1000
      }
      File.write(File.join(lang_path, "metadata.json"), JSON.generate(metadata))
    end

    it "removes expired entries" do
      result = cache.clean

      expect(result[:expired_entries_removed]).to be > 0
      expect(File.exist?(File.join(cache.language_path("en", "spelling"), "metadata.json"))).to be false
    end
  end
end
