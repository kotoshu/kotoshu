# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Dictionaries::Catalog, "# Integration - Dictionary Catalog" do
  describe ".all" do
    it "returns an array of DictionaryEntry objects" do
      entries = described_class.all

      expect(entries).to be_an(Array)
      expect(entries).not_to be_empty
      expect(entries.first).to be_a(Kotoshu::Dictionaries::Catalog::DictionaryEntry)
    end

    it "includes dictionaries from multiple sources" do
      entries = described_class.all

      # Should have Hunspell dictionaries
      hunspell = entries.select(&:hunspell?)
      expect(hunspell).not_to be_empty

      # Should have plain text dictionaries
      plain_text = entries.select(&:plain_text?)
      expect(plain_text).not_to be_empty
    end
  end

  describe ".find" do
    context "when dictionary exists" do
      it "finds dictionary by exact code" do
        entry = described_class.find("en-GB")

        expect(entry).not_to be_nil
        expect(entry.code).to eq("en-GB")
        expect(entry.name).to include("British")
        expect(entry.format).to eq(:hunspell)
      end

      it "finds dictionary with underscore notation" do
        entry = described_class.find(:en_GB)

        expect(entry).not_to be_nil
        expect(entry.code).to eq("en-GB")
      end

      it "is case-insensitive" do
        entry1 = described_class.find("en-gb")
        entry2 = described_class.find("EN-GB")
        entry3 = described_class.find("En-Gb")

        expect(entry1.code).to eq(entry2.code)
        expect(entry2.code).to eq(entry3.code)
      end
    end

    context "when dictionary does not exist" do
      it "returns nil for unknown code" do
        entry = described_class.find("xx-YY")

        expect(entry).to be_nil
      end

      it "returns nil for empty string" do
        entry = described_class.find("")

        expect(entry).to be_nil
      end
    end
  end

  describe ".by_language" do
    it "returns all dictionaries for a language" do
      entries = described_class.by_language("en")

      expect(entries).to be_an(Array)
      expect(entries.size).to be >= 9  # en, en-GB, en-CA, en-AU, en-ZA, + unix-words
      expect(entries.map(&:language).uniq).to eq(["en"])
    end

    it "is case-insensitive" do
      entries1 = described_class.by_language("en")
      entries2 = described_class.by_language("EN")
      entries3 = described_class.by_language("En")

      expect(entries1.size).to eq(entries2.size)
      expect(entries2.size).to eq(entries3.size)
    end

    it "returns empty array for unknown language" do
      entries = described_class.by_language("xx")

      expect(entries).to eq([])
    end
  end

  describe ".by_format" do
    it "returns all Hunspell dictionaries" do
      entries = described_class.by_format(:hunspell)

      expect(entries).to be_an(Array)
      expect(entries).not_to be_empty
      expect(entries.all?(&:hunspell?)).to be true
    end

    it "returns all plain text dictionaries" do
      entries = described_class.by_format(:plain_text)

      expect(entries).to be_an(Array)
      expect(entries).not_to be_empty
      expect(entries.all?(&:plain_text?)).to be true
    end
  end

  describe ".by_license" do
    it "returns GPL dictionaries" do
      entries = described_class.by_license("GPL")

      expect(entries).to be_an(Array)
      expect(entries).not_to be_empty
      expect(entries.first.license).to include("GPL")
    end

    it "returns Public Domain dictionaries" do
      entries = described_class.by_license("Public Domain")

      expect(entries).to be_an(Array)
      expect(entries.size).to be >= 4  # unix-words
      expect(entries.first.license).to include("Public Domain")
    end
  end

  describe ".hunspell" do
    it "returns all Hunspell dictionaries" do
      entries = described_class.hunspell

      expect(entries).to be_an(Array)
      expect(entries.size).to be > 80
      expect(entries.all?(&:hunspell?)).to be true
    end
  end

  describe ".plain_text" do
    it "returns all plain text dictionaries" do
      entries = described_class.plain_text

      expect(entries).to be_an(Array)
      expect(entries.size).to eq(4)  # web2, web2a, connectives, propernames
      expect(entries.all?(&:plain_text?)).to be true
    end
  end

  describe ".statistics" do
    it "returns catalog statistics" do
      stats = described_class.statistics

      expect(stats).to include(
        total: be_a(Integer),
        hunspell: be_a(Integer),
        plain_text: be_a(Integer),
        languages: be_a(Integer),
        total_words: be_a(Integer),
        formats: be_a(Hash),
        licenses: be_a(Hash)
      )
    end

    it "has correct counts" do
      stats = described_class.statistics

      expect(stats[:total]).to eq(stats[:hunspell] + stats[:plain_text])
      expect(stats[:total]).to be >= 89
      expect(stats[:languages]).to be >= 50
      expect(stats[:total_words]).to be > 20_000_000
    end
  end

  describe ".languages" do
    it "returns array of unique language codes" do
      languages = described_class.languages

      expect(languages).to be_an(Array)
      expect(languages).to include("en", "de", "es", "fr", "ru")
      expect(languages.uniq).to eq(languages)  # All unique
    end
  end

  describe ".licenses" do
    it "returns array of unique license types" do
      licenses = described_class.licenses

      expect(licenses).to be_an(Array)
      expect(licenses).to include("GPL", "Public Domain")
    end
  end

  describe Kotoshu::Dictionaries::Catalog::DictionaryEntry do
    let(:entry) do
      described_class.new(
        code: "en-GB",
        name: "British English (ise)",
        language: "en",
        region: "GB",
        format: :hunspell,
        source: "SCOWL",
        license: "LGPL/MPL/GPL",
        word_count: 450_000,
        dic_url: "https://example.com/index.dic",
        aff_url: "https://example.com/index.aff",
        metadata: { test: true }
      )
    end

    describe "#initialize" do
      it "creates a valid entry" do
        expect(entry.code).to eq("en-GB")
        expect(entry.name).to eq("British English (ise)")
        expect(entry.language).to eq("en")
        expect(entry.region).to eq("GB")
        expect(entry.format).to eq(:hunspell)
        expect(entry.source).to eq("SCOWL")
        expect(entry.license).to eq("LGPL/MPL/GPL")
        expect(entry.word_count).to eq(450_000)
      end

      it "freezes the entry" do
        expect(entry).to be_frozen
      end
    end

    describe "#description" do
      it "returns human-readable description" do
        expect(entry.description).to include("British English")
        expect(entry.description).to include("450000")
      end

      context "without region" do
        let(:entry_no_region) do
          described_class.new(
            code: "en",
            name: "US English",
            language: "en",
            region: nil,
            format: :hunspell,
            source: "SCOWL",
            license: "GPL",
            word_count: 500_000,
            dic_url: "https://example.com/index.dic",
            aff_url: "https://example.com/index.aff"
          )
        end

        it "returns description without region" do
          expect(entry_no_region.description).to eq("US English - 500000 words")
        end
      end
    end

    describe "#hunspell?" do
      it "returns true for Hunspell format" do
        expect(entry.hunspell?).to be true
      end

      it "returns false for plain text format" do
        plain_entry = described_class.new(
          code: "test",
          name: "Test",
          language: "en",
          format: :plain_text,
          source: "Test",
          license: "MIT",
          word_count: 100,
          dic_url: "https://example.com/words.txt"
        )

        expect(plain_entry.hunspell?).to be false
      end
    end

    describe "#plain_text?" do
      it "returns false for Hunspell format" do
        expect(entry.plain_text?).to be false
      end
    end
  end
end
