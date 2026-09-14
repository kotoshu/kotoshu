# frozen_string_literal: true

require "spec_helper"
require_relative "../support/local_http_server"
require "fileutils"
require "tmpdir"
require "digest"
require "json"

# Plan 131: the typo-retrieval want item in ResourceManager#setup —
# the two-stage setup half (KOTOSHU_TYPO_RETRIEVAL resolves cache-only
# at suggest time). All specs run without network: caches are seeded
# on disk and the registry points at a closed port (the tier-spec
# style), so the pre-cut registry answers :unavailable and the cached
# halves answer :cached.
RSpec.describe Kotoshu::ResourceManager do
  let(:temp_cache_dir) { Dir.mktmpdir("kotoshu-rm-typo") }
  let(:fixture_registry_path) { File.expand_path("../fixtures/registry.json", __dir__) }

  before do
    Kotoshu::Configuration.reset
    Kotoshu::Configuration.instance.cache_path = temp_cache_dir
    Kotoshu::Configuration.instance.repos_base_url = "http://127.0.0.1:9"
  end

  after do
    FileUtils.rm_rf(temp_cache_dir)
    Kotoshu::Configuration.reset
  end

  def seed_registry_fixture
    dir = File.join(temp_cache_dir, "registry")
    FileUtils.mkdir_p(dir)
    bytes = File.read(fixture_registry_path)
    File.write(File.join(dir, "registry.json"), bytes)
    File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                  "url" => "http://127.0.0.1:9/registry.json",
                                                  "sha256" => Digest::SHA256.hexdigest(bytes),
                                                  "cached_at" => Time.now.utc.iso8601
                                                ))
  end

  def seed_typo_pair
    dir = File.join(temp_cache_dir, "models", "typo")
    FileUtils.mkdir_p(dir)
    bytes = "fake-typo-biencoder-bytes"
    File.binwrite(File.join(dir, "typo.biencoder.onnx"), bytes)
    File.binwrite(File.join(dir, "typo.biencoder.vocab.json"), "{}")
    File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                  "file" => "typo.biencoder.onnx", "vocab_file" => "typo.biencoder.vocab.json",
                                                  "checksum" => Digest::SHA256.hexdigest(bytes),
                                                  "registry_id" => "kotoshu://models/typo/typo-biencoder",
                                                  "url" => "fixture", "cached_at" => Time.now.utc.iso8601
                                                ))
  end

  def seed_full_tier(language = "en")
    dir = File.join(temp_cache_dir, language, "models", "onnx")
    FileUtils.mkdir_p(dir)
    bytes = "fake-full-tier"
    File.binwrite(File.join(dir, "fasttext.#{language}.onnx"), bytes)
    File.binwrite(File.join(dir, "fasttext.#{language}.vocab.json"), "{}")
    File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                  "file" => "fasttext.#{language}.onnx", "vocab_file" => "fasttext.#{language}.vocab.json",
                                                  "checksum" => Digest::SHA256.hexdigest(bytes),
                                                  "url" => "fixture", "cached_at" => Time.now.utc.iso8601
                                                ))
  end

  describe "#setup with want: [:typo]" do
    it "reports :cached when both halves are already present" do
      seed_typo_pair
      seed_full_tier
      result = described_class.setup("en", want: %i[typo])
      expect(result.typo).to eq(:cached)
    end

    it "reports :unavailable against a pre-cut registry" do
      seed_registry_fixture
      result = described_class.setup("en", want: %i[typo])
      expect(result.typo).to eq(:unavailable)
    end

    it "raises under strict against a pre-cut registry" do
      seed_registry_fixture
      expect { described_class.setup("en", want: %i[typo], strict: true) }
        .to raise_error(Kotoshu::Error, /typo|registry/i)
    end

    it "leaves the other wants untouched" do
      seed_registry_fixture
      seed_typo_pair
      seed_full_tier
      # spelling: against the closed port the dictionary download
      # fails and setup raises for it; run typo-only concerns through
      # the model+typo combination instead
      result = described_class.setup("en", want: %i[model typo], tier: :full)
      expect(result.typo).to eq(:cached)
    end
  end

  describe "#setup with want: [:typo] matrix backfill (plan 136)" do
    # An install set up before the prebuilt matrix existed (or a fresh
    # one, for a language that gained one) must pick the matrix up on
    # the next setup run — otherwise arming derives (~25s) forever.
    def seed_registry_with_matrix_entry(matrix_bytes:, mirror_url:)
      payload = JSON.pretty_generate(
        "spec" => "kotoshu.resources/v1", "registry_version" => 2,
        "release_tag" => "v1.7.0",
        "resources" => {
          "kotoshu://models/en/typo-matrix" => {
            "type" => "model", "language" => "en",
            "tier" => { "name" => "typo-matrix", "dims" => 256,
                        "vocab_size" => 10, "quantization" => "int8-per-row" },
            "version" => "1.7.0",
            "urls" => { "primary" => nil, "mirror" => mirror_url },
            "vocab_url" => nil,
            "sha256" => Digest::SHA256.hexdigest(matrix_bytes),
            "size_bytes" => matrix_bytes.bytesize,
            "license" => "CC-BY-SA-3.0", "min_engine_version" => "1.1",
            "eval_ref" => nil
          }
        }
      )
      dir = File.join(temp_cache_dir, "registry")
      FileUtils.mkdir_p(dir)
      File.binwrite(File.join(dir, "registry.json"), payload)
      File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                    "url" => "fixture", "sha256" => Digest::SHA256.hexdigest(payload),
                                                    "cached_at" => Time.now.utc.iso8601
                                                  ))
    end

    def matrix_cache_path
      File.join(temp_cache_dir, "en", "models", "typo-matrix", "typo.matrix.en.ktm1")
    end

    it "backfills a missing matrix on an already-satisfied setup" do
      server_root = File.join(temp_cache_dir, "server")
      FileUtils.mkdir_p(server_root)
      bytes = "KTM1" + ("\0" * 12)
      File.binwrite(File.join(server_root, "typo.matrix.en.ktm1"), bytes)
      server = LocalHttpServer.new(root: server_root)
      begin
        seed_typo_pair
        seed_full_tier
        seed_registry_with_matrix_entry(matrix_bytes: bytes, mirror_url: "#{server.base_url}/typo.matrix.en.ktm1")

        result = described_class.setup("en", want: %i[typo])

        expect(result.typo).to eq(:downloaded)
        expect(File.binread(matrix_cache_path)).to eq(bytes)
      ensure
        server.stop
      end
    end

    it "stays :cached when the matrix is already present" do
      seed_typo_pair
      seed_full_tier
      bytes = "KTM1" + ("\0" * 12)
      FileUtils.mkdir_p(File.dirname(matrix_cache_path))
      File.binwrite(matrix_cache_path, bytes)
      seed_registry_with_matrix_entry(matrix_bytes: bytes, mirror_url: "http://127.0.0.1:9/typo.matrix.en.ktm1")

      result = described_class.setup("en", want: %i[typo])

      expect(result.typo).to eq(:cached)
    end

    it "degrades to :cached when the registry has no matrix entry" do
      seed_typo_pair
      seed_full_tier
      seed_registry_fixture

      result = described_class.setup("en", want: %i[typo])

      expect(result.typo).to eq(:cached)
      expect(File.exist?(matrix_cache_path)).to be(false)
    end
  end

  describe ".setup? with resource: :typo" do
    it "is false with nothing cached" do
      expect(described_class.setup?("en", resource: :typo)).to be(false)
    end

    it "is false with only the pair cached (the full tier is the other half)" do
      seed_typo_pair
      expect(described_class.setup?("en", resource: :typo)).to be(false)
    end

    it "is true with both halves cached" do
      seed_typo_pair
      seed_full_tier
      expect(described_class.setup?("en", resource: :typo)).to be(true)
    end
  end
end
