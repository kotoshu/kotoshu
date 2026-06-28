# frozen_string_literal: true

require "kotoshu"
require "stringio"
require "fileutils"
require "tempfile"

RSpec.describe Kotoshu::Cli::CacheCommand do
  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
  end

  def create_cli(options = {})
    described_class.new([], options.merge(cache_path: temp_dir))
  end

  def capture_output
    original_stdout = $stdout
    $stdout = StringIO.new
    yield
    $stdout.string
  ensure
    $stdout = original_stdout
  end

  describe "#info" do
    context "without --json flag" do
      it "displays cache statistics in text format" do
        cli = create_cli
        output = capture_output { cli.info }

        expect(output).to include("Cache Statistics")
        expect(output).to include("Location:")
        expect(output).to include("Languages cached:")
      end
    end

    context "with --json flag" do
      it "displays cache statistics in JSON format" do
        cli = create_cli(json: true)
        output = capture_output { cli.info }

        parsed = JSON.parse(output)
        expect(parsed).to include("hits", "misses", "size", "hit_rate")
      end
    end
  end

  describe "#clean" do
    context "without --dry-run flag" do
      it "removes expired entries and displays results" do
        lang_path = File.join(temp_dir, "languages", "en", "spelling")
        FileUtils.mkdir_p(lang_path)

        metadata = {
          version: (Time.now.utc - 48_000).iso8601,
          cached_at: (Time.now.utc - 48_000).iso8601,
          language: "en",
          type: "spelling",
          size: 1000
        }
        File.write(File.join(lang_path, "metadata.json"), JSON.generate(metadata))

        cli = create_cli
        output = capture_output { cli.clean }

        expect(output).to include("Cache cleaned:")
        expect(output).to include("Expired entries removed:")
      end
    end

    context "with --dry-run flag" do
      it "shows what would be removed without removing" do
        lang_path = File.join(temp_dir, "languages", "en", "spelling")
        FileUtils.mkdir_p(lang_path)

        metadata = {
          version: (Time.now.utc - 48_000).iso8601,
          cached_at: (Time.now.utc - 48_000).iso8601,
          language: "en",
          type: "spelling",
          size: 1000
        }
        File.write(File.join(lang_path, "metadata.json"), JSON.generate(metadata))

        cli = create_cli(dry_run: true)
        output = capture_output { cli.clean }

        expect(output).to include("Dry run")
        expect(File.exist?(File.join(lang_path, "metadata.json"))).to be true
      end
    end
  end

  describe "#download" do
    context "without --type flag" do
      it "raises DictionaryNotFoundError when no network", :network do
        cli = create_cli(verbose: true)
        expect { cli.download("en") }.to raise_error(Kotoshu::DictionaryNotFoundError)
      end
    end

    context "with --type flag" do
      it "raises DictionaryNotFoundError when no network", :network do
        cli = create_cli(type: "grammar", verbose: true)
        expect { cli.download("en") }.to raise_error(Kotoshu::DictionaryNotFoundError)
      end
    end
  end

  describe "#purge" do
    context "without --confirm flag" do
      it "aborts purge when user declines" do
        lang_path = File.join(temp_dir, "languages", "en", "spelling")
        FileUtils.mkdir_p(lang_path)
        File.write(File.join(lang_path, "metadata.json"), '{"version": "2024-01-01"}')

        allow($stdin).to receive(:gets).and_return("n\n")

        cli = create_cli
        capture_output { cli.purge }

        expect(File.exist?(lang_path)).to be true
      end
    end

    context "with --confirm flag" do
      it "purges without prompting" do
        lang_path = File.join(temp_dir, "languages", "en", "spelling")
        FileUtils.mkdir_p(lang_path)
        File.write(File.join(lang_path, "metadata.json"), '{"version": "2024-01-01"}')

        cli = create_cli(confirm: true)
        output = capture_output { cli.purge }

        expect(output).to include("Cache purged")
        expect(File.exist?(lang_path)).to be false
      end
    end
  end

  describe "#list" do
    context "without --json flag" do
      it "lists cached languages in text format" do
        lang_path = File.join(temp_dir, "languages", "en", "spelling")
        FileUtils.mkdir_p(lang_path)

        metadata = {
          version: Time.now.utc.iso8601,
          cached_at: Time.now.utc.iso8601,
          language: "en",
          type: "spelling",
          size: 1000
        }
        File.write(File.join(lang_path, "metadata.json"), JSON.generate(metadata))

        cli = create_cli
        output = capture_output { cli.list }

        expect(output).to include("Cached languages:")
        expect(output).to include("en")
      end

      it "shows message when no languages are cached" do
        cli = create_cli
        output = capture_output { cli.list }

        expect(output).to include("No cached languages found")
      end
    end

    context "with --json flag" do
      it "lists cached languages in JSON format" do
        cli = create_cli(json: true)
        output = capture_output { cli.list }

        parsed = JSON.parse(output)
        expect(parsed).to have_key("languages")
      end
    end
  end

  describe "#validate" do
    before do
      lang_path = File.join(temp_dir, "languages", "en", "spelling")
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

      grammar_path = File.join(temp_dir, "languages", "en", "grammar")
      FileUtils.mkdir_p(grammar_path)

      grammar_metadata = {
        version: Time.now.utc.iso8601,
        cached_at: Time.now.utc.iso8601,
        language: "en",
        type: "grammar",
        size: 500
      }
      File.write(File.join(grammar_path, "metadata.json"), JSON.generate(grammar_metadata))
      File.write(File.join(grammar_path, "rules.yaml"), "rules: []")
    end

    it "validates cached resources and shows status" do
      cli = create_cli
      output = capture_output { cli.validate("en") }

      expect(output).to include("Validating en")
      expect(output).to include("Spelling:")
      expect(output).to include("Grammar:")
    end

    it "shows checkmarks for valid resources" do
      cli = create_cli
      output = capture_output { cli.validate("en") }

      expect(output).to include("✓")
    end

    it "shows X for missing resources" do
      cli = create_cli
      output = capture_output { cli.validate("fr") }

      expect(output).to include("✗ Not cached")
    end
  end

  describe "#create_cache" do
    it "builds cache from options" do
      cli = described_class.new([], cache_path: temp_dir)
      cache_instance = cli.create_cache

      expect(cache_instance.cache_path).to eq(temp_dir)
    end
  end

  describe "#format_bytes" do
    it "formats bytes in human-readable format" do
      cli = create_cli

      expect(cli.format_bytes(0)).to eq("0 B")
      expect(cli.format_bytes(500)).to eq("500.0 B")
      expect(cli.format_bytes(1024)).to eq("1.0 KB")
      expect(cli.format_bytes(1_048_576)).to eq("1.0 MB")
      expect(cli.format_bytes(1_073_741_824)).to eq("1.0 GB")
    end
  end

  describe "#time_ago" do
    it "returns human-readable time ago string" do
      cli = create_cli

      expect(cli.time_ago(Time.now.utc.iso8601)).to eq("just now")
    end
  end

  describe "#evict" do
    def write_resource(lang, bytes:, cached_at:, type: "spelling")
      dir = File.join(temp_dir, "languages", lang, type)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "index.dic"), "x" * bytes)
      File.write(
        File.join(dir, "metadata.json"),
        JSON.generate(
          version: cached_at,
          cached_at: cached_at,
          language: lang,
          type: type,
          url: "https://example.test",
          checksum: "deadbeef"
        )
      )
      dir
    end

    # Subclass the CLI to inject a small-cap cache rather than stubbing
    # create_cache on any instance. The default 1 GB cap makes eviction
    # impractical to exercise in a unit test; the subclass points the
    # command at a 1 KB cap so we can force eviction with a few bytes
    # of fixture data.
    let(:cli_class) do
      cache_path = temp_dir
      Class.new(described_class) do
        define_method(:create_cache) do
          Kotoshu::Cache::LanguageCache.new(cache_path: cache_path, max_cache_size: 1_000)
        end
      end
    end

    context "with --dry-run flag" do
      it "reports nothing-to-evict when under the cap" do
        write_resource("en", bytes: 100, cached_at: "2026-03-01T00:00:00Z")
        cli = cli_class.new([], cache_path: temp_dir, dry_run: true)
        output = capture_output { cli.evict }

        expect(output).to include("Nothing to evict")
      end

      it "lists the entries that would be evicted without removing them" do
        old_dir = write_resource("en", bytes: 600, cached_at: "2026-01-01T00:00:00Z")
        new_dir = write_resource("de", bytes: 600, cached_at: "2026-03-01T00:00:00Z")
        cli = cli_class.new([], cache_path: temp_dir, dry_run: true)

        output = capture_output { cli.evict }

        expect(output).to include("Dry run")
        expect(output).to include("Would evict 1 entries")
        expect(output).to include(old_dir)
        expect(File.exist?(old_dir)).to be(true)
        expect(File.exist?(new_dir)).to be(true)
      end
    end

    context "without --dry-run flag" do
      it "removes the oldest entry and reports the reclaimed bytes" do
        old_dir = write_resource("en", bytes: 600, cached_at: "2026-01-01T00:00:00Z")
        new_dir = write_resource("de", bytes: 600, cached_at: "2026-03-01T00:00:00Z")
        cli = cli_class.new([], cache_path: temp_dir)

        output = capture_output { cli.evict }

        expect(output).to include("Evicted 1 entries")
        expect(File.exist?(old_dir)).to be(false)
        expect(File.exist?(new_dir)).to be(true)
      end

      it "reports nothing-to-evict when under the cap" do
        write_resource("fr", bytes: 100, cached_at: "2026-03-01T00:00:00Z")
        cli = cli_class.new([], cache_path: temp_dir)

        output = capture_output { cli.evict }

        expect(output).to include("Nothing to evict")
      end
    end
  end
end
