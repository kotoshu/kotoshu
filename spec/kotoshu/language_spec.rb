# frozen_string_literal: true

RSpec.describe Kotoshu::Language do
  describe ".detect" do
    it "detects English" do
      expect(described_class.detect("Hello world")).to eq("en")
    end

    it "detects French" do
      # Use text with French accents
      expect(described_class.detect("café résumé")).to eq("fr")
    end

    it "detects German" do
      # Use text with more German umlauts for clearer detection
      expect(described_class.detect("Grüße aus Österreich")).to eq("de")
    end

    it "detects Arabic" do
      pending "FastText LID missing Arabic vector — see TODO.impl/30-language-auto-detection.md"
      expect(described_class.detect("مرحبا")).to eq("ar")
    end

    it "returns nil for unknown" do
      result = described_class.detect("")

      # Empty or nil returns nil
      expect(result).to be_nil
    end
  end

  describe ".detect_with_confidence" do
    it "returns language and confidence" do
      language, confidence = described_class.detect_with_confidence("Hello world")

      expect(language).to eq("en")
      expect(confidence).to be_a(Float)
      expect(confidence).to be > 0.0
      expect(confidence).to be <= 1.0
    end
  end

  describe ".get" do
    before do
      # Clear any existing registrations
      Kotoshu::Language::Registry.clear
    end

    after do
      Kotoshu::Language::Registry.clear
    end

    it "returns nil for unregistered language" do
      result = described_class.get("xx-XX")

      expect(result).to be_nil
    end

    context "with registered language" do
      let(:test_class) do
        Class.new(Kotoshu::Language::Base) do
          def initialize
            super(code: "test", name: "Test")
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
        described_class.register("test", test_class)
      end

      it "returns registered class" do
        result = described_class.get("test")

        expect(result).to eq(test_class)
      end
    end
  end

  describe ".registered?" do
    before do
      Kotoshu::Language::Registry.clear
    end

    after do
      Kotoshu::Language::Registry.clear
    end

    it "returns false for unregistered language" do
      expect(described_class.registered?("xx-XX")).to be false
    end

    context "with registered language" do
      before do
        test_class = Class.new(Kotoshu::Language::Base) do
          def initialize
            super(code: "test", name: "Test")
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

        described_class.register("test", test_class)
      end

      it "returns true for registered language" do
        expect(described_class.registered?("test")).to be true
      end
    end
  end

  describe ".supported_codes" do
    before do
      Kotoshu::Language::Registry.clear
    end

    after do
      Kotoshu::Language::Registry.clear
    end

    it "returns empty array when no languages registered" do
      expect(described_class.supported_codes).to eq([])
    end

    context "with registered languages" do
      before do
        test_class = Class.new(Kotoshu::Language::Base) do
          def initialize
            super(code: "test", name: "Test")
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

        described_class.register("en-US", test_class)
        described_class.register("de-DE", test_class)
        described_class.register("fr-FR", test_class)
      end

      it "returns sorted list of codes" do
        codes = described_class.supported_codes

        expect(codes).to eq(["de-DE", "en-US", "fr-FR"])
      end
    end
  end

  describe ".info" do
    before do
      Kotoshu::Language::Registry.clear
    end

    after do
      Kotoshu::Language::Registry.clear
    end

    it "returns nil for unregistered language" do
      result = described_class.info("xx-XX")

      expect(result).to be_nil
    end

    context "with registered language" do
      before do
        test_class = Class.new(Kotoshu::Language::Base) do
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

        described_class.register("test", test_class)
      end

      it "returns language info" do
        info = described_class.info("test")

        expect(info).to include(
          code: "test",
          name: "Test Language",
          encoding: "UTF-8"
        )
      end
    end
  end

  describe ".register" do
    before do
      Kotoshu::Language::Registry.clear
    end

    after do
      Kotoshu::Language::Registry.clear
    end

    it "registers a language class" do
      test_class = Class.new(Kotoshu::Language::Base) do
        def initialize
          super(code: "test", name: "Test")
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

      described_class.register("test", test_class)

      expect(described_class.registered?("test")).to be true
    end
  end
end
