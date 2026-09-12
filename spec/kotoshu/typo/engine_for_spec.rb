# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "digest"
require "json"

# The Typo::Engine resolve path (plan 131): cache-only, two-stage —
# nothing downloads, every absent link is a nil, and the armed case
# needs BOTH the native extension and parseable cached artifacts.
RSpec.describe Kotoshu::Typo::Engine do
  let(:temp_dir) { Dir.mktmpdir("kotoshu-typo-for") }
  let(:configuration) do
    config = Kotoshu::Configuration.new
    config.cache_path = temp_dir
    config
  end

  def seed_typo_pair(bytes: "fake-typo-biencoder-bytes" * 64)
    dir = File.join(temp_dir, "models", "typo")
    FileUtils.mkdir_p(dir)
    File.binwrite(File.join(dir, "typo.biencoder.onnx"), bytes)
    File.binwrite(File.join(dir, "typo.biencoder.vocab.json"), "{}")
    File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                  "file" => "typo.biencoder.onnx", "vocab_file" => "typo.biencoder.vocab.json",
                                                  "checksum" => Digest::SHA256.hexdigest(bytes),
                                                  "registry_id" => "kotoshu://models/typo/typo-biencoder",
                                                  "url" => "fixture", "cached_at" => Time.now.utc.iso8601
                                                ))
  end

  def seed_full_tier
    dir = File.join(temp_dir, "en", "models", "onnx")
    FileUtils.mkdir_p(dir)
    File.binwrite(File.join(dir, "fasttext.en.onnx"), "fake-full-tier")
    File.binwrite(File.join(dir, "fasttext.en.vocab.json"), "{}")
    File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                  "file" => "fasttext.en.onnx", "vocab_file" => "fasttext.en.vocab.json",
                                                  "checksum" => Digest::SHA256.hexdigest("fake-full-tier"),
                                                  "url" => "fixture", "cached_at" => Time.now.utc.iso8601
                                                ))
  end

  after { FileUtils.rm_rf(temp_dir) if File.exist?(temp_dir) }

  it "is nil when nothing is cached" do
    expect(described_class.for("en", configuration: configuration)).to be_nil
  end

  it "is nil when only the typo pair is cached (the tier is absent)" do
    seed_typo_pair
    expect(described_class.for("en", configuration: configuration)).to be_nil
  end

  it "is nil when the tier lacks its vocab sibling" do
    seed_typo_pair
    seed_full_tier
    File.delete(File.join(temp_dir, "en", "models", "onnx", "fasttext.en.vocab.json"))
    expect(described_class.for("en", configuration: configuration)).to be_nil
  end

  it "degrades to nil on unparseable artifacts (never raises)" do
    seed_typo_pair
    seed_full_tier
    # Both pairs cached but the bytes are fixtures: either the native
    # extension is absent (nil at the guard) or TypoModel.parse fails
    # (nil at the rescue) — both the silent-degrade contract.
    expect(described_class.for("en", configuration: configuration)).to be_nil
  end
end
