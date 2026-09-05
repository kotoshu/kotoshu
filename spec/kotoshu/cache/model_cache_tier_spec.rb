# frozen_string_literal: true

require "spec_helper"
require_relative "../../support/local_http_server"
require "fileutils"
require "tmpdir"
require "digest"
require "json"

# Plan 67 M1: tier-aware ModelCache. These specs are fixture- and
# localhost-server-driven — no external network, no test doubles:
#
# - tier -> resource id -> on-disk path mapping (full keeps the legacy
#   layout; fluency/mini nest beside it so tiers coexist)
# - registry.json is cached under the cache dir with its own sha-verified
#   storage and reused; offline mode never fetches
# - tiered downloads go primary -> mirror, verify sha256 against the
#   registry entry, and remove corrupt bytes before raising
RSpec.describe Kotoshu::Cache::ModelCache do
  let(:temp_dir) { Dir.mktmpdir("kotoshu-model-tier") }
  # Port 9 (discard) is closed on this host: any accidental fetch fails
  # fast with ECONNREFUSED, proving specs never touch the network.
  let(:unreachable_registry) do
    Kotoshu::SourceRegistry.new(base_url: "http://127.0.0.1:9")
  end
  let(:audit_log) do
    Kotoshu::Integrity::AuditLog.new(path: File.join(temp_dir, "audit.log"))
  end
  let(:cache) do
    described_class.new(cache_path: temp_dir,
                        cache_ttl: 3600,
                        source_registry: unreachable_registry,
                        audit_log: audit_log)
  end
  let(:fixture_json) do
    File.read(File.expand_path("../../fixtures/registry.json", __dir__))
  end

  def seed_cached_registry(json: fixture_json)
    dir = File.join(temp_dir, "registry")
    FileUtils.mkdir_p(dir)
    File.binwrite(File.join(dir, "registry.json"), json)
    File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                  "url" => "#{unreachable_registry.base_url}/models-fasttext-onnx/main/registry.json",
                                                  "sha256" => Digest::SHA256.hexdigest(json),
                                                  "cached_at" => Time.now.utc.iso8601
                                                ))
  end

  def seed_metadata(dir, extra_fields = {})
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, "metadata.json"),
               JSON.pretty_generate({ "cached_at" => Time.now.utc.iso8601 }.merge(extra_fields)))
  end

  after do
    FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir)
    Kotoshu::Configuration.reset
  end

  describe ".normalize_tier" do
    it "accepts symbols and strings, case-insensitively" do
      expect(described_class.normalize_tier(:mini)).to eq(:mini)
      expect(described_class.normalize_tier("Fluency")).to eq(:fluency)
      expect(described_class.normalize_tier("full")).to eq(:full)
    end

    it "raises ArgumentError listing valid tiers for anything else" do
      expect { described_class.normalize_tier("huge") }
        .to raise_error(ArgumentError, /unknown model tier "huge".*full, fluency, mini/)
    end
  end

  describe "tier -> resource id -> path mapping" do
    def seed_model_dir(dir, filename)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, filename), "model-bytes", mode: "wb")
      seed_metadata(dir, "file" => filename)
    end

    it "maps :full to the legacy id and directory (backwards compat)" do
      expect(cache.tier_resource_id("en", :full)).to eq("en:onnx")

      # Legacy layout: {lang}/models/onnx — unchanged from pre-tier days
      seed_model_dir(File.join(temp_dir, "en", "models", "onnx"), "fasttext.en.onnx")
      expect(cache.available?("en:onnx")).to be(true)
    end

    it "maps :mini and :fluency to tiered ids and sibling directories" do
      expect(cache.tier_resource_id("en", :mini)).to eq("en:onnx:mini")

      # Tiered layout nests beside the full tier so they coexist
      %w[mini fluency].each do |tier|
        seed_model_dir(File.join(temp_dir, "en", "models", "onnx", tier),
                       "fasttext.en.#{tier}.onnx")
        expect(cache.available?("en:onnx:#{tier}")).to be(true)
      end
    end

    it "recognizes tiered ids in supports_resource? and rejects bogus tiers" do
      expect(cache.supports_resource?("en:onnx:mini")).to be(true)
      expect(cache.supports_resource?("en:onnx:huge")).to be(false)
      expect(cache.supports_resource?("en:onnx")).to be(true)
    end

    it "reports the tier of a tiered id" do
      expect(cache.tier_from_resource_id("en:onnx:mini")).to eq(:mini)
      expect(cache.tier_from_resource_id("en:onnx")).to be_nil
    end
  end

  describe "#cached_tiers" do
    it "returns an empty list when nothing is cached" do
      expect(cache.cached_tiers("en")).to eq([])
    end

    it "counts the legacy directory as :full" do
      seed_metadata(File.join(temp_dir, "en", "models", "onnx"))
      expect(cache.cached_tiers("en")).to eq([:full])
    end

    it "lists coexisting tiers in preference order (mini first)" do
      seed_metadata(File.join(temp_dir, "en", "models", "onnx"))
      seed_metadata(File.join(temp_dir, "en", "models", "onnx", "fluency"))
      seed_metadata(File.join(temp_dir, "en", "models", "onnx", "mini"))
      expect(cache.cached_tiers("en")).to eq(%i[mini fluency full])
    end
  end

  describe "#cached_resources" do
    it "lists tiered and legacy entries without the registry storage" do
      seed_metadata(File.join(temp_dir, "en", "models", "onnx"))
      seed_metadata(File.join(temp_dir, "en", "models", "onnx", "mini"))
      seed_cached_registry

      expect(cache.cached_resources).to contain_exactly("en:onnx", "en:onnx:mini")
    end
  end

  describe "registry storage" do
    it "reuses a cached registry without fetching (unreachable URL would raise)" do
      seed_cached_registry

      entry = cache.registry_entry_for("en", :mini)
      expect(entry).to be_a(Kotoshu::Cache::ModelRegistry::Resource)
      expect(entry.tier.name).to eq("mini")
      expect(entry.sha256).to match(/\A[0-9a-f]{64}\z/)
    end

    it "downloads and stores the registry once, then reuses it" do
      server_dir = File.join(temp_dir, "server-root")
      FileUtils.mkdir_p(File.join(server_dir, "models-fasttext-onnx", "main"))
      File.binwrite(File.join(server_dir, "models-fasttext-onnx", "main", "registry.json"), fixture_json)
      server = LocalHttpServer.new(root: server_dir)
      live_cache = described_class.new(
        cache_path: temp_dir, cache_ttl: 3600,
        source_registry: Kotoshu::SourceRegistry.new(
          base_url: server.base_url,
          pins: { "models-fasttext-onnx" => "main" }
        ),
        audit_log: audit_log
      )

      entry = live_cache.registry_entry_for("de", :fluency)
      expect(entry.tier.name).to eq("fluency")

      # Stored with its own sha-verified metadata
      expect(File.exist?(File.join(temp_dir, "registry", "registry.json"))).to be(true)
      metadata = JSON.parse(File.read(File.join(temp_dir, "registry", "metadata.json")))
      expect(metadata["sha256"]).to eq(Digest::SHA256.hexdigest(fixture_json))

      # Stopping the server proves the second lookup is served from disk
      server.stop
      again = live_cache.registry_entry_for("de", :fluency)
      expect(again.sha256).to eq(entry.sha256)
    end

    it "raises (never fetches) when offline with no cached registry" do
      Kotoshu::Configuration.instance.offline = true

      expect { cache.registry_entry_for("en", :mini) }
        .to raise_error(Kotoshu::Error, /offline mode.*no cached registry/)
    end

    it "reuses a cached registry in offline mode" do
      Kotoshu::Configuration.instance.offline = true
      seed_cached_registry

      expect(cache.registry_entry_for("en", :fluency).tier.name).to eq("fluency")
    end

    it "refuses to trust a cached registry whose bytes fail the recorded sha" do
      seed_cached_registry
      File.write(File.join(temp_dir, "registry", "registry.json"), "{\"tampered\": true}")

      expect { cache.registry_entry_for("en", :mini) }.to raise_error(StandardError)
    end

    it "returns nil for a pair the registry does not know" do
      seed_cached_registry

      expect(cache.registry_entry_for("xx", :mini)).to be_nil
    end
  end

  describe "#download_tiered_model", :local_server do
    let(:server_dir) { File.join(temp_dir, "server-root") }
    let!(:server) { LocalHttpServer.new(root: server_dir) }
    let(:model_bytes) { ("fake-onnx-mini-model-bytes" * 50).dup }
    let(:vocab_bytes) { '{"hello": 0, "world": 1}'.dup }
    let(:registry_for_server) do
      {
        "spec" => "kotoshu.resources/v1",
        "registry_version" => 1,
        "release_tag" => "v1.0.0",
        "resources" => {
          "kotoshu://models/en/mini" => {
            "type" => "model",
            "language" => "en",
            "tier" => { "name" => "mini", "dims" => 300, "vocab_size" => 10_000, "quantization" => "int8-per-row" },
            "version" => "1.0.0",
            "urls" => {
              "primary" => "#{server.base_url}/releases/fasttext.en.mini.onnx",
              "mirror" => "#{server.base_url}/mirror/fasttext.en.mini.onnx"
            },
            "vocab_url" => "#{server.base_url}/releases/fasttext.en.mini.vocab.json",
            "sha256" => Digest::SHA256.hexdigest(model_bytes),
            "size_bytes" => model_bytes.bytesize,
            "license" => "CC-BY-SA-3.0",
            "min_engine_version" => "0.7",
            "eval_ref" => nil
          }
        }
      }.to_json
    end

    def live_cache
      described_class.new(
        cache_path: temp_dir, cache_ttl: 3600,
        source_registry: Kotoshu::SourceRegistry.new(base_url: server.base_url),
        audit_log: audit_log
      )
    end

    def write_server_file(relative, bytes)
      path = File.join(server_dir, relative)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, bytes, mode: "wb")
    end

    before do
      FileUtils.mkdir_p(server_dir)
      write_server_file("models-fasttext-onnx/main/registry.json", registry_for_server)
      write_server_file("releases/fasttext.en.mini.onnx", model_bytes)
      write_server_file("releases/fasttext.en.mini.vocab.json", vocab_bytes)
      seed_cached_registry(json: registry_for_server)
    end

    after { server.stop }

    it "downloads, verifies, and stores the model + vocab under the tier path" do
      result = cache.download_tiered_model("en", tier: :mini)

      tier_dir = File.join(temp_dir, "en", "models", "onnx", "mini")
      expect(result[:model_path]).to eq(File.join(tier_dir, "fasttext.en.mini.onnx"))
      expect(File.binread(result[:model_path])).to eq(model_bytes)
      expect(File.binread(result[:vocab_path])).to eq(vocab_bytes)

      metadata = result[:metadata]
      expect(metadata[:tier]).to eq("mini")
      expect(metadata[:checksum]).to eq(Digest::SHA256.hexdigest(model_bytes))
      expect(metadata[:registry_id]).to eq("kotoshu://models/en/mini")
      expect(metadata[:language]).to eq("en")

      # The download is audited as verified against the registry sha
      audit = File.readlines(audit_log.path).map { |l| JSON.parse(l) }
      expect(audit.last["status"]).to eq("verified")
      expect(audit.last["manifest_sha256"]).to eq(Digest::SHA256.hexdigest(model_bytes))

      # And a subsequent cache hit loads the verified tier
      hit = cache.get("en:onnx:mini")
      expect(hit[:model_path]).to eq(result[:model_path])
      expect(hit[:metadata]["tier"]).to eq("mini")
      expect(cache.available?("en:onnx:mini")).to be(true)
    end

    it "falls back to the mirror when the primary 404s" do
      # Remove the primary asset; the mirror copy serves the same bytes
      File.delete(File.join(server_dir, "releases", "fasttext.en.mini.onnx"))
      write_server_file("mirror/fasttext.en.mini.onnx", model_bytes)

      result = cache.download_tiered_model("en", tier: :mini)

      expect(File.binread(result[:model_path])).to eq(model_bytes)
      expect(result[:metadata][:url]).to eq("#{server.base_url}/mirror/fasttext.en.mini.onnx")
    end

    it "raises and removes corrupt bytes when the sha256 does not match the registry" do
      write_server_file("releases/fasttext.en.mini.onnx", "tampered-bytes-not-in-registry")

      model_path = File.join(temp_dir, "en", "models", "onnx", "mini", "fasttext.en.mini.onnx")
      expect { cache.download_tiered_model("en", tier: :mini) }
        .to raise_error(Kotoshu::IntegrityError, /en:onnx:mini/) do |error|
          expect(error.expected).to eq(Digest::SHA256.hexdigest(model_bytes))
          expect(error.actual).to eq(Digest::SHA256.hexdigest("tampered-bytes-not-in-registry"))
        end
      expect(File.exist?(model_path)).to be(false)

      audit = File.readlines(audit_log.path).map { |l| JSON.parse(l) }
      expect(audit.last["status"]).to eq("mismatch")
    end

    it "raises when the registry has no entry for the pair" do
      expect { cache.download_tiered_model("xx", tier: :mini) }
        .to raise_error(Kotoshu::Error, /no registry entry for kotoshu:\/\/models\/xx\/mini/)
    end

    it "leaves no partial file behind when both primary and mirror fail" do
      File.delete(File.join(server_dir, "releases", "fasttext.en.mini.onnx"))
      registry_without_mirror = JSON.parse(registry_for_server)
      registry_without_mirror["resources"]["kotoshu://models/en/mini"]["urls"]["mirror"] =
        "#{server.base_url}/nowhere/fasttext.en.mini.onnx"
      seed_cached_registry(json: JSON.generate(registry_without_mirror))

      expect { cache.download_tiered_model("en", tier: :mini) }.to raise_error(StandardError)

      tier_dir = File.join(temp_dir, "en", "models", "onnx", "mini")
      expect(Dir.children(tier_dir)).to be_empty
    end
  end

  # Opt-in (NETWORK_TESTS=1): pins the contract with the LIVE registry
  # and the v1.0.0 release assets. Everything above runs without any
  # network; this one is the real-world smoke test.
  describe "live registry end-to-end", :network do
    it "downloads the en mini tier from the real registry and verifies its sha" do
      live_cache = described_class.new(
        cache_path: temp_dir, cache_ttl: 3600,
        audit_log: Kotoshu::Integrity::AuditLog.new(path: File.join(temp_dir, "audit.log"))
      )

      result = live_cache.download_tiered_model("en", tier: :mini)

      entry = live_cache.registry_entry_for("en", :mini)
      expect(Digest::SHA256.file(result[:model_path]).hexdigest).to eq(entry.sha256)
      expect(File.size(result[:model_path])).to eq(entry.size_bytes)
      expect(live_cache.available?("en:onnx:mini")).to be(true)
      expect(live_cache.cached_tiers("en")).to eq([:mini])
    end
  end
end
