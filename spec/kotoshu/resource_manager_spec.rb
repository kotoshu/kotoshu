# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"
require "kotoshu/resource_manager"

RSpec.describe Kotoshu::ResourceManager do
  let(:temp_cache_dir) { Dir.mktmpdir("kotoshu-rm-spec") }
  let(:en_aff_fixture) { File.expand_path("../integrational/fixtures/en_US.aff", __dir__) }
  let(:en_dic_fixture) { File.expand_path("../integrational/fixtures/en_US.dic", __dir__) }

  after do
    FileUtils.rm_rf(temp_cache_dir)
    Kotoshu::Configuration.reset
  end

  before do
    Kotoshu::Configuration.reset
    Kotoshu::Configuration.instance.cache_path = temp_cache_dir
  end

  describe ".resolve / #resolve (cache-only)" do
    it "raises ResourceNotSetupError when not set up" do
      expect do
        described_class.resolve(language: "en")
      end.to raise_error(Kotoshu::ResourceNotSetupError) do |err|
        expect(err.language).to eq("en")
        expect(err.resource_type).to eq("spelling")
        expect(err.message).to include("kotoshu setup en")
      end
    end

    it "raises ResourceNotSetupError with normalized language code" do
      expect do
        described_class.resolve(language: "en-US")
      end.to raise_error(Kotoshu::ResourceNotSetupError) do |err|
        expect(err.language).to eq("en")
      end
    end

    it "raises ResourceNotSetupError with symbol language code" do
      expect do
        described_class.resolve(language: :en)
      end.to raise_error(Kotoshu::ResourceNotSetupError) do |err|
        expect(err.language).to eq("en")
      end
    end
  end

  describe "language normalization" do
    it "strips region suffixes" do
      error = nil
      begin
        described_class.resolve(language: "de-DE")
      rescue Kotoshu::ResourceNotSetupError => e
        error = e
      end
      expect(error.language).to eq("de")
    end

    it "handles underscore-separated locale codes" do
      error = nil
      begin
        described_class.resolve(language: "pt_BR")
      rescue Kotoshu::ResourceNotSetupError => e
        error = e
      end
      expect(error.language).to eq("pt")
    end

    it "downcases the code" do
      error = nil
      begin
        described_class.resolve(language: "EN-us")
      rescue Kotoshu::ResourceNotSetupError => e
        error = e
      end
      expect(error.language).to eq("en")
    end
  end

  describe ".setup? predicate" do
    it "returns false for an unset language" do
      expect(described_class.setup?("en")).to eq(false)
    end

    it "returns true after a local install" do
      skip "en_US fixtures missing" unless File.exist?(en_aff_fixture) && File.exist?(en_dic_fixture)

      described_class.setup_from_local(
        language: "en",
        aff: en_aff_fixture,
        dic: en_dic_fixture
      )
      expect(described_class.setup?(:en)).to eq(true)
      expect(described_class.setup?(:en, resource: :spelling)).to eq(true)
    end

    it "returns false for :frequency when only spelling is set up" do
      skip "en_US fixtures missing" unless File.exist?(en_aff_fixture) && File.exist?(en_dic_fixture)

      described_class.setup_from_local(
        language: "en",
        aff: en_aff_fixture,
        dic: en_dic_fixture
      )
      expect(described_class.setup?(:en, resource: :frequency)).to eq(false)
    end
  end

  describe ".languages_setup" do
    it "returns empty array when nothing is set up" do
      expect(described_class.languages_setup).to eq([])
    end

    it "lists set up languages" do
      skip "en_US fixtures missing" unless File.exist?(en_aff_fixture) && File.exist?(en_dic_fixture)

      described_class.setup_from_local(
        language: "en",
        aff: en_aff_fixture,
        dic: en_dic_fixture
      )
      expect(described_class.languages_setup).to eq(["en"])
    end
  end

  describe ".setup_from_local" do
    it "raises ArgumentError when aff file is missing" do
      expect do
        described_class.setup_from_local(
          language: "en",
          aff: "/nonexistent.aff",
          dic: en_dic_fixture
        )
      end.to raise_error(ArgumentError, /aff file not found/)
    end

    it "raises ArgumentError when dic file is missing" do
      expect do
        described_class.setup_from_local(
          language: "en",
          aff: en_aff_fixture,
          dic: "/nonexistent.dic"
        )
      end.to raise_error(ArgumentError, /dic file not found/)
    end

    it "installs the language and lets resolve succeed" do
      skip "en_US fixtures missing" unless File.exist?(en_aff_fixture) && File.exist?(en_dic_fixture)

      result = described_class.setup_from_local(
        language: "en",
        aff: en_aff_fixture,
        dic: en_dic_fixture
      )
      expect(result.language).to eq("en")
      expect(result.spelling).to eq(:local)
      expect(result.source).to eq(:local)

      bundle = described_class.resolve(language: "en")
      expect(bundle.dictionary).to be_a(Kotoshu::Dictionary::Hunspell)
      expect(bundle.dictionary.lookup("hello")).to eq(true)
    end

    it "is idempotent without force (raises on second run)" do
      skip "en_US fixtures missing" unless File.exist?(en_aff_fixture) && File.exist?(en_dic_fixture)

      described_class.setup_from_local(language: "en", aff: en_aff_fixture, dic: en_dic_fixture)
      expect do
        described_class.setup_from_local(language: "en", aff: en_aff_fixture, dic: en_dic_fixture)
      end.to raise_error(ArgumentError, /already exists/)
    end

    it "overwrites with force: true" do
      skip "en_US fixtures missing" unless File.exist?(en_aff_fixture) && File.exist?(en_dic_fixture)

      described_class.setup_from_local(language: "en", aff: en_aff_fixture, dic: en_dic_fixture)
      result = described_class.setup_from_local(
        language: "en",
        aff: en_aff_fixture,
        dic: en_dic_fixture,
        force: true
      )
      expect(result.spelling).to eq(:local)
    end
  end

  describe ".setup with want: parameter" do
    it "accepts multiple resource types" do
      skip "en_US fixtures missing" unless File.exist?(en_aff_fixture) && File.exist?(en_dic_fixture)

      result = described_class.setup(
        :en,
        aff: en_aff_fixture,
        dic: en_dic_fixture,
        want: %i[spelling frequency]
      )
      expect(result.spelling).to eq(:local)
    end
  end

  describe "downloading from kotoshu/dictionaries (network)", :network do
    it "downloads and returns a real bundle for English" do
      result = described_class.setup(:en)
      expect(result).to be_a(Kotoshu::ResourceManager::SetupResult)
      expect(result.language).to eq("en")
      expect(result.spelling).to eq(:downloaded).or(eq(:cached))

      bundle = described_class.resolve(language: "en")
      expect(bundle.dictionary).to be_a(Kotoshu::Dictionary::Hunspell)
      expect(bundle.dictionary.lookup("hello")).to eq(true)
    end
  end
end
