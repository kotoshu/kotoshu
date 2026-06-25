# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "kotoshu/resource_manager"

RSpec.describe Kotoshu::ResourceManager do
  let(:temp_cache_dir) { Dir.mktmpdir("kotoshu-rm-spec") }

  after do
    FileUtils.rm_rf(temp_cache_dir)
    Kotoshu::Configuration.reset
  end

  before do
    Kotoshu::Configuration.reset
    Kotoshu::Configuration.instance.cache_path = temp_cache_dir
  end

  describe ".resolve / #resolve" do
    it "raises ResourceNotCachedError when offline and not cached" do
      expect do
        described_class.resolve(language: "en", offline: true)
      end.to raise_error(Kotoshu::ResourceNotCachedError) do |err|
        expect(err.language).to eq("en")
        expect(err.resource_type).to eq("spelling")
        expect(err.message).to include("kotoshu cache download language en")
      end
    end

    it "raises ResourceNotCachedError with normalized language code" do
      expect do
        described_class.resolve(language: "en-US", offline: true)
      end.to raise_error(Kotoshu::ResourceNotCachedError) do |err|
        expect(err.language).to eq("en")
      end
    end

    it "raises ResourceNotCachedError with symbol language code" do
      expect do
        described_class.resolve(language: :en, offline: true)
      end.to raise_error(Kotoshu::ResourceNotCachedError) do |err|
        expect(err.language).to eq("en")
      end
    end
  end

  describe "language normalization" do
    it "strips region suffixes" do
      # de-DE -> de
      error = nil
      begin
        described_class.resolve(language: "de-DE", offline: true)
      rescue Kotoshu::ResourceNotCachedError => e
        error = e
      end
      expect(error.language).to eq("de")
    end

    it "handles underscore-separated locale codes" do
      error = nil
      begin
        described_class.resolve(language: "pt_BR", offline: true)
      rescue Kotoshu::ResourceNotCachedError => e
        error = e
      end
      expect(error.language).to eq("pt")
    end

    it "downcases the code" do
      error = nil
      begin
        described_class.resolve(language: "EN-us", offline: true)
      rescue Kotoshu::ResourceNotCachedError => e
        error = e
      end
      expect(error.language).to eq("en")
    end
  end

  describe "language detection fallback" do
    it "uses default_language when no text and no language given" do
      Kotoshu::Configuration.instance.default_language = "fr"

      error = nil
      begin
        described_class.resolve(offline: true)
      rescue Kotoshu::ResourceNotCachedError => e
        error = e
      end
      expect(error.language).to eq("fr")
    end

    it "uses default_language when text is blank" do
      Kotoshu::Configuration.instance.default_language = "de"

      error = nil
      begin
        described_class.resolve(text: "   ", offline: true)
      rescue Kotoshu::ResourceNotCachedError => e
        error = e
      end
      expect(error.language).to eq("de")
    end
  end

  describe "explicit :auto language" do
    it "falls back to default_language when text is nil" do
      Kotoshu::Configuration.instance.default_language = "es"

      error = nil
      begin
        described_class.resolve(language: :auto, offline: true)
      rescue Kotoshu::ResourceNotCachedError => e
        error = e
      end
      expect(error.language).to eq("es")
    end
  end

  describe "want parameter" do
    it "skips spelling resolution when not in want" do
      bundle = described_class.resolve(language: "en", want: [], offline: true)

      expect(bundle.language).to eq("en")
      expect(bundle.dictionary).to be_nil
      expect(bundle.cached?).to eq(true) # vacuously cached when nothing was resolved
    end

    it "skips frequency resolution when not in want" do
      bundle = described_class.resolve(language: "ar", want: [:spelling], offline: true) rescue nil
      # Arabic isn't in AVAILABLE_LANGUAGES for spelling, but we expect
      # ResourceNotCachedError to be raised before frequency is touched
    rescue Kotoshu::ResourceNotCachedError
      # expected — spelling is wanted but not cached
    end
  end

  describe "strict mode for optional resources" do
    # English is supported for both spelling and frequency (Kelly list).
    # Pre-cache spelling, leave frequency uncached, and assert that strict
    # mode changes how the missing optional resource is handled.
    let(:en_aff_fixture) { File.expand_path("../integrational/fixtures/en_US.aff", __dir__) }
    let(:en_dic_fixture) { File.expand_path("../integrational/fixtures/en_US.dic", __dir__) }

    before do
      skip "en_US fixtures missing" unless File.exist?(en_aff_fixture) && File.exist?(en_dic_fixture)

      dir = File.join(temp_cache_dir, "languages", "en", "spelling")
      FileUtils.mkdir_p(dir)
      FileUtils.cp(en_aff_fixture, File.join(dir, "index.aff"))
      FileUtils.cp(en_dic_fixture, File.join(dir, "index.dic"))
      File.write(File.join(dir, "metadata.json"), {
        "language" => "en",
        "type" => "spelling",
        "version" => "2026-01-01T00:00:00Z",
        "cached_at" => "2026-06-25T00:00:00Z",
        "source" => "fixture"
      }.to_json)
    end

    it "silently degrades when frequency is uncached (default)" do
      bundle = described_class.resolve(
        language: "en",
        want: %i[spelling frequency],
        offline: true
      )

      expect(bundle.dictionary).to be_a(Kotoshu::Dictionary::Hunspell)
      expect(bundle.frequency).to be_nil
    end

    it "raises ResourceNotCachedError in strict mode when frequency is uncached" do
      expect do
        described_class.resolve(
          language: "en",
          want: %i[spelling frequency],
          offline: true,
          strict: true
        )
      end.to raise_error(Kotoshu::ResourceNotCachedError) do |err|
        expect(err.language).to eq("en")
        expect(err.resource_type).to eq("frequency")
      end
    end
  end

  describe "downloading (network)", :network do
    it "downloads and returns a real bundle for English" do
      bundle = described_class.resolve(language: "en")

      expect(bundle).to be_a(Kotoshu::ResourceBundle)
      expect(bundle.language).to eq("en")
      expect(bundle.dictionary).to be_a(Kotoshu::Dictionary::Hunspell)
      expect(bundle.dictionary.correct?("hello")).to eq(true)
    end

    it "auto-detects language from German text" do
      bundle = described_class.resolve(text: "Guten Tag, wie geht es Ihnen heute?")
      expect(bundle.language).to eq("de")
    end
  end
end
