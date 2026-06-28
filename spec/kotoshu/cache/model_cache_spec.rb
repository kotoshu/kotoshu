# frozen_string_literal: true

require_relative "../../../lib/kotoshu/cache/model_cache"
require "fileutils"
require "tmpdir"
require "digest"

# Phase C of TODO.impl/38-onnx-semantic-gating.md
#
# These specs pin the model-cache integrity contract: a cached model
# file whose SHA-256 no longer matches the checksum recorded at
# download time is rejected at load with a clear, actionable error
# pointing the user at the cache subcommand. They run in the
# always-run suite (no :onnx, no :network tag) because they exercise
# the load path against locally-seeded cache files — no real download.
RSpec.describe Kotoshu::Cache::ModelCache do
  let(:temp_dir) { Dir.mktmpdir }
  let(:cache) { described_class.new(cache_path: temp_dir, cache_ttl: 3600) }

  let(:language) { "en" }
  let(:type) { "onnx" }
  let(:resource_id) { "#{language}:#{type}" }
  let(:model_dir) { File.join(temp_dir, language, "models", type) }
  let(:model_filename) { "fasttext.#{language}.onnx" }
  let(:model_path) { File.join(model_dir, model_filename) }
  let(:metadata_path) { File.join(model_dir, "metadata.json") }
  let(:model_bytes) { ("onnx-model-bytes" * 100).dup }

  after do
    FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
  end

  def write_cached_model(checksum: Digest::SHA256.hexdigest(model_bytes))
    FileUtils.mkdir_p(model_dir)
    File.write(model_path, model_bytes, mode: "wb")
    File.write(metadata_path, JSON.pretty_generate(
                                "version" => Time.now.utc.iso8601,
                                "url" => "https://example.test/#{model_filename}",
                                "language" => language,
                                "type" => type,
                                "file" => model_filename,
                                "checksum" => checksum,
                                "cached_at" => Time.now.utc.iso8601
                              ))
  end

  describe "#get integrity verification on cache hit" do
    it "returns the model path when the checksum matches" do
      write_cached_model
      result = cache.get(resource_id)
      expect(result).to be_a(Hash)
      expect(result[:model_path]).to eq(model_path)
    end

    it "raises IntegrityError when the cached file is truncated" do
      write_cached_model
      # Truncate the file so its checksum no longer matches
      File.write(model_path, "corrupted-bytes", mode: "wb")

      expect { cache.get(resource_id) }
        .to raise_error(Kotoshu::IntegrityError, /Integrity verification failed for #{resource_id}/)
    end

    it "points the user at the cache download subcommand in the remediation hint" do
      write_cached_model
      File.write(model_path, "different-bytes", mode: "wb")

      error = nil
      begin
        cache.get(resource_id)
      rescue Kotoshu::IntegrityError => e
        error = e
      end

      expect(error.message).to include("kotoshu cache download :#{language} --model")
      expect(error.remediation).to include("kotoshu cache download")
    end

    it "exposes expected and actual checksums on the error" do
      write_cached_model
      File.write(model_path, "tampered", mode: "wb")

      error = nil
      begin
        cache.get(resource_id)
      rescue Kotoshu::IntegrityError => e
        error = e
      end

      expected = Digest::SHA256.hexdigest(model_bytes)
      actual = Digest::SHA256.hexdigest("tampered")
      expect(error.expected).to eq(expected)
      expect(error.actual).to eq(actual)
    end

    it "accepts a legacy cache whose metadata has no checksum field (graceful degradation)" do
      FileUtils.mkdir_p(model_dir)
      File.write(model_path, model_bytes, mode: "wb")
      File.write(metadata_path, JSON.pretty_generate(
                                  "version" => Time.now.utc.iso8601,
                                  "cached_at" => Time.now.utc.iso8601
                                  # No "checksum" key — pre-verification cache
                                ))

      expect { cache.get(resource_id) }.not_to raise_error
    end

    it "returns nil when the resource is not in AVAILABLE_MODELS" do
      expect(cache.get("xx:onnx")).to be_nil
    end
  end
end

RSpec.describe Kotoshu::IntegrityError do
  it "omits the remediation line when not provided (backward compat)" do
    error = described_class.new("en:onnx",
                                expected: "aaa",
                                actual: "bbb")
    expect(error.message).to eq("Integrity verification failed for en:onnx: expected sha256=aaa, got sha256=bbb")
    expect(error.remediation).to be_nil
  end

  it "appends the remediation hint when provided" do
    error = described_class.new("en:onnx",
                                expected: "aaa",
                                actual: "bbb",
                                url: "https://example.test/file",
                                remediation: "Run `kotoshu cache download :en --model`.")
    expect(error.message).to include("Run `kotoshu cache download :en --model`.")
    expect(error.message).to include("(url: https://example.test/file)")
    expect(error.remediation).to eq("Run `kotoshu cache download :en --model`.")
  end

  it "exposes url and remediation readers" do
    error = described_class.new("en:onnx",
                                expected: "aaa",
                                actual: "bbb",
                                url: "https://example.test/file",
                                remediation: "hint")
    expect(error.url).to eq("https://example.test/file")
    expect(error.remediation).to eq("hint")
  end
end
