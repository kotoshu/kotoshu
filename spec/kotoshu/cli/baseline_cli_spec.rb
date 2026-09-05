# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "tmpdir"

# End-to-end CLI behavior for baselines and --show-suppressed
# (TODO.impl/82 Track B), mirroring check_format_spec: the real
# executable, an isolated XDG cache, and the en dictionary setup.
RSpec.describe "kotoshu check --baseline", :network do
  let(:ruby) { Gem.ruby }
  let(:bundler) { "bundle" }
  let(:exe) { File.expand_path("exe/kotoshu", Dir.pwd) }
  let(:doc) { File.join(@dir, "doc.txt") }

  around do |ex|
    Dir.mktmpdir do |dir|
      ENV["XDG_CACHE_HOME"] = "#{dir}/cache"
      ENV["XDG_CONFIG_HOME"] = "#{dir}/config"
      ENV["XDG_DATA_HOME"] = "#{dir}/local"
      Kotoshu::Configuration.reset
      Kotoshu.reset_spellchecker
      Kotoshu.setup(:en, want: %i[spelling])
      @dir = dir
      ex.run
    end
  end

  def run_cli(*args)
    env = {
      "XDG_CACHE_HOME" => ENV.fetch("XDG_CACHE_HOME"),
      "XDG_CONFIG_HOME" => ENV.fetch("XDG_CONFIG_HOME"),
      "XDG_DATA_HOME" => ENV.fetch("XDG_DATA_HOME")
    }
    stdout, status = Open3.capture2e(env, ruby, "-S", bundler, "exec", exe, *args)
    [stdout, status]
  end

  def parse_json(stdout)
    JSON.parse(stdout.lines.reject { |l| l.start_with?("#") }.join)
  end

  before { File.write(doc, "wrold helo\n") }

  describe "kotoshu baseline init" do
    it "writes the canonical baseline JSON from current findings" do
      output, status = run_cli("baseline", "init", doc)
      path = File.join(Dir.pwd, ".kotoshu-baseline.json")

      expect(status.exitstatus).to eq(0)
      expect(File).to exist(path)
      payload = JSON.parse(File.read(path))
      expect(payload["version"]).to eq(1)
      words = payload["entries"].map { |e| e["word"] }.sort
      expect(words).to eq(%w[helo wrold])
      wrold = payload["entries"].find { |e| e["word"] == "wrold" }
      expect(wrold["file"]).to eq(doc)
      expect(wrold["count"]).to eq(1)
      expect(wrold["line"]).to eq(1)
      expect(output).to include("Wrote")
    ensure
      File.delete(path) if File.exist?(path)
    end

    it "refuses to run without files" do
      _output, status = run_cli("baseline", "init")
      expect(status.exitstatus).to eq(2)
    end
  end

  describe "--baseline" do
    it "exits 0 when every error is covered, and 1 on a new error" do
      baseline = File.join(@dir, ".kotoshu-baseline.json")
      run_cli("baseline", "init", doc, "--output", baseline)

      _out0, status0 = run_cli("check", doc, "--baseline", baseline, "--language", "en")
      expect(status0.exitstatus).to eq(0)

      File.write(doc, "wrold helo xyzzy\n")
      _out1, status1 = run_cli("check", doc, "--baseline", baseline, "--language", "en")
      expect(status1.exitstatus).to eq(1)
    end

    it "reports baseline suppression counts and staleness in text output" do
      baseline = File.join(@dir, ".kotoshu-baseline.json")
      run_cli("baseline", "init", doc, "--output", baseline)

      File.write(doc, "wrold\n") # helo fixed -> stale
      output, _status = run_cli("check", doc, "--baseline", baseline, "--language", "en")
      expect(output).to include("1 error(s) suppressed by baseline")
      expect(output).to include("Baseline: 1 stale entry")
    end

    it "adds suppressed and baseline keys to JSON output" do
      baseline = File.join(@dir, ".kotoshu-baseline.json")
      run_cli("baseline", "init", doc, "--output", baseline)

      output, _status = run_cli(
        "check", doc, "--baseline", baseline, "--language", "en", "--format", "json"
      )
      payload = parse_json(output)

      expect(payload["success"]).to be(true)
      expect(payload["suppressedCount"]).to eq(2)
      expect(payload["suppressedErrors"].map { |e| e["word"] }.sort)
        .to eq(%w[helo wrold])
      expect(payload["suppressedErrors"].first["suppressed"]).to be(true)
      expect(payload["baseline"]["staleCount"]).to eq(0)
    end
  end

  describe "--show-suppressed" do
    it "lists inline-suppressed entries in text output" do
      File.write(doc, "kotoshu:disable-line wrold helo\n")
      output, status = run_cli(
        "check", doc, "--language", "en", "--show-suppressed"
      )

      expect(status.exitstatus).to eq(0)
      expect(output).to include("suppressed [inline]: wrold")
      expect(output).to include("suppressed [inline]: helo")
    end

    it "omits suppressed entries by default" do
      File.write(doc, "kotoshu:disable-line wrold helo\n")
      output, status = run_cli("check", doc, "--language", "en")

      expect(status.exitstatus).to eq(0)
      expect(output).not_to include("wrold")
    end
  end

  describe "SARIF marking" do
    it "tags baseline-suppressed results with a baseline suppression" do
      baseline = File.join(@dir, ".kotoshu-baseline.json")
      run_cli("baseline", "init", doc, "--output", baseline)

      output, _status = run_cli(
        "check", doc, "--baseline", baseline, "--language", "en", "--format", "sarif"
      )
      results = parse_json(output)["runs"].first["results"]

      expect(results.length).to eq(2)
      expect(results).to all(include("suppressions"))
      expect(results.map { |r| r["suppressions"].first["justification"] })
        .to all(eq("baseline"))
      expect(results.map { |r| r["level"] }).to all(eq("note"))
    end

    it "includes inline-suppressed results only with --show-suppressed" do
      File.write(doc, "kotoshu:disable-line wrold\n")

      quiet, _s = run_cli("check", doc, "--language", "en", "--format", "sarif")
      expect(parse_json(quiet)["runs"].first["results"]).to eq([])

      loud, _s = run_cli(
        "check", doc, "--language", "en", "--format", "sarif", "--show-suppressed"
      )
      results = parse_json(loud)["runs"].first["results"]
      # "kotoshu" itself is not an English word, so the directive
      # comment contributes a suppressed entry too
      expect(results.map { |r| r["message"]["text"] }).to include(/wrold/)
      expect(results).to all(include("suppressions"))
      expect(results.map { |r| r["suppressions"].first["justification"] })
        .to all(eq("inline"))
    end
  end
end
