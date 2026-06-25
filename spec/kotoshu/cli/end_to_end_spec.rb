# frozen_string_literal: true

require "spec_helper"
require "open3"
require "tmpdir"
require "fileutils"
require "json"

# End-to-end CLI spec for the 0.2 release cut.
# Drives the actual `exe/kotoshu` binary via Open3 so we exercise the
# real require chain, exit codes, and stdout/stderr streams — no mocking.
#
# Acceptance criteria covered (from TODO.impl/00-cut-0.2.md):
#   - `kotoshu check FILE` exits 1 when errors are found, with suggestions
#   - `kotoshu check FILE` exits 0 when the file is clean
#   - `kotoshu check MISSING` exits 2 (usage error)
#   - `kotoshu check FILE --language XX --offline` exits 3 when XX is uncached
#   - `--format json` produces parseable JSON with the expected shape
#   - stdin input works when no FILE argument is given
RSpec.describe "kotoshu CLI end-to-end", :slow do
  EN_AFF_FIXTURE = File.expand_path("../../integrational/fixtures/en_US.aff", __dir__)
  EN_DIC_FIXTURE = File.expand_path("../../integrational/fixtures/en_US.dic", __dir__)

  before(:all) do
    skip "en_US fixtures missing" unless File.exist?(EN_AFF_FIXTURE) && File.exist?(EN_DIC_FIXTURE)
  end

  # Per-test sandbox: a fresh KOTOSHU_HOME so cache state never leaks
  # between examples or into the user's real ~/.kotoshu.
  let(:kotoshu_home) { Dir.mktmpdir("kotoshu-cli-home") }

  # File contents used across examples.
  let(:clean_text) { "hello world\nthis is a test\n" }
  let(:dirty_text) { "helo wrld\nrecieve seperate\n" }

  after do
    FileUtils.rm_rf(kotoshu_home) if Dir.exist?(kotoshu_home)
  end

  # Populate the cache so the spec doesn't hit the network.
  def populate_en_cache(home)
    dir = File.join(home, "languages", "en", "spelling")
    FileUtils.mkdir_p(dir)
    FileUtils.cp(EN_AFF_FIXTURE, File.join(dir, "index.aff"))
    FileUtils.cp(EN_DIC_FIXTURE, File.join(dir, "index.dic"))
    File.write(File.join(dir, "metadata.json"), {
      "language" => "en",
      "type" => "spelling",
      "version" => "2026-01-01T00:00:00Z",
      "cached_at" => "2026-06-25T00:00:00Z",
      "source" => "fixture"
    }.to_json)
  end

  # Run the CLI with the sandboxed KOTOSHU_HOME. Returns stdout, stderr, exit.
  def run_cli(*args, stdin: "")
    env = {
      "KOTOSHU_HOME" => kotoshu_home,
      # Defend against inherited KOTOSHU_OFFLINE=1 in the parent env.
      "KOTOSHU_OFFLINE" => "0"
    }
    stdout, stderr, status = Open3.capture3(env, *cli_command, *args,
                                            stdin_data: stdin)
    [stdout, stderr, status.exitstatus]
  end

  # Path to the actual exe so we go through the same require chain as users.
  def cli_command
    exe = File.expand_path("../../../exe/kotoshu", __dir__)
    ["bundle", "exec", "ruby", exe]
  end

  def write_tmp_file(name, contents)
    path = File.join(kotoshu_home, name)
    File.write(path, contents)
    path
  end

  describe "check" do
    context "with a clean file" do
      it "exits 0 and reports no errors" do
        populate_en_cache(kotoshu_home)
        file = write_tmp_file("clean.txt", clean_text)
        stdout, _stderr, code = run_cli("check", file, "--offline")

        expect(code).to eq(0)
        expect(stdout).to include("OK")
        expect(stdout).to include("no errors")
      end
    end

    context "with a file containing spelling errors" do
      it "exits 1 and lists suggestions for each error" do
        populate_en_cache(kotoshu_home)
        file = write_tmp_file("dirty.txt", dirty_text)
        stdout, _stderr, code = run_cli("check", file, "--offline")

        expect(code).to eq(1)
        expect(stdout).to include("FAIL")
        expect(stdout).to include("helo")
        expect(stdout).to include("wrld")
        # Suggestions appear after the arrow.
        expect(stdout).to match(/helo\s*->\s*\w+/)
      end
    end

    context "when the file does not exist" do
      it "exits 2 with a clear usage error on stderr" do
        _stdout, stderr, code = run_cli("check", "/nonexistent/path.txt")

        expect(code).to eq(2)
        expect(stderr).to match(/not found/i)
      end
    end

    context "with --offline on an uncached language" do
      it "exits 3 with a prefetch hint" do
        # Do NOT populate the cache for this language.
        file = write_tmp_file("dirty.txt", dirty_text)
        _stdout, stderr, code = run_cli(
          "check", file, "--language", "de", "--offline"
        )

        expect(code).to eq(3)
        expect(stderr).to match(/not cached/i)
        expect(stderr).to match(/kotoshu cache download/)
      end
    end

    context "with --format json" do
      it "emits parseable JSON with the expected shape" do
        populate_en_cache(kotoshu_home)
        file = write_tmp_file("dirty.txt", dirty_text)
        stdout, _stderr, code = run_cli("check", file, "--offline", "--format", "json")

        expect(code).to eq(1)
        payload = JSON.parse(stdout)
        expect(payload["success"]).to eq(false)
        expect(payload["errorCount"]).to be > 0
        expect(payload["errors"]).to be_an(Array)
        first = payload["errors"].first
        expect(first["word"]).to eq("helo")
        expect(first["suggestions"]).to include("hello")
        expect(payload["source"]).to eq(file)
      end
    end

    context "with --format sarif" do
      it "emits SARIF 2.1.0 with one result per error" do
        populate_en_cache(kotoshu_home)
        file = write_tmp_file("dirty.txt", dirty_text)
        stdout, _stderr, code = run_cli("check", file, "--offline", "--format", "sarif")

        expect(code).to eq(1)
        sarif = JSON.parse(stdout)
        expect(sarif["version"]).to eq("2.1.0")
        expect(sarif["$schema"]).to include("sarif-2.1.0")
        run = sarif["runs"].first
        expect(run["tool"]["driver"]["name"]).to eq("kotoshu")
        rules = run["tool"]["driver"]["rules"]
        expect(rules.first["id"]).to eq("kotoshu/spelling")

        results = run["results"]
        expect(results.length).to be > 0
        first = results.first
        expect(first["ruleId"]).to eq("kotoshu/spelling")
        expect(first["level"]).to eq("warning")
        expect(first["message"]["text"]).to include("helo")
        location = first["locations"].first["physicalLocation"]
        expect(location["artifactLocation"]["uri"]).to eq(file)
        expect(location["region"]["charLength"]).to eq(4)
      end
    end

    context "with --interactive" do
      it "navigates errors and exits on q" do
        populate_en_cache(kotoshu_home)
        file = write_tmp_file("dirty.txt", dirty_text)
        # Drive the interactive loop: next, accept suggestion 1, quit.
        stdout, _stderr, code = run_cli("check", file, "--offline", "--interactive",
                                       stdin: "n\n1\nq\n")

        expect(code).to eq(1)
        expect(stdout).to match(/Interactive review/)
        expect(stdout).to match(/'\w+' \(offset/)
        expect(stdout).to match(/Review complete/)
      end
    end

    context "reading from stdin" do
      it "checks piped input and uses <stdin> as the source label" do
        populate_en_cache(kotoshu_home)
        stdout, _stderr, code = run_cli("check", "--offline", stdin: dirty_text)

        expect(code).to eq(1)
        expect(stdout).to include("<stdin>")
        expect(stdout).to include("helo")
      end
    end
  end

  describe "version" do
    it "prints the version banner" do
      stdout, _stderr, code = run_cli("version")
      expect(code).to eq(0)
      expect(stdout).to match(/Kotoshu version/)
      expect(stdout).to match(/Ruby \d/)
    end
  end

  describe "fetch" do
    it "exits 2 when no languages are given" do
      _stdout, stderr, code = run_cli("fetch")
      expect(code).to eq(2)
      expect(stderr).to match(/at least one LANGUAGE/i)
    end

    it "exits 3 in offline mode when the language is not cached" do
      _stdout, _stderr, code = run_cli("fetch", "de", "--offline")
      expect(code).to eq(3)
    end

    it "pre-warms a cached language in offline mode (exit 0)" do
      populate_en_cache(kotoshu_home)
      stdout, _stderr, code = run_cli("fetch", "en", "--offline")
      expect(code).to eq(0)
      expect(stdout).to match(/Fetching en\.\.\. OK/)
      expect(stdout).to match(/spelling: cached/)
    end

    it "reports per-language status for multiple languages" do
      populate_en_cache(kotoshu_home)
      stdout, _stderr, code = run_cli("fetch", "en", "de", "--offline")
      expect(code).to eq(3) # de fails
      expect(stdout).to match(/Fetching en\.\.\. OK/)
      expect(stdout).to match(/Fetching de\.\.\. FAIL/)
    end
  end
end
