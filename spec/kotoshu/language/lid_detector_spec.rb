# frozen_string_literal: true

require "spec_helper"
require "json"
require "tmpdir"
require "fileutils"
require "digest"

# Native language detection (plan 106): the pure-Rust LID reader over
# the kotoshu://models/lid/lid-176 registry artifact pair, exposed as
# Kotoshu.detect_language -> Language::Detection with the
# Language::Detector heuristic as the fallback.
#
# The parity corpus is the frozen JSON the kotoshu-rs suite froze the
# reader against (55 samples: the gem's detection outputs over
# upstream lid.176.ftz). These specs replay it through the Ruby seam
# and assert the same contract: codes equal, scores within the fixture
# tolerance. Cache-layer behavior lives in
# spec/kotoshu/cache/model_cache_lid_spec.rb.
RSpec.describe Kotoshu::Language::LidDetector do
  let(:parity) { JSON.parse(File.read(File.expand_path("../../fixtures/lid/parity.json", __dir__))) }

  after { described_class.reset }

  describe "the Detection value" do
    it "carries code and score and interpolates to the code" do
      detection = Kotoshu::Language::Detection.new(code: "de", score: 0.99)

      expect(detection.code).to eq("de")
      expect(detection.score).to eq(0.99)
      expect("detected #{detection}").to eq("detected de")
    end
  end

  describe ".detect" do
    it "returns an empty Detection for nil" do
      detection = described_class.detect(nil, config: Kotoshu::Configuration.new)

      expect(detection).to be_a(Kotoshu::Language::Detection)
      expect(detection.code).to be_nil
      expect(detection.score).to eq(0.0)
    end

    it "falls back to the heuristic when the model is not set up" do
      Dir.mktmpdir do |dir|
        config = Kotoshu::Configuration.new(cache_path: dir)

        detection = described_class.detect(
          "Привет, это русский текст для проверки языка.",
          config: config
        )

        expect(described_class.available?(config: config)).to be false
        expect(detection).to be_a(Kotoshu::Language::Detection)
        expect(detection.code).to eq("ru")
        expect(detection.score).to be_a(Float).and(be_between(0.0, 1.0))
      end
    end
  end

  describe "KOTOSHU_BACKEND=ruby" do
    around do |example|
      ENV["KOTOSHU_BACKEND"] = "ruby"
      begin
        example.run
      ensure
        ENV.delete("KOTOSHU_BACKEND")
      end
    end

    it "stays on the heuristic even when the pair is cached" do
      Dir.mktmpdir do |dir|
        config = Kotoshu::Configuration.new(cache_path: dir)
        seed_pair(dir)

        expect(described_class.setup?(config: config)).to be true
        expect(described_class.available?(config: config)).to be false

        detection = described_class.detect(
          "Привет, это русский текст для проверки языка.",
          config: config
        )

        expect(detection.code).to eq("ru")
      end
    end
  end

  describe ".setup" do
    it "raises when offline with no cached registry" do
      Dir.mktmpdir do |dir|
        prior = Kotoshu::Configuration.instance.offline
        Kotoshu::Configuration.instance.offline = true
        begin
          config = Kotoshu::Configuration.new(cache_path: dir)

          expect { described_class.setup(config: config) }
            .to raise_error(Kotoshu::Error, /offline mode.*no cached registry/)
        ensure
          Kotoshu::Configuration.instance.offline = prior
        end
      end
    end

    it "raises when the registry carries no lid entry" do
      Dir.mktmpdir do |dir|
        cache = Kotoshu::Cache::ModelCache.new(
          cache_path: dir,
          source_registry: Kotoshu::SourceRegistry.new(base_url: "http://127.0.0.1:9")
        )
        registry_dir = File.join(dir, "registry")
        FileUtils.mkdir_p(registry_dir)
        json = JSON.pretty_generate("spec" => "kotoshu.resources/v1",
                                    "registry_version" => 1, "resources" => {})
        File.binwrite(File.join(registry_dir, "registry.json"), json)
        File.write(File.join(registry_dir, "metadata.json"), JSON.pretty_generate(
                                                               "url" => "fixture", "sha256" => Digest::SHA256.hexdigest(json),
                                                               "cached_at" => Time.now.utc.iso8601
                                                             ))
        config = Kotoshu::Configuration.new(cache_path: dir)

        expect { described_class.setup(config: config) }
          .to raise_error(Kotoshu::Error, /no registry entry for kotoshu:\/\/models\/lid\/lid-176/)
      end
    end
  end

  describe "setup and detect through the real registry", :network do
    it "downloads once, resolves cache-only, and answers a 176-language detect" do
      Dir.mktmpdir do |dir|
        config = Kotoshu::Configuration.new(cache_path: dir)

        pair = described_class.setup(config: config)

        expect(pair[:metadata][:registry_id]).to eq("kotoshu://models/lid/lid-176")
        expect(described_class.setup?(config: config)).to be true

        described_class.reset
        unless described_class.available?(config: config)
          skip "native extension not built (rake compile) or predates plan 106"
        end

        detection = described_class.detect(
          "Maschinelle Lernmodelle benötigen große Mengen annotierter Daten.",
          config: config
        )

        expect(detection.code).to eq("de")
        expect(detection.score).to be > 0.5
      end
    end
  end

  describe "parity with the frozen gem corpus", :native_ext, :network do
    before do
      skip "native extension not built (rake compile)" unless Kotoshu::Native.available?
      skip "Kotoshu::Native::LidModel missing (rebuild the extension)" unless Kotoshu::Native.const_defined?(:LidModel)
    end

    it "reproduces every frozen code and score, and the expected labels" do
      Dir.mktmpdir do |dir|
        config = Kotoshu::Configuration.new(cache_path: dir)
        described_class.setup(config: config)
        described_class.reset

        labeled = 0
        parity["samples"].each do |sample|
          detection = described_class.detect(sample["text"], config: config)

          expect(detection.code).to eq(sample["code"]),
                                    "code mismatch on #{sample['id']}: #{detection.code.inspect}"
          expect(detection.score).to be_within(parity["tolerance"]).of(sample["score"]),
                                     "score mismatch on #{sample['id']}"

          next if sample["expected"].nil?

          labeled += 1
          expect(detection.code).to eq(sample["expected"]), sample["id"]
        end
        expect(labeled).to eq(52)
      end
    end
  end

  describe "the Kotoshu facade" do
    it "returns a Detection from detect_language" do
      detection = Kotoshu.detect_language("Hello world")

      expect(detection).to be_a(Kotoshu::Language::Detection)
      expect(detection.code).to be_a(String).or be_nil
      expect(detection.score).to be_a(Float).and(be_between(0.0, 1.0))
    end

    it "keeps the historical pair shape on detect_language_with_confidence" do
      code, score = Kotoshu.detect_language_with_confidence("Bonjour le monde")

      expect(code).to be_a(String).or be_nil
      expect(score).to be_a(Float).and(be_between(0.0, 1.0))
    end
  end

  private

  # Seed a cached lid pair with placeholder bytes and a matching
  # checksum: enough for cache-resolution and backend-selection specs
  # (the model is never parsed on those paths). The real pair is only
  # needed where detection actually runs, which the network-tagged
  # examples download.
  def seed_pair(cache_dir)
    dir = File.join(cache_dir, "lid")
    FileUtils.mkdir_p(dir)
    onnx = "spec-lid-onnx-bytes"
    File.binwrite(File.join(dir, "lid.176.onnx"), onnx)
    File.binwrite(File.join(dir, "lid.176.vocab.json"), "{}")
    File.write(File.join(dir, "metadata.json"), JSON.pretty_generate(
                                                  "version" => "1.4.0",
                                                  "url" => "fixture",
                                                  "language" => "lid",
                                                  "type" => "lid",
                                                  "tier" => "lid-176",
                                                  "file" => "lid.176.onnx",
                                                  "vocab_file" => "lid.176.vocab.json",
                                                  "checksum" => Digest::SHA256.hexdigest(onnx),
                                                  "registry_id" => "kotoshu://models/lid/lid-176",
                                                  "size_bytes" => onnx.bytesize,
                                                  "cached_at" => Time.now.utc.iso8601,
                                                  "source" => "fixture"
                                                ))
  end
end
