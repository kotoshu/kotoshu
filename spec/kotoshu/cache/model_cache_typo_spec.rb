# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "digest"
require "json"

# Plan 131: the typo bi-encoder pair in ModelCache — resolved through
# the models registry exactly like the LID pair, plus the cache-only
# tier resolver the Typo::Engine resolve path uses (fixture-driven, no
# network, no doubles; the same style as model_cache_lid_spec.rb).
RSpec.describe Kotoshu::Cache::ModelCache do
  let(:temp_dir) { Dir.mktmpdir("kotoshu-model-typo") }
  let(:unreachable_registry) { Kotoshu::SourceRegistry.new(base_url: "http://127.0.0.1:9") }
  let(:audit_log) { Kotoshu::Integrity::AuditLog.new(path: File.join(temp_dir, "audit.log")) }
  let(:cache) do
    described_class.new(cache_path: temp_dir,
                        cache_ttl: 3600,
                        source_registry: unreachable_registry,
                        audit_log: audit_log)
  end

  let(:onnx_bytes) { ("fake-typo-biencoder-bytes" * 64).dup }
  let(:vocab_bytes) { '{"!": 1, "a": 2}'.dup }

  def seed_typo_cache
    dir = File.join(temp_dir, described_class::TYPO_DIRECTORY)
    FileUtils.mkdir_p(dir)
    File.binwrite(File.join(dir, "typo.biencoder.onnx"), onnx_bytes)
    File.binwrite(File.join(dir, "typo.biencoder.vocab.json"), vocab_bytes)
    File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                  "file" => "typo.biencoder.onnx", "vocab_file" => "typo.biencoder.vocab.json",
                                                  "checksum" => Digest::SHA256.hexdigest(onnx_bytes),
                                                  "registry_id" => described_class::TYPO_REGISTRY_ID,
                                                  "url" => "fixture", "cached_at" => Time.now.utc.iso8601
                                                ))
    dir
  end

  def seed_full_tier_cache(vocab: true)
    # :full maps to the untiered "{lang}:onnx" layout (the tier
    # resource id keeps full legacy-untiered)
    dir = File.join(temp_dir, "en", "models", "onnx")
    FileUtils.mkdir_p(dir)
    File.binwrite(File.join(dir, "fasttext.en.onnx"), "fake-full-tier")
    File.binwrite(File.join(dir, "fasttext.en.vocab.json"), "{}") if vocab
    File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                  "file" => "fasttext.en.onnx",
                                                  "vocab_file" => vocab ? "fasttext.en.vocab.json" : nil,
                                                  "checksum" => Digest::SHA256.hexdigest("fake-full-tier"),
                                                  "url" => "fixture", "cached_at" => Time.now.utc.iso8601
                                                ))
    dir
  end

  after { FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir) }

  describe "typo constants" do
    it "addresses the registry resource under the models root" do
      expect(described_class::TYPO_REGISTRY_ID).to eq("kotoshu://models/typo/typo-biencoder")
      expect(described_class::TYPO_DIRECTORY).to eq(File.join("models", "typo"))
    end
  end

  describe "#load_cached_typo_biencoder / #typo_biencoder_cached?" do
    it "answers nil / false when nothing is cached" do
      expect(cache.load_cached_typo_biencoder).to be_nil
      expect(cache.typo_biencoder_cached?).to be false
    end

    it "resolves the pair from the cache with metadata" do
      dir = seed_typo_cache
      pair = cache.load_cached_typo_biencoder
      expect(pair[:onnx_path]).to eq(File.join(dir, "typo.biencoder.onnx"))
      expect(pair[:vocab_path]).to eq(File.join(dir, "typo.biencoder.vocab.json"))
      expect(pair[:metadata]["registry_id"]).to eq("kotoshu://models/typo/typo-biencoder")
      expect(cache.typo_biencoder_cached?).to be true
    end

    it "answers nil when the vocab sidecar is missing" do
      dir = seed_typo_cache
      File.delete(File.join(dir, "typo.biencoder.vocab.json"))
      expect(cache.load_cached_typo_biencoder).to be_nil
    end

    it "raises IntegrityError when the cached onnx fails its checksum" do
      dir = seed_typo_cache
      File.binwrite(File.join(dir, "typo.biencoder.onnx"), "tampered" + onnx_bytes)
      expect { cache.load_cached_typo_biencoder }
        .to raise_error(Kotoshu::IntegrityError, /kotoshu:\/\/models\/typo\/typo-biencoder/)
    end
  end

  describe "#download_typo_biencoder" do
    def seed_registry_with_empty_resources
      seed_registry_contents(
        JSON.pretty_generate("spec" => "kotoshu.resources/v1",
                             "registry_version" => 1, "release_tag" => "v1.6.0",
                             "resources" => {})
      )
    end

    def seed_registry(vocab_url)
      payload = JSON.pretty_generate(
        "spec" => "kotoshu.resources/v1",
        "registry_version" => 1,
        "release_tag" => "v1.6.0",
        "resources" => {
          "kotoshu://models/typo/typo-biencoder" => {
            "type" => "model", "language" => "typo",
            "tier" => { "name" => "typo-biencoder", "dims" => 256,
                        "vocab_size" => 1821, "quantization" => "int8-dynamic" },
            "version" => "1.6.0",
            "urls" => { "primary" => "http://127.0.0.1:9/typo.onnx", "mirror" => nil },
            "vocab_url" => vocab_url, "sha256" => "0" * 64, "size_bytes" => 1,
            "license" => "CC-BY-SA-3.0", "min_engine_version" => "0.7", "eval_ref" => nil
          }
        }
      )
      seed_registry_contents(payload)
    end

    def seed_registry_contents(payload)
      dir = File.join(temp_dir, "registry")
      FileUtils.mkdir_p(dir)
      File.binwrite(File.join(dir, "registry.json"), payload)
      File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                    "url" => "#{unreachable_registry.base_url}/models-fasttext-onnx/main/registry.json",
                                                    "sha256" => Digest::SHA256.hexdigest(payload),
                                                    "cached_at" => Time.now.utc.iso8601
                                                  ))
    end

    it "raises the honest error for a pre-cut entry without vocab_url" do
      seed_registry("")
      expect { cache.download_typo_biencoder }
        .to raise_error(Kotoshu::Error, /carries no vocab_url yet/)
    end

    it "raises when the registry has no entry" do
      seed_registry_with_empty_resources
      expect { cache.download_typo_biencoder }
        .to raise_error(Kotoshu::Error, /no registry entry for kotoshu:\/\/models\/typo\/typo-biencoder/)
    end
  end

  describe "#load_cached_tier" do
    it "resolves the full tier with its vocab sibling" do
      seed_full_tier_cache
      tier = cache.load_cached_tier("en", :full)
      expect(tier[:model_path]).to end_with("fasttext.en.onnx")
      expect(tier[:vocab_path]).to end_with("fasttext.en.vocab.json")
    end

    it "omits vocab_path when the sibling is absent" do
      seed_full_tier_cache(vocab: false)
      tier = cache.load_cached_tier("en", :full)
      expect(tier[:model_path]).to end_with("fasttext.en.onnx")
      expect(tier).not_to have_key(:vocab_path)
    end

    it "answers nil when nothing is cached" do
      expect(cache.load_cached_tier("en", :full)).to be_nil
    end
  end
end
