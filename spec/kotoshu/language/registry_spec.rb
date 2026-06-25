# frozen_string_literal: true

RSpec.describe Kotoshu::Language::Registry do
  let(:test_language_class) do
    Class.new(Kotoshu::Language::Base) do
      def initialize
        super(code: "test", name: "Test Language")
      end

      def tokenizer
        Kotoshu::Language::Tokenizer::LatinTokenizer.new
      end

      def normalizer
        Kotoshu::Language::Normalizer::Base.new
      end

      def dictionary_class
        Kotoshu::Dictionary::PlainText
      end
    end
  end

  before do
    described_class.clear
  end

  after do
    described_class.clear
  end

  describe ".register" do
    it "registers a language class" do
      described_class.register("test", test_language_class)

      expect(described_class.registered?("test")).to be true
    end

    it "overwrites existing registration" do
      described_class.register("test", test_language_class)

      other_class = Class.new(Kotoshu::Language::Base)
      described_class.register("test", other_class)

      expect(described_class.get("test")).to eq(other_class)
    end
  end

  describe ".get" do
    before do
      described_class.register("en-US", test_language_class)
    end

    it "returns registered language class" do
      result = described_class.get("en-US")

      expect(result).to eq(test_language_class)
    end

    it "falls back to base language" do
      result = described_class.get("en")

      expect(result).to eq(test_language_class)
    end

    it "returns nil for unknown language" do
      result = described_class.get("de-DE")

      expect(result).to be_nil
    end

    it "returns nil for nil input" do
      result = described_class.get(nil)

      expect(result).to be_nil
    end
  end

  describe ".registered?" do
    before do
      described_class.register("en-US", test_language_class)
    end

    it "returns true for registered language" do
      expect(described_class.registered?("en-US")).to be true
    end

    it "returns true for base language when variant registered" do
      expect(described_class.registered?("en")).to be true
    end

    it "returns false for unknown language" do
      expect(described_class.registered?("fr-FR")).to be false
    end
  end

  describe ".supported_codes" do
    before do
      described_class.register("en-US", test_language_class)
      described_class.register("de-DE", test_language_class)
      described_class.register("fr-FR", test_language_class)
    end

    it "returns sorted list of codes" do
      codes = described_class.supported_codes

      expect(codes).to eq(["de-DE", "en-US", "fr-FR"])
    end
  end

  describe ".all" do
    before do
      described_class.register("en-US", test_language_class)
      described_class.register("de-DE", Class.new(Kotoshu::Language::Base))
    end

    it "returns all registered languages" do
      all = described_class.all

      expect(all.keys).to include("en-US", "de-DE")
      expect(all["en-US"]).to eq(test_language_class)
    end

    it "returns a copy of the registry" do
      all = described_class.all
      all.delete("en-US")

      expect(described_class.registered?("en-US")).to be true
    end
  end

  describe ".clear" do
    before do
      described_class.register("en-US", test_language_class)
    end

    it "clears all registrations" do
      described_class.clear

      expect(described_class.registered?("en-US")).to be false
      expect(described_class.supported_codes).to be_empty
    end
  end

  describe ".register_detector" do
    let(:test_detector) do
      Class.new do
        def detect(text)
          return "en" if text.match?(/hello/i)
          nil
        end
      end.new
    end

    it "registers a detector" do
      described_class.register_detector(test_detector)

      expect(described_class.detect("hello world")).to eq("en")
    end
  end

  describe ".detect" do
    let(:test_detector) do
      Class.new do
        def detect(text)
          return "en" if text.match?(/hello/i)
          return "fr" if text.match?(/bonjour/i)
          nil
        end
      end.new
    end

    before do
      described_class.register_detector(test_detector)
    end

    it "uses detectors to identify language" do
      expect(described_class.detect("hello world")).to eq("en")
      expect(described_class.detect("bonjour le monde")).to eq("fr")
    end

    it "returns nil when no detector matches" do
      expect(described_class.detect("こんにちは")).to be_nil
    end

    it "returns nil for nil input" do
      expect(described_class.detect(nil)).to be_nil
    end

    it "returns nil for empty input" do
      expect(described_class.detect("")).to be_nil
      expect(described_class.detect("   ")).to be_nil
    end
  end

  describe ".info" do
    let(:language_instance) do
      test_language_class.new
    end

    before do
      described_class.register("test", test_language_class)
    end

    it "returns language info" do
      info = described_class.info("test")

      expect(info).to include(
        code: "test",
        name: "Test Language",
        encoding: "UTF-8",
        rtl?: false,
        script_type: :latin
      )
    end

    it "returns nil for unknown language" do
      info = described_class.info("unknown")

      expect(info).to be_nil
    end
  end
end
