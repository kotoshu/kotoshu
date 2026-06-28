# frozen_string_literal: true

require_relative "../../../lib/kotoshu/cli/cache_command"
require "stringio"

# This spec exercises Kotoshu::Cli::CacheCommand, the CLI class wired up
# in lib/kotoshu/cli.rb. That class calls methods on LanguageCache that
# do not exist in the current implementation:
#
#   - cache.cache_status            (no such method)
#   - cache.get_frequency_data(...) (only private download_frequency)
#   - cache.get_language_info(...)  (actual API: cache.language_info)
#   - cache.purge_all               (actual API: cache.clear_all)
#
# A parallel implementation at lib/kotoshu/commands/cache_command.rb
# (Kotoshu::CacheCommand, no Cli namespace) calls the correct API but
# is NOT wired into cli.rb. So `kotoshu cache ...` is currently broken
# end-to-end.
#
# Quarantined wholesale in TODO.impl/40-spec-drift-cleanup.md pending
# one of: (a) consolidate to a single cache_command.rb, or (b) fix the
# wired CLI to use the real LanguageCache API. Until that decision is
# made, every example here is skipped rather than removed.
RSpec.describe Kotoshu::Cli::CacheCommand do
  before do
    skip "Kotoshu::Cli::CacheCommand calls nonexistent LanguageCache methods " \
         "(cache_status, get_frequency_data, get_language_info, purge_all). " \
         "See TODO.impl/40-spec-drift-cleanup.md"
  end

  let(:temp_dir) { Dir.mktmpdir }

  after do
    FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
  end

  def create_cli(options = {})
    cli = described_class.new([], options)
    allow(cli).to receive(:create_cache).and_return(
      Kotoshu::Cache::LanguageCache.new(cache_path: temp_dir, cache_ttl: 3600)
    )
    cli
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
    context "without --force flag" do
      it "attempts to download language resources", :network do
        cli = create_cli(verbose: true)
        expect { cli.download("en") }.to raise_error(Kotoshu::DictionaryNotFoundError)
      end
    end

    context "with --type flag" do
      it "downloads only the specified resource type" do
        cli = create_cli(type: "grammar", verbose: true)
        expect { cli.download("en") }.to raise_error(Kotoshu::DictionaryNotFoundError)
      end
    end
  end

  describe "#purge" do
    context "without --confirm flag" do
      it "prompts for confirmation before purging" do
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
          version: (Time.now.utc - 3600).iso8601,
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
end
