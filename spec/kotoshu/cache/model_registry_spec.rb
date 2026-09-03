# frozen_string_literal: true

require "spec_helper"

# Plan 67 M1: the tier registry model parses registry.json (Resource
# Spec v1) from kotoshu/models-fasttext-onnx via lutaml-model. These
# specs run against the checked-in fixture copy — never the network.
RSpec.describe Kotoshu::Cache::ModelRegistry do
  let(:fixture_path) { File.expand_path("../../fixtures/registry.json", __dir__) }
  let(:fixture_json) { File.read(fixture_path) }
  let(:registry) { described_class.from_json(fixture_json) }

  it "parses the top-level fields" do
    expect(registry.spec).to eq("kotoshu.resources/v1")
    expect(registry.registry_version).to eq(1)
    expect(registry.generated_at).to eq("2026-09-02T22:16:05Z")
    expect(registry.release_tag).to eq("v1.0.0")
  end

  it "holds one entry per (language, tier) id" do
    expect(registry.resources.keys).to contain_exactly(
      "kotoshu://models/de/fluency", "kotoshu://models/de/full", "kotoshu://models/de/mini",
      "kotoshu://models/en/fluency", "kotoshu://models/en/full", "kotoshu://models/en/mini"
    )
  end

  describe "#find" do
    it "returns a typed resource for an existing (language, tier) pair" do
      entry = registry.find("en", "mini")

      expect(entry).to be_a(described_class::Resource)
      expect(entry.type).to eq("model")
      expect(entry.language).to eq("en")
      expect(entry.tier.name).to eq("mini")
      expect(entry.tier.dims).to eq(300)
      expect(entry.tier.vocab_size).to eq(10_000)
      expect(entry.tier.quantization).to eq("int8-per-row")
      expect(entry.version).to eq("1.0.0")
      expect(entry.urls.primary).to eq(
        "https://github.com/kotoshu/models-fasttext-onnx/releases/download/v1.0.0/fasttext.en.mini.onnx"
      )
      expect(entry.urls.mirror).to eq(
        "https://github.com/kotoshu/models-fasttext-onnx/raw/main/models/en/fasttext.en.mini.onnx"
      )
      expect(entry.vocab_url).to eq(
        "https://github.com/kotoshu/models-fasttext-onnx/releases/download/v1.0.0/fasttext.en.mini.vocab.json"
      )
      expect(entry.sha256).to match(/\A[0-9a-f]{64}\z/)
      expect(entry.size_bytes).to be_a(Integer)
      expect(entry.license).to eq("CC-BY-SA-3.0")
      expect(entry.min_engine_version).to eq("0.7")
      expect(entry.eval_ref).to eq("eval/reports/en.mini.json")
    end

    it "accepts a tier given as a symbol" do
      expect(registry.find("en", :fluency).tier.name).to eq("fluency")
    end

    it "leaves nullable fields nil for the full tier" do
      entry = registry.find("de", "full")

      expect(entry.tier.quantization).to be_nil
      expect(entry.eval_ref).to be_nil
    end

    it "returns nil for an unknown language" do
      expect(registry.find("xx", "mini")).to be_nil
    end

    it "returns nil for an unknown tier" do
      expect(registry.find("en", "huge")).to be_nil
    end
  end

  describe ".id_for" do
    it "builds the stable registry id" do
      expect(described_class::Resource.id_for("en", "mini")).to eq("kotoshu://models/en/mini")
      expect(described_class::Resource.id_for("de", :fluency)).to eq("kotoshu://models/de/fluency")
    end

    it "is the key under which entries are stored" do
      id = described_class::Resource.id_for("en", "mini")
      expect(registry.resources).to be_key(id)
    end
  end

  describe "#languages" do
    it "lists the languages the registry covers" do
      expect(registry.languages).to eq(%w[de en])
    end
  end

  describe "lutaml-model round trip" do
    it "deserializes a raw resource hash through Resource.from_hash" do
      raw = registry.resources["kotoshu://models/en/fluency"]
      entry = described_class::Resource.from_hash(raw)

      expect(entry.language).to eq("en")
      expect(entry.tier.name).to eq("fluency")
      expect(entry.urls.primary).to match(%r{/fasttext\.en\.fluency\.onnx\z})
    end
  end
end
