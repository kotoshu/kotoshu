# frozen_string_literal: true

require "spec_helper"
require "json"
require "open3"
require "tmpdir"

RSpec.describe "kotoshu check output formats", :network do
  let(:ruby) { Gem.ruby }
  let(:bundler) { "bundle" }
  let(:exe) { File.expand_path("exe/kotoshu", Dir.pwd) }

  around do |ex|
    Dir.mktmpdir do |dir|
      ENV["XDG_CACHE_HOME"] = "#{dir}/cache"
      ENV["XDG_CONFIG_HOME"] = "#{dir}/config"
      ENV["XDG_DATA_HOME"] = "#{dir}/local"
      Kotoshu::Configuration.reset
      Kotoshu.reset_spellchecker
      Kotoshu.setup(:en, want: %i[spelling])
      @temp_file = File.join(dir, "input.txt")
      File.write(@temp_file, "wrold\n")
      ex.run
    end
  end

  def run_cli(*args)
    env = {
      "XDG_CACHE_HOME" => ENV.fetch("XDG_CACHE_HOME"),
      "XDG_CONFIG_HOME" => ENV.fetch("XDG_CONFIG_HOME"),
      "XDG_DATA_HOME" => ENV.fetch("XDG_DATA_HOME")
    }
    stdout, status = Open3.capture2e(env, ruby, "-S", bundler, "exec", exe, "check", *args)
    [stdout, status]
  end

  describe "--format json" do
    it "emits valid JSON with the documented top-level keys" do
      output, status = run_cli("--format", "json", "--language", "en", @temp_file)
      payload = JSON.parse(output.lines.reject { |l| l.start_with?("#") }.join)

      expect(payload.keys).to include("success", "wordCount", "errorCount",
                                      "uniqueErrorCount", "errors", "source")
      expect(payload["success"]).to be(false)
      expect(payload["errorCount"]).to eq(1)
      expect(payload["source"]).to eq(@temp_file)
      expect(payload["errors"].first["word"]).to eq("wrold")
      expect(status.exitstatus).to eq(1)
    end

    it "emits success JSON with zero errors on a clean file" do
      File.write(@temp_file, "hello world\n")
      output, status = run_cli("--format", "json", "--language", "en", @temp_file)
      payload = JSON.parse(output.lines.reject { |l| l.start_with?("#") }.join)

      expect(payload["success"]).to be(true)
      expect(payload["errorCount"]).to eq(0)
      expect(status.exitstatus).to eq(0)
    end
  end

  describe "--format sarif" do
    it "emits SARIF v2.1 with required top-level keys" do
      output, _status = run_cli("--format", "sarif", "--language", "en", @temp_file)
      payload = JSON.parse(output.lines.reject { |l| l.start_with?("#") }.join)

      expect(payload["version"]).to eq("2.1.0")
      expect(payload["$schema"]).to include("sarif-2.1.0")
      expect(payload["runs"]).to be_an(Array)
      expect(payload["runs"].length).to eq(1)
    end

    it "includes tool.driver with kotoshu identity and rules" do
      output, _status = run_cli("--format", "sarif", "--language", "en", @temp_file)
      payload = JSON.parse(output.lines.reject { |l| l.start_with?("#") }.join)

      driver = payload["runs"].first["tool"]["driver"]
      expect(driver["name"]).to eq("kotoshu")
      expect(driver["informationUri"]).to eq("https://github.com/kotoshu/kotoshu")
      expect(driver["rules"].first["id"]).to eq("kotoshu/spelling")
    end

    it "reports each misspelling as a result with location and message" do
      output, _status = run_cli("--format", "sarif", "--language", "en", @temp_file)
      payload = JSON.parse(output.lines.reject { |l| l.start_with?("#") }.join)

      result = payload["runs"].first["results"].first
      expect(result["ruleId"]).to eq("kotoshu/spelling")
      expect(result["level"]).to eq("warning")
      expect(result["message"]["text"]).to include("'wrold'")

      location = result["locations"].first["physicalLocation"]
      expect(location["artifactLocation"]["uri"]).to eq(@temp_file)
      expect(location["region"]["charOffset"]).to eq(0)
      expect(location["region"]["charLength"]).to eq(5)
    end

    it "emits an empty results array when the document is clean" do
      File.write(@temp_file, "hello world\n")
      output, _status = run_cli("--format", "sarif", "--language", "en", @temp_file)
      payload = JSON.parse(output.lines.reject { |l| l.start_with?("#") }.join)

      expect(payload["runs"].first["results"]).to eq([])
    end
  end

  describe "exit codes" do
    it "returns 0 when no errors are found" do
      File.write(@temp_file, "hello\n")
      _out, status = run_cli("--language", "en", @temp_file)
      expect(status.exitstatus).to eq(0)
    end

    it "returns 1 when errors are found" do
      _out, status = run_cli("--language", "en", @temp_file)
      expect(status.exitstatus).to eq(1)
    end
  end
end
