# frozen_string_literal: true

require_relative "../../../lib/kotoshu/configuration/builder"

RSpec.describe Kotoshu::Configuration::Builder do
  describe ".build" do
    it "creates a configuration with defaults" do
      config = described_class.build

      expect(config.language).to eq("en-US")
      expect(config.max_suggestions).to eq(10)
      expect(config.case_sensitive).to be false
    end

    it "creates configuration using block syntax" do
      config = described_class.build do |b|
        b.dictionary_path = "words.txt"
        b.language = "en-GB"
        b.max_suggestions = 15
      end

      expect(config.dictionary_path).to eq("words.txt")
      expect(config.language).to eq("en-GB")
      expect(config.max_suggestions).to eq(15)
    end

    it "creates immutable configuration" do
      config = described_class.build { |b| b.language = "en-GB" }

      expect(config).to be_frozen
      expect { config.language = "en-US" }.to raise_error(FrozenError)
    end

    it "is thread-safe for concurrent use" do
      threads = 10.times.map do
        Thread.new do
          described_class.build do |b|
            b.language = "en-GB"
            b.max_suggestions = 5
          end
        end
      end

      configs = threads.map(&:value)
      expect(configs).to all(be_frozen)
      expect(configs.map(&:language)).to all(eq("en-GB"))
    end
  end

  describe "backward compatibility" do
    it "works with existing Configuration.new API" do
      config1 = Kotoshu::Configuration.new(language: "en-GB")
      config2 = described_class.build { |b| b.language = "en-GB" }

      expect(config1.language).to eq(config2.language)
    end

    it "supports dictionary_path assignment" do
      config = described_class.build do |b|
        b.dictionary_path = "/usr/share/dict/words"
        b.dictionary_type = :unix_words
      end

      expect(config.dictionary_path).to eq("/usr/share/dict/words")
      expect(config.dictionary_type).to eq(:unix_words)
    end

    it "supports custom_words" do
      config = described_class.build do |b|
        b.custom_words = %w[Kotoshu GitHub]
      end

      expect(config.custom_words).to eq(%w[Kotoshu GitHub])
    end

    it "supports boolean flags" do
      config = described_class.build do |b|
        b.case_sensitive = true
        b.verbose = true
      end

      expect(config.case_sensitive).to be true
      expect(config.verbose).to be true
    end
  end

  describe "builder methods" do
    it "provides fluent setter methods" do
      builder = described_class.new
      builder.with_dictionary_path("words.txt")
      builder.with_language("en-GB")
      builder.with_max_suggestions(15)

      config = builder.to_config

      expect(config.dictionary_path).to eq("words.txt")
      expect(config.language).to eq("en-GB")
      expect(config.max_suggestions).to eq(15)
    end
  end
end
