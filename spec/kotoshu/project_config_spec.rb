# frozen_string_literal: true

require "kotoshu/project_config"
require "tmpdir"

RSpec.describe Kotoshu::ProjectConfig do
  describe ".load" do
    it "returns nil when no config file exists" do
      # Test in a temporary directory without .kotoshu
      Dir.mktmpdir do |dir|
        result = described_class.load(dir)
        expect(result).to be_nil
      end
    end

    it "returns config hash when config exists" do
      Dir.mktmpdir do |dir|
        config_file = File.join(dir, ".kotoshu")
        File.write(config_file, "dictionary: en-GB\nignore_words:\n  - github\n")

        result = described_class.load(dir)
        expect(result).not_to be_nil
        expect(result["dictionary"]).to eq("en-GB")
      end
    end
  end

  describe ".ignore_patterns" do
    it "returns empty hash when no config" do
      Dir.mktmpdir do |dir|
        result = described_class.ignore_patterns(dir)
        expect(result[:words]).to eq([])
        expect(result[:patterns]).to eq([])
      end
    end

    it "parses ignore patterns as regex" do
      Dir.mktmpdir do |dir|
        config_file = File.join(dir, ".kotoshu")
        File.write(config_file, "ignore_patterns:\n  - /https?:\\/\\/\\S+/\n")

        result = described_class.ignore_patterns(dir)
        expect(result[:patterns].size).to eq(1)
        expect(result[:patterns].first).to be_a(Regexp)
      end
    end
  end

  describe ".exists?" do
    it "returns true when .kotoshu exists" do
      Dir.mktmpdir do |dir|
        expect(described_class.exists?(dir)).to be false

        File.write(File.join(dir, ".kotoshu"), "")
        expect(described_class.exists?(dir)).to be true
      end
    end
  end
end
