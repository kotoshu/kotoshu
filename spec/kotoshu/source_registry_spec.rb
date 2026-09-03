# frozen_string_literal: true

require "spec_helper"
require "kotoshu/source_registry"

RSpec.describe Kotoshu::SourceRegistry do
  describe "#url_for" do
    it "builds spelling URL with v1 pin and language extension" do
      registry = described_class.new
      expect(registry.url_for(:spelling, lang: "en", ext: "aff")).to eq(
        "https://raw.githubusercontent.com/kotoshu/dictionaries/v1/en/spelling/index.aff"
      )
    end

    it "builds grammar URL with v1 pin" do
      registry = described_class.new
      expect(registry.url_for(:grammar, lang: "de")).to eq(
        "https://raw.githubusercontent.com/kotoshu/dictionaries/v1/de/grammar/rules.yaml"
      )
    end

    it "builds frequency URL with main pin (Kelly repo)" do
      registry = described_class.new
      expect(registry.url_for(:frequency, lang: "en")).to eq(
        "https://raw.githubusercontent.com/kotoshu/frequency-list-kelly/main/data/en.json"
      )
    end

    it "builds model URL with main pin via the Git-LFS media host" do
      registry = described_class.new
      # *.onnx is LFS-tracked in models-fasttext-onnx: raw.githubusercontent
      # serves the 134-byte pointer stub, so the model must be fetched from
      # the media host (vocab.json is plain git and stays on raw).
      expect(registry.url_for(:model, lang: "ja")).to eq(
        "https://media.githubusercontent.com/media/kotoshu/models-fasttext-onnx/main/models/ja/fasttext.ja.onnx"
      )
    end

    it "builds vocab URL paired with each model" do
      registry = described_class.new
      expect(registry.url_for(:model_vocab, lang: "ja")).to eq(
        "https://raw.githubusercontent.com/kotoshu/models-fasttext-onnx/main/models/ja/fasttext.ja.vocab.json"
      )
    end

    it "builds manifest URLs for each repo" do
      registry = described_class.new
      expect(registry.url_for(:dict_manifest)).to eq(
        "https://raw.githubusercontent.com/kotoshu/dictionaries/v1/manifest.json"
      )
      expect(registry.url_for(:freq_manifest)).to eq(
        "https://raw.githubusercontent.com/kotoshu/frequency-list-kelly/main/manifest.json"
      )
      expect(registry.url_for(:model_manifest)).to eq(
        "https://raw.githubusercontent.com/kotoshu/models-fasttext-onnx/main/manifest.json"
      )
    end

    it "raises ArgumentError for unknown source" do
      registry = described_class.new
      expect { registry.url_for(:nope) }.to raise_error(ArgumentError, /unknown source/)
    end
  end

  describe "per-repo pin overrides" do
    it "honors override pins keyed by repo name" do
      registry = described_class.new(pins: { "dictionaries" => "v2" })
      expect(registry.url_for(:spelling, lang: "en", ext: "aff")).to eq(
        "https://raw.githubusercontent.com/kotoshu/dictionaries/v2/en/spelling/index.aff"
      )
    end

    it "leaves other repos on their default pin when only one is overridden" do
      registry = described_class.new(pins: { "dictionaries" => "feature-branch" })
      expect(registry.url_for(:model, lang: "en")).to include("models-fasttext-onnx/main/")
    end

    it "keeps a custom mirror base for LFS model sources" do
      # A mirror is responsible for resolving LFS itself; only the default
      # GitHub raw host is swapped for the media host.
      registry = described_class.new(base_url: "https://mirror.example.com/kotoshu")
      expect(registry.url_for(:model, lang: "ja")).to eq(
        "https://mirror.example.com/kotoshu/models-fasttext-onnx/main/models/ja/fasttext.ja.onnx"
      )
    end

    it "accepts symbol keys in the pins hash" do
      registry = described_class.new(pins: { dictionaries: "v3" })
      expect(registry.pin_for_source(:spelling)).to eq("v3")
    end
  end

  describe "custom base URL" do
    it "uses the provided base without trailing slash" do
      registry = described_class.new(base_url: "https://mirror.example.com/kotoshu/")
      expect(registry.base_url).to eq("https://mirror.example.com/kotoshu")
      expect(registry.url_for(:spelling, lang: "en", ext: "aff")).to start_with(
        "https://mirror.example.com/kotoshu/dictionaries/v1/"
      )
    end
  end

  describe "#pin_for_source and #repo_for" do
    it "returns the default pin when no override is configured" do
      registry = described_class.new
      expect(registry.pin_for_source(:spelling)).to eq("v1")
      expect(registry.pin_for_source(:frequency)).to eq("main")
      expect(registry.pin_for_source(:model)).to eq("main")
    end

    it "returns the repo name for a source key" do
      registry = described_class.new
      expect(registry.repo_for(:spelling)).to eq("dictionaries")
      expect(registry.repo_for(:frequency)).to eq("frequency-list-kelly")
      expect(registry.repo_for(:model)).to eq("models-fasttext-onnx")
    end
  end

  describe "immutability" do
    it "is unaffected by mutating the hash passed to the constructor" do
      pins = { "dictionaries" => "v1" }
      registry = described_class.new(pins: pins)
      pins["dictionaries"] = "tampered"

      expect(registry.pin_for_source(:spelling)).to eq("v1")
    end
  end
end
