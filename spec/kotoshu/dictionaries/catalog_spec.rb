# frozen_string_literal: true

require "kotoshu"

# Direct spec for Dictionaries::Catalog — the registry of all
# downloadable dictionaries from kotoshu/dictionaries.
#
# The Catalog is a pure-data class: ALL_DICTIONARIES is a frozen
# array of Hashes, mapped to DictionaryEntry structs at load time.
# No IO, no network — the specs pin the catalog's query API.
RSpec.describe Kotoshu::Dictionaries::Catalog do
  describe Kotoshu::Dictionaries::Catalog::DictionaryEntry do
    let(:entry) do
      described_class.new(
        code: "en-US", name: "American English", language: "en",
        region: "US", format: :hunspell, source: "SCROLL",
        license: "LGPL/MPL/GPL", word_count: 49_568,
        dic_url: "https://example.com/index.dic",
        aff_url: "https://example.com/index.aff",
        metadata: { source_file: "index.dic" }
      )
    end

    it "exposes all constructor fields as readers" do
      expect(entry.code).to eq("en-US")
      expect(entry.name).to eq("American English")
      expect(entry.language).to eq("en")
      expect(entry.region).to eq("US")
      expect(entry.format).to eq(:hunspell)
      expect(entry.source).to eq("SCROLL")
      expect(entry.license).to eq("LGPL/MPL/GPL")
      expect(entry.word_count).to eq(49_568)
      expect(entry.dic_url).to eq("https://example.com/index.dic")
      expect(entry.aff_url).to eq("https://example.com/index.aff")
      expect(entry.metadata).to eq(source_file: "index.dic")
    end

    it "is frozen" do
      expect(entry).to be_frozen
    end

    it "#hunspell? is true for hunspell format" do
      expect(entry.hunspell?).to be true
      expect(entry.plain_text?).to be false
    end

    it "#plain_text? is true for plain_text format" do
      pt = described_class.new(
        code: "en-web2", name: "Webster", language: "en",
        format: :plain_text, source: "FreeBSD", license: "PD",
        word_count: 200_000, dic_url: "https://example.com/web2.txt"
      )
      expect(pt.plain_text?).to be true
      expect(pt.hunspell?).to be false
    end

    it "#description includes name, region, and word count" do
      expect(entry.description).to eq("American English (US) - 49568 words")
    end

    it "#description omits region when nil" do
      no_region = described_class.new(
        code: "en", name: "English", language: "en",
        format: :plain_text, source: "src", license: "MIT",
        word_count: 100, dic_url: "https://example.com/words.txt"
      )
      expect(no_region.description).to eq("English - 100 words")
    end
  end

  describe ".all" do
    it "returns a frozen array of DictionaryEntry instances" do
      entries = described_class.all
      expect(entries).to be_an(Array)
      expect(entries).to be_frozen
      expect(entries).not_to be_empty
      expect(entries).to all(be_a(Kotoshu::Dictionaries::Catalog::DictionaryEntry))
    end
  end

  describe ".find" do
    it "finds a dictionary by exact code" do
      entry = described_class.find("en")
      expect(entry).not_to be_nil
      expect(entry.language).to eq("en")
    end

    it "returns nil for an unknown code" do
      expect(described_class.find("xx-XX")).to be_nil
    end
  end

  describe ".by_language" do
    it "returns all dictionaries for a language" do
      entries = described_class.by_language("en")
      expect(entries).not_to be_empty
      expect(entries).to all(satisfy { |e| e.language == "en" })
    end

    it "returns [] for an unknown language" do
      expect(described_class.by_language("xx")).to eq([])
    end
  end

  describe ".by_format / .hunspell / .plain_text" do
    it ".hunspell returns only hunspell-format entries" do
      entries = described_class.hunspell
      expect(entries).not_to be_empty
      expect(entries).to all(satisfy(&:hunspell?))
    end

    it ".plain_text returns only plain_text-format entries" do
      entries = described_class.plain_text
      expect(entries).not_to be_empty
      expect(entries).to all(satisfy(&:plain_text?))
    end

    it ".by_format(:hunspell) equals .hunspell" do
      expect(described_class.by_format(:hunspell)).to eq(described_class.hunspell)
    end
  end

  describe ".by_license" do
    it "returns entries whose license includes the query string" do
      entries = described_class.by_license("GPL")
      expect(entries).not_to be_empty
    end
  end

  describe ".statistics" do
    it "returns a hash with the documented keys" do
      stats = described_class.statistics
      expect(stats).to include(:total, :hunspell, :plain_text, :languages,
                               :total_words, :formats, :licenses)
      expect(stats[:total]).to be > 0
      expect(stats[:hunspell] + stats[:plain_text]).to eq(stats[:total])
    end
  end
end
