# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/local_http_server"
require "fileutils"
require "tmpdir"
require "digest"
require "json"

# Plan 106: the LID artifact pair in ModelCache —
# kotoshu://models/lid/lid-176 resolved through the models registry.
#
# Same fixture- and localhost-server-driven style as the tier specs
# (model_cache_tier_spec.rb): the REAL Net::HTTP download path against
# a real socket, offline behavior through the global configuration
# flag, and no test doubles.
RSpec.describe Kotoshu::Cache::ModelCache do
  let(:temp_dir) { Dir.mktmpdir("kotoshu-model-lid") }
  # Port 9 (discard) is closed on this host: any accidental fetch fails
  # fast with ECONNREFUSED, proving specs never touch the network.
  let(:unreachable_registry) { Kotoshu::SourceRegistry.new(base_url: "http://127.0.0.1:9") }
  let(:audit_log) { Kotoshu::Integrity::AuditLog.new(path: File.join(temp_dir, "audit.log")) }
  let(:cache) do
    described_class.new(cache_path: temp_dir,
                        cache_ttl: 3600,
                        source_registry: unreachable_registry,
                        audit_log: audit_log)
  end

  let(:onnx_bytes) { ("fake-lid-onnx-model-bytes" * 64).dup }
  let(:vocab_bytes) { '{"labels": ["en"], "counts": [1]}'.dup }

  def seed_cached_registry(json:)
    dir = File.join(temp_dir, "registry")
    FileUtils.mkdir_p(dir)
    File.binwrite(File.join(dir, "registry.json"), json)
    File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                  "url" => "#{unreachable_registry.base_url}/models-fasttext-onnx/main/registry.json",
                                                  "sha256" => Digest::SHA256.hexdigest(json),
                                                  "cached_at" => Time.now.utc.iso8601
                                                ))
  end

  def lid_registry_without_entry
    JSON.pretty_generate(
      "spec" => "kotoshu.resources/v1",
      "registry_version" => 1,
      "release_tag" => "v1.4.0",
      "resources" => {
        "kotoshu://models/en/mini" => {
          "type" => "model", "language" => "en",
          "tier" => { "name" => "mini", "dims" => 300, "vocab_size" => 10_000,
                      "quantization" => "int8-per-row" },
          "version" => "1.4.0",
          "urls" => { "primary" => "http://127.0.0.1:9/en.onnx", "mirror" => nil },
          "vocab_url" => "", "sha256" => "0" * 64, "size_bytes" => 1,
          "license" => "CC-BY-SA-3.0", "min_engine_version" => "0.7", "eval_ref" => nil
        }
      }
    )
  end

  after do
    FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
    Kotoshu::Configuration.reset
  end

  describe "lid constants" do
    it "addresses the registry resource and a top-level cache directory" do
      expect(described_class::LID_REGISTRY_ID).to eq("kotoshu://models/lid/lid-176")
      expect(described_class::LID_DIRECTORY).to eq("lid")
    end
  end

  describe "#load_cached_lid / #lid_cached?" do
    it "answers nil / false when nothing is cached" do
      expect(cache.load_cached_lid).to be_nil
      expect(cache.lid_cached?).to be false
    end

    it "resolves the pair from the cache with metadata" do
      dir = File.join(temp_dir, "lid")
      FileUtils.mkdir_p(dir)
      File.binwrite(File.join(dir, "lid.176.onnx"), onnx_bytes)
      File.binwrite(File.join(dir, "lid.176.vocab.json"), vocab_bytes)
      File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                    "file" => "lid.176.onnx", "vocab_file" => "lid.176.vocab.json",
                                                    "checksum" => Digest::SHA256.hexdigest(onnx_bytes),
                                                    "registry_id" => described_class::LID_REGISTRY_ID,
                                                    "url" => "fixture", "cached_at" => Time.now.utc.iso8601
                                                  ))

      pair = cache.load_cached_lid

      expect(pair[:onnx_path]).to eq(File.join(dir, "lid.176.onnx"))
      expect(pair[:vocab_path]).to eq(File.join(dir, "lid.176.vocab.json"))
      expect(pair[:metadata]["registry_id"]).to eq("kotoshu://models/lid/lid-176")
      expect(cache.lid_cached?).to be true
    end

    it "answers nil when the vocab sidecar is missing" do
      dir = File.join(temp_dir, "lid")
      FileUtils.mkdir_p(dir)
      File.binwrite(File.join(dir, "lid.176.onnx"), onnx_bytes)
      File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                    "file" => "lid.176.onnx", "vocab_file" => "lid.176.vocab.json",
                                                    "checksum" => Digest::SHA256.hexdigest(onnx_bytes),
                                                    "url" => "fixture", "cached_at" => Time.now.utc.iso8601
                                                  ))

      expect(cache.load_cached_lid).to be_nil
      expect(cache.lid_cached?).to be false
    end

    it "raises IntegrityError when the cached onnx fails its checksum" do
      dir = File.join(temp_dir, "lid")
      FileUtils.mkdir_p(dir)
      File.binwrite(File.join(dir, "lid.176.onnx"), "tampered" + onnx_bytes)
      File.binwrite(File.join(dir, "lid.176.vocab.json"), vocab_bytes)
      File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                    "file" => "lid.176.onnx", "vocab_file" => "lid.176.vocab.json",
                                                    "checksum" => Digest::SHA256.hexdigest(onnx_bytes),
                                                    "url" => "fixture", "cached_at" => Time.now.utc.iso8601
                                                  ))

      expect { cache.load_cached_lid }
        .to raise_error(Kotoshu::IntegrityError, /kotoshu:\/\/models\/lid\/lid-176/)
    end

    it "refuses a Git LFS pointer stub and purges the pair" do
      stub = "version https://git-lfs.github.com/spec/v1\noid sha256:#{'0' * 64}\n"
      dir = File.join(temp_dir, "lid")
      FileUtils.mkdir_p(dir)
      File.binwrite(File.join(dir, "lid.176.onnx"), stub)
      File.binwrite(File.join(dir, "lid.176.vocab.json"), vocab_bytes)
      File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                    "file" => "lid.176.onnx", "vocab_file" => "lid.176.vocab.json",
                                                    "checksum" => Digest::SHA256.hexdigest(stub),
                                                    "url" => "fixture", "cached_at" => Time.now.utc.iso8601
                                                  ))

      expect { cache.load_cached_lid }.to raise_error(Kotoshu::Error, /LFS pointer stub/)
      expect(File.exist?(File.join(dir, "lid.176.onnx"))).to be false
      expect(File.exist?(File.join(dir, "lid.176.vocab.json"))).to be false
    end

    it "keeps the lid directory out of the per-language resource listing" do
      dir = File.join(temp_dir, "lid")
      FileUtils.mkdir_p(dir)
      File.binwrite(File.join(dir, "lid.176.onnx"), onnx_bytes)
      File.binwrite(File.join(dir, "lid.176.vocab.json"), vocab_bytes)
      File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                    "file" => "lid.176.onnx", "vocab_file" => "lid.176.vocab.json",
                                                    "checksum" => Digest::SHA256.hexdigest(onnx_bytes),
                                                    "url" => "fixture", "cached_at" => Time.now.utc.iso8601
                                                  ))

      expect(cache.cached_resources).to be_empty
    end
  end

  describe "#download_lid" do
    it "raises (never fetches) when offline with no cached registry" do
      Kotoshu::Configuration.instance.offline = true

      expect { cache.download_lid }.to raise_error(Kotoshu::Error, /offline mode.*no cached registry/)
    end

    it "reuses a cached registry in offline mode" do
      Kotoshu::Configuration.instance.offline = true
      seed_cached_registry(json: lid_registry_without_entry)

      expect { cache.download_lid }
        .to raise_error(Kotoshu::Error, /no registry entry for kotoshu:\/\/models\/lid\/lid-176/)
    end

    it "raises when the registry carries no lid entry" do
      seed_cached_registry(json: lid_registry_without_entry)

      expect { cache.download_lid }
        .to raise_error(Kotoshu::Error, /no registry entry for kotoshu:\/\/models\/lid\/lid-176/)
    end

    context "with a local server", :local_server do
      let(:server_dir) { File.join(temp_dir, "server-root") }
      let!(:server) { LocalHttpServer.new(root: server_dir) }
      let(:live_cache) do
        described_class.new(cache_path: File.join(temp_dir, "live"),
                            cache_ttl: 3600,
                            source_registry: Kotoshu::SourceRegistry.new(base_url: server.base_url),
                            audit_log: audit_log)
      end

      let(:registry_json) do
        JSON.pretty_generate(
          "spec" => "kotoshu.resources/v1",
          "registry_version" => 1,
          "generated_at" => "2026-09-07T00:00:00Z",
          "release_tag" => "v1.4.0",
          "resources" => {
            described_class::LID_REGISTRY_ID => {
              "type" => "model",
              "language" => "lid",
              "tier" => { "name" => "lid-176", "dims" => 16, "vocab_size" => 50_000,
                          "quantization" => "int8-per-row" },
              "version" => "1.4.0",
              "urls" => {
                "primary" => "#{server.base_url}/releases/lid.176.onnx",
                "mirror" => "#{server.base_url}/mirror/lid.176.onnx"
              },
              "vocab_url" => "#{server.base_url}/releases/lid.176.vocab.json",
              "sha256" => Digest::SHA256.hexdigest(onnx_bytes),
              "size_bytes" => onnx_bytes.bytesize,
              "license" => "MIT",
              "min_engine_version" => "0.3",
              "eval_ref" => "eval/reports/lid.176.json"
            }
          }
        )
      end

      before do
        releases = File.join(server_dir, "releases")
        mirror = File.join(server_dir, "mirror")
        registry_tree = File.join(server_dir, "models-fasttext-onnx", "main")
        FileUtils.mkdir_p([releases, mirror, registry_tree])
        File.binwrite(File.join(mirror, "lid.176.onnx"), onnx_bytes)
        File.binwrite(File.join(releases, "lid.176.vocab.json"), vocab_bytes)
        File.binwrite(File.join(registry_tree, "registry.json"), registry_json)
      end

      it "downloads primary, verifies sha256, requires the vocab, and writes metadata" do
        # Primary deliberately absent: the mirror serves the bytes, so
        # the fallback path is exercised like the tier specs do.
        pair = live_cache.download_lid

        expect(File.binread(pair[:onnx_path])).to eq(onnx_bytes)
        expect(File.binread(pair[:vocab_path])).to eq(vocab_bytes)
        expect(pair[:metadata][:registry_id]).to eq(described_class::LID_REGISTRY_ID)
        expect(pair[:metadata][:checksum]).to eq(Digest::SHA256.hexdigest(onnx_bytes))
        expect(live_cache.lid_cached?).to be true
        expect(live_cache.load_cached_lid[:onnx_path]).to eq(pair[:onnx_path])
      end

      it "fails the download when the bytes do not match the registry sha256" do
        File.binwrite(File.join(server_dir, "releases", "lid.176.onnx"), "wrong bytes")
        File.delete(File.join(server_dir, "mirror", "lid.176.onnx"))

        expect { live_cache.download_lid }.to raise_error(Kotoshu::IntegrityError)
        expect(File.exist?(File.join(temp_dir, "live", "lid", "lid.176.onnx"))).to be false
      end

      it "raises when the vocab sidecar cannot be fetched" do
        File.delete(File.join(server_dir, "releases", "lid.176.vocab.json"))
        File.binwrite(File.join(server_dir, "releases", "lid.176.onnx"), onnx_bytes)

        expect { live_cache.download_lid }.to raise_error(Kotoshu::Error, /LID vocab unavailable/)
        expect(File.exist?(File.join(temp_dir, "live", "lid", "lid.176.onnx"))).to be false
      end
    end
  end
end
