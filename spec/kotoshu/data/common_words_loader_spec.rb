# frozen_string_literal: true

require "spec_helper"
require "json"
require "tmpdir"

RSpec.describe Kotoshu::Data::CommonWordsLoader do
  describe ".load_from_frequency_file" do
    def write_frequency(dir, payload)
      path = File.join(dir, "frequency.json")
      File.write(path, JSON.generate(payload))
      path
    end

    it "parses Kelly format into cumulative tiers" do
      Dir.mktmpdir do |dir|
        path = write_frequency(dir, tiers: {
                                 top_50: { words: %w[the] },
                                 top_200: { words: %w[house] },
                                 top_1000: { words: %w[zebra] }
                               })

        result = described_class.load_from_frequency_file(path)

        expect(result[:tiers][:top_50]).to contain_exactly("the")
        expect(result[:tiers][:top_200]).to contain_exactly("the", "house")
        expect(result[:tiers][:top_1000]).to contain_exactly("the", "house", "zebra")
      end
    end

    it "accepts wiki-unigram-shape tiers (plain word lists) (plan C6)" do
      Dir.mktmpdir do |dir|
        path = write_frequency(dir, tiers: { top_50: %w[the], top_200: [], top_1000: %w[the] })

        result = described_class.load_from_frequency_file(path)

        # Kelly format (hash with 'words') AND plain word lists both
        # accepted; wiki-unigram producers emit the latter.
        expect(result[:tiers][:top_50]).to contain_exactly("the")
        expect(result[:tiers][:top_1000]).to contain_exactly("the")
      end
    end

    it "tolerates partially Kelly-shaped tiers" do
      Dir.mktmpdir do |dir|
        path = write_frequency(dir, tiers: {
                                 top_50: { words: %w[the] },
                                 top_200: %w[also-a-plain-list]
                               })

        result = described_class.load_from_frequency_file(path)

        expect(result[:tiers][:top_50]).to contain_exactly("the")
        # top_200 is cumulative: top_50 + top_200
        expect(result[:tiers][:top_200]).to contain_exactly("the", "also-a-plain-list")
      end
    end

    it "returns empty tiers when the file is missing" do
      result = described_class.load_from_frequency_file("/nonexistent/frequency.json")

      expect(result[:tiers][:top_1000]).to be_empty
    end
  end
end
