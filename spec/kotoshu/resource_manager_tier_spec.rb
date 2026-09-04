# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "digest"
require "json"

# Plan 67 M1: tier semantics on the two-stage resource model.
#
# - setup accepts tier:, reports it on SetupResult, and short-circuits
#   to :cached before any registry consultation
# - setup? accepts tier:
# - resolve stays cache-only: the bundle's model reflects the requested
#   tier, a missing tier raises ResourceNotSetupError exactly like
#   today (message names the tier), and only an explicit tier: :any
#   maps to "the single cached tier" — raising on zero or many
#
# All of these run without network: caches are seeded on disk and the
# configured repo base points at a closed local port, so any accidental
# fetch would fail loudly with ECONNREFUSED.
RSpec.describe Kotoshu::ResourceManager do
  let(:temp_cache_dir) { Dir.mktmpdir("kotoshu-rm-tier-spec") }
  let(:fixture_registry_path) do
    File.expand_path("../fixtures/registry.json", __dir__)
  end

  before do
    Kotoshu::Configuration.reset
    Kotoshu::Configuration.instance.cache_path = temp_cache_dir
    # Unreachable base: specs must never fetch; if they did, the closed
    # port fails fast instead of silently hitting the network.
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

  def seed_tiered_model(language, tier, bytes: "fake-onnx-bytes-#{tier}")
    dir = File.join(temp_cache_dir, language, "models", "onnx", tier.to_s)
    file = "fasttext.#{language}.#{tier}.onnx"
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, file), bytes, mode: "wb")
    File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                  "version" => "1.0.0",
                                                  "url" => "https://example.test/#{file}",
                                                  "language" => language,
                                                  "type" => "onnx",
                                                  "tier" => tier.to_s,
                                                  "file" => file,
                                                  "checksum" => Digest::SHA256.hexdigest(bytes),
                                                  "registry_id" => "kotoshu://models/#{language}/#{tier}",
                                                  "cached_at" => Time.now.utc.iso8601
                                                ))
  end

  def seed_full_model(language, bytes: "fake-onnx-bytes-full")
    dir = File.join(temp_cache_dir, language, "models", "onnx")
    file = "fasttext.#{language}.onnx"
    FileUtils.mkdir_p(dir)
    File.write(File.join(dir, file), bytes, mode: "wb")
    File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                  "version" => Time.now.utc.iso8601,
                                                  "url" => "https://example.test/#{file}",
                                                  "language" => language,
                                                  "type" => "onnx",
                                                  "file" => file,
                                                  "checksum" => Digest::SHA256.hexdigest(bytes),
                                                  "cached_at" => Time.now.utc.iso8601
                                                ))
  end

  describe "configuration default" do
    it "defaults model_tier to \"fluency\" (owner decision 2026-09-04; light/medium default)" do
      expect(Kotoshu::Configuration.instance.model_tier).to eq("fluency")
    end

    it "picks up KOTOSHU_MODEL_TIER from the environment automatically" do
      ENV["KOTOSHU_MODEL_TIER"] = "fluency"
      begin
        Kotoshu::Configuration.reset
        expect(Kotoshu::Configuration.instance.model_tier).to eq("fluency")
      ensure
        ENV.delete("KOTOSHU_MODEL_TIER")
      end
    end

    it "rejects an unknown tier at use time" do
      expect { described_class.setup(:en, want: %i[model], tier: :huge) }
        .to raise_error(ArgumentError, /unknown model tier :huge/)
    end
  end

  describe ".resolve with an explicit tier (cache-only)" do
    it "returns the bundle's model for the tier that was set up" do
      seed_tiered_model("en", "mini")

      bundle = described_class.resolve(language: "en", want: %i[model], tier: :mini)
      expect(bundle.has_model?).to be(true)
      expect(bundle.model[:metadata]["tier"]).to eq("mini")
      expect(bundle.model[:model_path]).to end_with("models/onnx/mini/fasttext.en.mini.onnx")
    end

    it "raises ResourceNotSetupError naming the tier when it is not cached" do
      seed_tiered_model("en", "mini")

      expect do
        described_class.resolve(language: "en", want: %i[model], tier: :fluency)
      end.to raise_error(Kotoshu::ResourceNotSetupError) do |err|
        expect(err.language).to eq("en")
        expect(err.resource_type).to eq("model tier 'fluency'")
        expect(err.message).to include("model tier 'fluency'")
        expect(err.message).to include("kotoshu setup en")
      end
    end

    it "raises for a missing configured tier when no model is cached" do
      expect do
        described_class.resolve(language: "en", want: %i[model])
      end.to raise_error(Kotoshu::ResourceNotSetupError) do |err|
        expect(err.resource_type).to start_with("model")
      end
    end

    it "resolves the full tier from the legacy layout" do
      seed_full_model("en")

      bundle = described_class.resolve(language: "en", want: %i[model], tier: :full)
      expect(bundle.model[:model_path]).to end_with("models/onnx/fasttext.en.onnx")
      expect(bundle.model[:metadata]["tier"]).to be_nil # legacy metadata has no tier
    end

    it "never downloads during resolve (closed port proves cache-only)" do
      seed_tiered_model("en", "mini")

      # If resolve fetched (registry or model), this raises
      # Errno::ECONNREFUSED instead of returning a bundle.
      bundle = described_class.resolve(language: "en", want: %i[model], tier: :mini)
      expect(bundle.has_model?).to be(true)
    end
  end

  describe ".resolve with tier: :any" do
    it "maps to the single cached tier" do
      seed_tiered_model("en", "mini")

      bundle = described_class.resolve(language: "en", want: %i[model], tier: :any)
      expect(bundle.model[:metadata]["tier"]).to eq("mini")
    end

    it "raises ResourceNotSetupError when no tier is cached" do
      expect do
        described_class.resolve(language: "en", want: %i[model], tier: :any)
      end.to raise_error(Kotoshu::ResourceNotSetupError, /no tier cached/)
    end

    it "raises when multiple tiers are cached, listing them in preference order" do
      seed_tiered_model("en", "mini")
      seed_full_model("en")

      expect do
        described_class.resolve(language: "en", want: %i[model], tier: :any)
      end.to raise_error(Kotoshu::ResourceResolutionError, /multiple model tiers cached \(mini, full\)/)
    end
  end

  describe ".setup? with tier:" do
    it "is false for every tier when nothing is cached" do
      expect(described_class.setup?(:en, resource: :model, tier: :mini)).to be(false)
      expect(described_class.setup?(:en, resource: :model, tier: :any)).to be(false)
    end

    it "reflects exactly the tier that was set up" do
      seed_tiered_model("en", "mini")

      expect(described_class.setup?(:en, resource: :model, tier: :mini)).to be(true)
      expect(described_class.setup?(:en, resource: :model, tier: :fluency)).to be(false)
      expect(described_class.setup?(:en, resource: :model, tier: :full)).to be(false)
      expect(described_class.setup?(:en, resource: :model, tier: :any)).to be(true)
    end

    it "is exposed through the Kotoshu facade" do
      seed_tiered_model("en", "mini")

      expect(Kotoshu.setup?(:en, resource: :model, tier: :mini)).to be(true)
      expect(Kotoshu.setup?(:en, resource: :model, tier: :full)).to be(false)
    end
  end

  describe ".setup with tier:" do
    it "reports :cached and the tier for an already-cached tiered model" do
      seed_registry_fixture
      seed_tiered_model("en", "mini")

      result = described_class.setup(:en, want: %i[model], tier: :mini)
      expect(result.model).to eq(:cached)
      expect(result.model_tier).to eq(:mini)
    end

    it "short-circuits to :cached without consulting the registry (offline-safe)" do
      # No registry seeded at all — a cached model must still work
      # offline, so availability is checked before any registry lookup.
      Kotoshu::Configuration.instance.offline = true
      seed_tiered_model("en", "fluency")

      result = described_class.setup(:en, want: %i[model], tier: :fluency)
      expect(result.model).to eq(:cached)
      expect(result.model_tier).to eq(:fluency)
    end

    it "defaults to the configured tier (:fluency) when tier is omitted" do
      seed_tiered_model("en", :fluency)

      result = described_class.setup(:en, want: %i[model])
      expect(result.model).to eq(:cached)
      expect(result.model_tier).to eq(:fluency)
    end

    it "bridges a legacy single-tier full cache on a tier-less setup" do
      seed_full_model("en")

      result = described_class.setup(:en, want: %i[model])
      expect(result.model).to eq(:cached)
      expect(result.model_tier).to eq(:full)
    end

    it "returns :unavailable offline when the registry is missing and nothing is cached" do
      Kotoshu::Configuration.instance.offline = true

      result = described_class.setup(:en, want: %i[model], tier: :mini)
      expect(result.model).to eq(:unavailable)
      expect(result.model_tier).to eq(:mini)
    end

    it "returns :unavailable when the registry has no entry for the tier" do
      seed_registry_fixture

      # zh is absent from the fixture registry
      result = described_class.setup(:zh, want: %i[model], tier: :mini)
      expect(result.model).to eq(:unavailable)
    end

    it "flows through the Kotoshu facade" do
      seed_registry_fixture
      seed_tiered_model("en", "mini")

      result = Kotoshu.setup(:en, want: %i[model], tier: "mini")
      expect(result.model).to eq(:cached)
      expect(result.model_tier).to eq(:mini)
    end
  end
end
