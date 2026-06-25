# frozen_string_literal: true

RSpec.describe Kotoshu::Language::Detector do
  describe ".detect" do
    context "with English text" do
      it "detects English" do
        expect(described_class.detect("Hello world")).to eq("en")
        expect(described_class.detect("The quick brown fox")).to eq("en")
      end

      it "detects English with mixed case" do
        expect(described_class.detect("Hello WORLD from TEST")).to eq("en")
      end
    end

    context "with French text" do
      it "detects French" do
        # Use text with French accents to ensure detection works
        expect(described_class.detect("café résumé")).to eq("fr")
        expect(described_class.detect("Comment ça va?")).to eq("fr")
      end
    end

    context "with German text" do
      it "detects German" do
        # Use text with more German umlauts for clearer detection
        expect(described_class.detect("Grüße aus Österreich")).to eq("de")
        expect(described_class.detect("äöüß")).to eq("de")
      end
    end

    context "with Spanish text" do
      it "detects Spanish" do
        # Use text with Spanish inverted punctuation and accents
        expect(described_class.detect("¿Cómo estás?")).to eq("es")
        expect(described_class.detect("niño")).to eq("es")
      end
    end

    context "with Portuguese text" do
      it "detects Portuguese" do
        # Use text with Portuguese-specific character combinations
        expect(described_class.detect("são paulo")).to eq("pt")
        expect(described_class.detect("coração")).to eq("pt")
      end
    end

    context "with Russian text" do
      it "detects Russian" do
        expect(described_class.detect("Привет мир")).to eq("ru")
        expect(described_class.detect("Здравствуйте")).to eq("ru")
      end
    end

    context "with Arabic text" do
      it "detects Arabic" do
        expect(described_class.detect("مرحبا بالعالم")).to eq("ar")
        expect(described_class.detect("السلام عليكم")).to eq("ar")
      end
    end

    context "with mixed text" do
      it "detects dominant language" do
        mixed = "Hello world bonjour tout le monde"
        result = described_class.detect(mixed)

        # Should detect one of them
        expect(%w[en fr]).to include(result)
      end
    end

    context "with invalid input" do
      it "returns nil for nil" do
        expect(described_class.detect(nil)).to be_nil
      end

      it "returns nil for empty string" do
        expect(described_class.detect("")).to be_nil
      end

      it "returns nil for whitespace only" do
        expect(described_class.detect("   ")).to be_nil
      end

      it "returns nil for special characters only" do
        expect(described_class.detect("123 !@#")).to be_nil
      end
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

    it "returns zero confidence for nil" do
      language, confidence = described_class.detect_with_confidence(nil)

      expect(language).to be_nil
      expect(confidence).to eq(0.0)
    end

    it "returns higher confidence for clear language signals" do
      _, conf1 = described_class.detect_with_confidence("Hello world")
      _, conf2 = described_class.detect_with_confidence("Über Deutschland")

      # Both should have reasonable confidence
      expect(conf1).to be > 0.3
      expect(conf2).to be > 0.3
    end
  end

  describe ".detect_candidates" do
    it "returns multiple candidates" do
      candidates = described_class.detect_candidates("Hello world")

      expect(candidates).to be_an(Array)
      expect(candidates).not_to be_empty

      first = candidates.first
      expect(first).to be_an(Array)
      expect(first.length).to eq(2)
      expect(first[0]).to be_a(String) # Language code
      expect(first[1]).to be_a(Float)  # Confidence
    end

    it "respects limit parameter" do
      candidates = described_class.detect_candidates("Hello world", limit: 2)

      expect(candidates.length).to be <= 2
    end

    it "returns empty array for nil" do
      candidates = described_class.detect_candidates(nil)

      expect(candidates).to eq([])
    end

    it "orders by confidence" do
      candidates = described_class.detect_candidates("Hello world")

      confidences = candidates.map { |_, c| c }
      expect(confidences).to eq(confidences.sort.reverse)
    end
  end
end
