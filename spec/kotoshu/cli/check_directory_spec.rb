# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "json"
require "stringio"
require "kotoshu/cli"

# Directory-mode behavior specs (plan 88): real tmpdir trees, the
# real en dictionary from the committed fixtures written into an
# isolated cache, the real CLI. No doubles, no network.
RSpec.describe "kotoshu check directory mode" do
  EN_AFF = File.expand_path("../../integrational/fixtures/en_US.aff", __dir__)
  EN_DIC = File.expand_path("../../integrational/fixtures/en_US.dic", __dir__)

  around do |example|
    skip "en_US fixtures missing" unless File.exist?(EN_AFF) && File.exist?(EN_DIC)

    Dir.mktmpdir do |dir|
      @dir = dir
      @tree = File.join(dir, "tree")
      @cache = File.join(dir, "cache")
      FileUtils.mkdir_p(@tree)
      populate_en_cache(@cache)
      old_env = env_overrides
      set_env_overrides(@cache)
      Kotoshu::Configuration.reset
      Kotoshu.reset_spellchecker
      example.run
      Kotoshu::Configuration.reset
      Kotoshu.reset_spellchecker
      restore_env(old_env)
    end
  end

  def env_overrides
    %w[KOTOSHU_CACHE_PATH XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME].to_h { |k| [k, ENV.fetch(k, nil)] }
  end

  def set_env_overrides(cache)
    ENV["KOTOSHU_CACHE_PATH"] = cache
    ENV["XDG_CONFIG_HOME"] = File.join(@dir, "config")
    ENV["XDG_DATA_HOME"] = File.join(@dir, "local")
  end

  def restore_env(old_env)
    old_env.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  def populate_en_cache(cache)
    dir = File.join(cache, "languages", "en", "spelling")
    FileUtils.mkdir_p(dir)
    FileUtils.cp(EN_AFF, File.join(dir, "index.aff"))
    FileUtils.cp(EN_DIC, File.join(dir, "index.dic"))
    File.write(File.join(dir, "metadata.json"), {
      "language" => "en",
      "type" => "spelling",
      "version" => "2026-01-01T00:00:00Z",
      "cached_at" => Time.now.utc.iso8601,
      "source" => "fixture"
    }.to_json)
  end

  def write(relative, content = "hello world\n")
    path = File.join(@tree, relative)
    FileUtils.mkdir_p(File.dirname(path))
    File.write(path, content)
    path
  end

  def run_cli(*args)
    stdout = StringIO.new
    stderr = StringIO.new
    status = 0
    begin
      orig_out = $stdout
      orig_err = $stderr
      $stdout = stdout
      $stderr = stderr
      Kotoshu::Cli::Cli.start(args)
    rescue SystemExit => e
      status = e.status
    ensure
      $stdout = orig_out
      $stderr = orig_err
    end
    [stdout.string, stderr.string, status]
  end

  before do
    write("clean.md", "hello world\n")
    write("dirty.md", "wrold helo\n")
  end

  describe "text output" do
    it "prints one section per file plus a summary and exits 1 on errors" do
      output, _stderr, status = run_cli("check", @tree, "--language", "en")

      expect(status).to eq(1)
      expect(output).to include("OK #{File.join(@tree, 'clean.md')}")
      expect(output).to include("FAIL #{File.join(@tree, 'dirty.md')}")
      expect(output).to include("wrold")
      expect(output).to include("2 files checked, 4 words, 2 errors")
    end

    it "exits 0 when every file is clean" do
      File.write(File.join(@tree, "dirty.md"), "fixed now\n")
      output, _stderr, status = run_cli("check", @tree, "--language", "en")

      expect(status).to eq(0)
      expect(output).not_to include("FAIL")
    end

    it "reports when no text files are found" do
      FileUtils.rm(Dir[File.join(@tree, "*.md")])
      write("image.png")
      output, _stderr, status = run_cli("check", @tree, "--language", "en")

      expect(status).to eq(0)
      expect(output).to include("No text files found to check")
    end
  end

  describe "json output" do
    it "emits one combined document with per-file entries" do
      output, _stderr, status = run_cli("check", @tree, "--language", "en", "--format", "json")
      payload = JSON.parse(output.lines.reject { |line| line.start_with?("#") }.join)

      expect(status).to eq(1)
      expect(payload["fileCount"]).to eq(2)
      expect(payload["errorCount"]).to eq(2)
      expect(payload["success"]).to be(false)
      sources = payload["files"].map { |file| file["source"] }
      expect(sources).to include(File.join(@tree, "clean.md"), File.join(@tree, "dirty.md"))
      dirty = payload["files"].find { |file| file["source"].end_with?("dirty.md") }
      expect(dirty["errors"].map { |error| error["word"] }).to contain_exactly("wrold", "helo")
      clean = payload["files"].find { |file| file["source"].end_with?("clean.md") }
      expect(clean["success"]).to be(true)
    end
  end

  describe "sarif output" do
    it "emits one run per file" do
      output, _stderr, _status = run_cli("check", @tree, "--language", "en", "--format", "sarif")
      sarif = JSON.parse(output.lines.reject { |line| line.start_with?("#") }.join)

      expect(sarif["version"]).to eq("2.1.0")
      expect(sarif["runs"].length).to eq(2)
      uris = sarif["runs"].flat_map { |run| run["results"].map { |r| r["locations"][0]["physicalLocation"]["artifactLocation"]["uri"] } }
      expect(uris).to all(eq(File.join(@tree, "dirty.md")))
      expect(sarif["runs"].map { |run| run.dig("tool", "driver", "name") }).to all(eq("kotoshu"))
    end
  end

  describe "ignore and glob flags" do
    before do
      write("generated/notes.md", "wrold\n")
    end

    it "respects .gitignore files in the tree" do
      File.write(File.join(@tree, ".gitignore"), "generated/\n")
      output, _stderr, status = run_cli("check", @tree, "--language", "en")

      expect(status).to eq(1)
      expect(output).not_to include("generated")
    end

    it "applies --exclude" do
      _output, _stderr, status = run_cli("check", @tree, "--language", "en", "--exclude", "dirty.md")

      expect(status).to eq(1) # generated/notes.md still fails
      _out2, _err2, status2 = run_cli("check", @tree, "--language", "en", "--exclude", "*.md")
      expect(status2).to eq(0)
    end

    it "applies --include" do
      output, _stderr, status = run_cli("check", @tree, "--language", "en", "--include", "clean.md")

      expect(status).to eq(0)
      expect(output).to include("1 file checked")
    end
  end

  describe "multiple targets" do
    it "checks a directory and a file together" do
      extra = write("extra/only.txt", "teh\n")
      output, _stderr, status = run_cli("check", @tree, extra, "--language", "en")

      expect(status).to eq(1)
      expect(output).to include("teh")
      expect(output).to include("3 files checked")
    end
  end

  describe "baselines" do
    it "applies the baseline per file" do
      baseline = File.join(@dir, "baseline.json")
      checks = {}
      Dir[File.join(@tree, "*.md")].each do |path|
        text = File.read(path)
        checks[path] = [Kotoshu.spellchecker_for("en").check(text), text]
      end
      Kotoshu::Baseline::Store.from_checks(checks).save(baseline)

      _output, _stderr, status = run_cli("check", @tree, "--language", "en", "--baseline", baseline)
      expect(status).to eq(0)

      write("new-file.md", "xyzzy\n")
      output, _stderr, status = run_cli("check", @tree, "--language", "en", "--baseline", baseline)
      expect(status).to eq(1)
      expect(output).to include("xyzzy")
    end
  end

  describe "usage errors and interactive mode" do
    it "exits 2 for a missing target with the standard message" do
      _output, stderr, status = run_cli("check", File.join(@dir, "missing"), "--language", "en")

      expect(status).to eq(2)
      expect(stderr).to include("File not found")
    end

    it "prints the file-only notice for interactive mode instead of prompting" do
      _output, stderr, status = run_cli("check", @tree, "--language", "en", "--interactive")

      expect(status).to eq(1)
      expect(stderr).to include("Interactive mode is file-only")
    end
  end

  describe "single-file mode stays unchanged" do
    it "prints one section without a summary line for a lone file" do
      output, _stderr, status = run_cli("check", File.join(@tree, "dirty.md"), "--language", "en")

      expect(status).to eq(1)
      expect(output).to include("FAIL #{File.join(@tree, 'dirty.md')}")
      expect(output).not_to include("files checked")
    end
  end
end
