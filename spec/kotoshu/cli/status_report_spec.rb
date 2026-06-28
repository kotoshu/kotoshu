# frozen_string_literal: true

require "spec_helper"
require "kotoshu/cli/status_report"
require "tmpdir"

RSpec.describe Kotoshu::Cli::StatusReport do
  let(:temp_dir) { Dir.mktmpdir }
  let(:cache_path) { File.join(temp_dir, "cache") }
  let(:config_path) { File.join(temp_dir, "config") }
  let(:data_path) { File.join(temp_dir, "data") }

  around do |ex|
    Dir.mkdir(cache_path) unless File.directory?(cache_path)
    Dir.mkdir(config_path) unless File.directory?(config_path)
    Dir.mkdir(data_path) unless File.directory?(data_path)
    prior = ENV.to_h
    ENV["KOTOSHU_CACHE_PATH"] = cache_path
    ENV["KOTOSHU_CONFIG_PATH"] = config_path
    ENV["KOTOSHU_DATA_PATH"] = data_path
    ex.run
  ensure
    ENV.replace(prior) if prior
    FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
  end

  describe ".format_bytes" do
    it "returns 0 B for nil" do
      expect(described_class.format_bytes(nil)).to eq("0 B")
    end

    it "returns 0 B for zero" do
      expect(described_class.format_bytes(0)).to eq("0 B")
    end

    it "formats bytes without decimal" do
      expect(described_class.format_bytes(512)).to eq("512 B")
    end

    it "formats kilobytes with one decimal" do
      expect(described_class.format_bytes(1_500)).to eq("1.5 KB")
    end

    it "formats megabytes" do
      expect(described_class.format_bytes(5 * 1024 * 1024)).to eq("5.0 MB")
    end

    it "formats gigabytes" do
      expect(described_class.format_bytes(2 * 1024 * 1024 * 1024)).to eq("2.0 GB")
    end
  end

  describe ".directory_size" do
    it "returns 0 for missing directory" do
      expect(described_class.directory_size(File.join(temp_dir, "does-not-exist"))).to eq(0)
    end

    it "sums every regular file" do
      sub = File.join(cache_path, "languages", "en", "spelling")
      FileUtils.mkdir_p(sub)
      File.write(File.join(sub, "index.aff"), "x" * 100)
      File.write(File.join(sub, "index.dic"), "y" * 200)

      expect(described_class.directory_size(cache_path)).to eq(300)
    end
  end

  describe "#languages_with_model" do
    it "returns languages with model available" do
      resources = [
        described_class::ResourceStatus.new(language: "en", resource: :spelling, available: true),
        described_class::ResourceStatus.new(language: "en", resource: :model, available: true),
        described_class::ResourceStatus.new(language: "de", resource: :spelling, available: true),
        described_class::ResourceStatus.new(language: "de", resource: :model, available: false)
      ]
      report = described_class.new(
        version: "0.3.0", languages_setup: %w[en de], resources: resources,
        cache_path: "/tmp/x", cache_size_bytes: 0,
        audit_log_path: nil, audit_log_size_bytes: nil,
        onnx_loaded: false, default_language: "en", offline: false
      )

      expect(report.languages_with_model).to eq(%w[en])
    end
  end

  describe ".build with stubbed collaborators" do
    let(:fake_paths) do
      path_cache = cache_path
      path_audit = File.join(data_path, "audit.log")
      mod = Module.new
      mod.define_singleton_method(:cache_path) { path_cache }
      mod.define_singleton_method(:audit_log_path) { path_audit }
      mod
    end

    let(:fake_rm) do
      rm = Object.new
      def rm.languages_setup; %w[en]; end

      def rm.setup?(lang, resource: nil)
        lang == "en" && resource == :spelling
      end
      rm
    end

    let(:fake_config) do
      Struct.new(:default_language, :offline).new("en", false)
    end

    it "builds a report from injected collaborators without touching real state" do
      sub = File.join(cache_path, "languages", "en", "spelling")
      FileUtils.mkdir_p(sub)
      File.write(File.join(sub, "index.aff"), "x" * 100)

      report = described_class.build(
        version: "0.3.0",
        resource_manager: fake_rm,
        paths: fake_paths,
        configuration: fake_config,
        onnx_loaded: false
      )

      expect(report.version).to eq("0.3.0")
      expect(report.languages_setup).to eq(%w[en])
      expect(report.resources.length).to eq(3)
      spelling = report.resources.find { |r| r.resource == :spelling }
      expect(spelling.available).to be(true)
      expect(spelling.size_bytes).to eq(100)
      frequency = report.resources.find { |r| r.resource == :frequency }
      expect(frequency.available).to be(false)
      expect(frequency.size_bytes).to be_nil
      expect(report.cache_size_bytes).to eq(100)
      expect(report.onnx_loaded).to be(false)
      expect(report.default_language).to eq("en")
      expect(report.offline).to be(false)
    end

    it "returns nil audit_log_path when file does not exist" do
      report = described_class.build(
        version: "0.3.0",
        resource_manager: fake_rm,
        paths: fake_paths,
        configuration: fake_config,
        onnx_loaded: false
      )

      expect(report.audit_log_path).to be_nil
      expect(report.audit_log_size_bytes).to be_nil
    end

    it "reports audit log size when the file exists" do
      audit = File.join(data_path, "audit.log")
      File.write(audit, "x" * 250)

      report = described_class.build(
        version: "0.3.0",
        resource_manager: fake_rm,
        paths: fake_paths,
        configuration: fake_config,
        onnx_loaded: false
      )

      expect(report.audit_log_path).to eq(audit)
      expect(report.audit_log_size_bytes).to eq(250)
    end
  end
end
