# frozen_string_literal: true

require "kotoshu"

# Specs for Configuration as an injectable dependency (TODO.impl/56
# T5.2 stepping stone).
#
# The full T5.2 goal is to drop the Configuration.instance singleton
# entirely and require every caller to pass an explicit Configuration.
# This PR adds the writer that makes the singleton injectable (so
# tests can swap configurations without process-global state bleeding
# across examples), plus explicit specs covering both the singleton
# path and the explicit-config path through Spellchecker.
RSpec.describe "Configuration as data" do
  after { Kotoshu::Configuration.reset }

  describe "Kotoshu.configuration / Kotoshu.configuration=" do
    it "exposes the process-default Configuration" do
      expect(Kotoshu.configuration).to be_a(Kotoshu::Configuration)
    end

    it "configuration= replaces the process default" do
      replacement = Kotoshu::Configuration.new
      replacement.max_suggestions = 99
      Kotoshu.configuration = replacement
      expect(Kotoshu.configuration.max_suggestions).to eq(99)
      expect(Kotoshu.configuration).to be(replacement)
    end

    it "configuration= rejects a non-Configuration argument" do
      expect { Kotoshu.configuration = "not a config" }
        .to raise_error(ArgumentError, /must be a Configuration instance/)
    end

    it "Configuration.instance= also replaces the default" do
      replacement = Kotoshu::Configuration.new
      Kotoshu::Configuration.instance = replacement
      expect(Kotoshu::Configuration.instance).to be(replacement)
    end

    it "Configuration.instance= rejects a non-Configuration argument" do
      expect { Kotoshu::Configuration.instance = nil }
        .to raise_error(ArgumentError, /must be a Configuration/)
    end
  end

  describe "Spellchecker with an explicit Configuration" do
    let(:dictionary) do
      Kotoshu::Dictionary::Custom.new(words: %w[hello world ruby], language_code: "en")
    end

    it "uses the injected Configuration rather than the singleton" do
      config = Kotoshu::Configuration.new
      config.max_suggestions = 7

      spellchecker = Kotoshu::Spellchecker.new(dictionary: dictionary, config: config)

      expect(spellchecker.config).to be(config)
      expect(spellchecker.config.max_suggestions).to eq(7)
    end

    it "falls back to a fresh Configuration when none is given" do
      spellchecker = Kotoshu::Spellchecker.new(dictionary: dictionary)
      expect(spellchecker.config).to be_a(Kotoshu::Configuration)
    end
  end

  describe "Configuration.reset (cleanup)" do
    it "rebuilds the process default from scratch" do
      Kotoshu.configuration.max_suggestions = 42
      Kotoshu::Configuration.reset
      expect(Kotoshu.configuration.max_suggestions).to eq(Kotoshu::Configuration::DEFAULTS[:max_suggestions])
    end
  end
end
