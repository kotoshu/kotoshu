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
      expect(cache.cache_ttl).to eq(86_400) # 24 hours
      expect(cache.max_cache_size).to eq(1_073_741_824) # 1GB
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
  end

  describe "cache interface" do
    describe "#read and #write" do
      it "writes and reads values" do
        cache.write("test:key", { value: "test_data" })
        result = cache.read("test:key")

        expect(result).to eq({ "value" => "test_data" })
      end

      it "returns nil for non-existent keys" do
        expect(cache.read("nonexistent:key")).to be_nil
      end

      it "returns the written value from #write" do
        result = cache.write("test:key", { value: "test" })
        expect(result).to eq({ value: "test" })
      end
    end

    describe "#fetch" do
      it "returns cached value if exists" do
        cache.write("test:key", { value: "cached" })
        result = cache.fetch("test:key") { { value: "computed" } }

        expect(result["value"]).to eq("cached")
      end

      it "computes and caches value if not exists" do
        result = cache.fetch("test:new_key") { { value: "computed" } }

        # fetch returns the original value (with symbol keys)
        expect(result[:value]).to eq("computed")
        # read returns the cached value (with string keys after JSON)
        expect(cache.read("test:new_key")["value"]).to eq("computed")
      end

      it "tracks cache hits and misses" do
        cache.write("test:key", { value: "cached" })

        cache.fetch("test:key") { { value: "computed" } }
        cache.fetch("test:miss") { { value: "computed" } }

        stats = cache.stats
        expect(stats[:hits]).to eq(1)
        expect(stats[:misses]).to eq(1)
      end
    end

    describe "#delete" do
      it "deletes a cached value" do
        cache.write("test:key", { value: "test" })
        result = cache.delete("test:key")

        expect(result).to eq({ "value" => "test" })
        expect(cache.read("test:key")).to be_nil
      end

      it "returns nil for non-existent keys" do
        expect(cache.delete("nonexistent:key")).to be_nil
      end
    end

    describe "#key?" do
      it "returns true for existing keys" do
        cache.write("test:key", { value: "test" })
        expect(cache.key?("test:key")).to be true
      end

      it "returns false for non-existent keys" do
        expect(cache.key?("nonexistent:key")).to be false
      end
    end

    describe "#clear" do
      it "removes all cached entries" do
        cache.write("test:key1", { value: "test1" })
        cache.write("test:key2", { value: "test2" })

        cache.clear

        expect(cache.read("test:key1")).to be_nil
        expect(cache.read("test:key2")).to be_nil
      end

      it "resets statistics" do
        cache.write("test:key", { value: "test" })
        cache.read("test:key")

        cache.clear

        stats = cache.stats
        expect(stats[:hits]).to eq(0)
        expect(stats[:misses]).to eq(0)
      end
    end

    describe "#size" do
      it "returns 0 for empty cache" do
        expect(cache.size).to eq(0)
      end

      it "returns the number of entries" do
        # Create metadata files to simulate cached languages
        lang_path = cache.language_path("en", "spelling")
        FileUtils.mkdir_p(lang_path)
        File.write(File.join(lang_path, "metadata.json"), '{"version": "2024-01-01T00:00:00Z"}')

        expect(cache.size).to eq(1)
      end
    end

    describe "#stats" do
      it "returns cache statistics" do
        stats = cache.stats

        expect(stats).to include(:hits, :misses, :size, :hit_rate, :total_size_bytes, :cached_languages, :oldest_entry)
        expect(stats[:hits]).to eq(0)
        expect(stats[:misses]).to eq(0)
        expect(stats[:hit_rate]).to eq(0)
      end
    end

    describe "#reset_stats" do
      it "resets hit and miss counters" do
        cache.write("test:key", { value: "test" })
        cache.read("test:key")
        cache.read("test:miss")

        cache.reset_stats

        stats = cache.stats
        expect(stats[:hits]).to eq(0)
        expect(stats[:misses]).to eq(0)
      end
    end
  end

  describe "#get_spelling" do
    context "when resources are cached and valid" do
      before do
        lang_path = cache.language_path("en", "spelling")
        FileUtils.mkdir_p(lang_path)

        # Create metadata file
        metadata = {
          version: Time.now.utc.iso8601,
          language: "en",
          type: "spelling",
          checksum: "abc123",
          size: 1000
        }
        File.write(File.join(lang_path, "metadata.json"), JSON.generate(metadata))

        # Create dictionary files
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

        # Create metadata file
        metadata = {
          version: Time.now.utc.iso8601,
          language: "en",
          type: "grammar",
          checksum: "def456",
          size: 500
        }
        File.write(File.join(lang_path, "metadata.json"), JSON.generate(metadata))

        # Create rules file
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
      # Create cached entries
      lang_path = cache.language_path("en", "spelling")
      FileUtils.mkdir_p(lang_path)

      metadata = {
        version: (Time.now.utc - 48_000).iso8601, # 2 days ago (expired)
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

  describe "#stats" do
    before do
      # Create cached entries
      lang_path = cache.language_path("en", "spelling")
      FileUtils.mkdir_p(lang_path)

      metadata = {
        version: Time.now.utc.iso8601,
        language: "en",
        type: "spelling",
        size: 2048
      }
      File.write(File.join(lang_path, "metadata.json"), JSON.generate(metadata))
    end

    it "includes cached languages in stats" do
      stats = cache.stats

      expect(stats[:cached_languages]).to include("en")
    end

    it "includes total size in stats" do
      stats = cache.stats

      expect(stats[:total_size_bytes]).to eq(2048)
    end
  end
end
