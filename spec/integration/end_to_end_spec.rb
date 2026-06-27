# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

RSpec.describe "Kotoshu end-to-end", :network do
  around do |ex|
    Dir.mktmpdir do |dir|
      prior = ENV.to_h
      ENV["XDG_CACHE_HOME"] = "#{dir}/cache"
      ENV["XDG_CONFIG_HOME"] = "#{dir}/config"
      ENV["XDG_DATA_HOME"] = "#{dir}/local"
      Kotoshu::Configuration.reset
      Kotoshu.reset_spellchecker
      ex.run
    ensure
      ENV.replace(prior) if prior
      Kotoshu::Configuration.reset
      Kotoshu.reset_spellchecker
    end
  end

  describe "fresh install → setup → use" do
    it "sets up English spelling by downloading from kotoshu/dictionaries" do
      result = Kotoshu.setup(:en, want: %i[spelling])

      expect(result.spelling).to eq(:downloaded).or(eq(:cached))
      expect(Kotoshu.setup?(:en, :spelling)).to be(true)
    end

    it "accepts a correctly-spelled word after setup" do
      Kotoshu.setup(:en, want: %i[spelling])

      expect(Kotoshu.correct?("hello")).to be(true)
    end

    it "rejects a misspelling after setup" do
      Kotoshu.setup(:en, want: %i[spelling])

      expect(Kotoshu.correct?("xyzzq")).to be(false)
    end

    it "suggests corrections for a common typo" do
      Kotoshu.setup(:en, want: %i[spelling])
      suggestions = Kotoshu.suggest("teh")

      expect(suggestions.to_words).to include("the")
    end

    it "checks a document and flags misspellings" do
      Kotoshu.setup(:en, want: %i[spelling])
      result = Kotoshu.check("this is a teh test")

      expect(result.failed?).to be(true)
      expect(result.errors.map(&:word)).to include("teh")
    end
  end

  describe "setup predicate" do
    it "returns false before setup" do
      expect(Kotoshu.setup?(:en)).to be(false)
    end

    it "returns true after setup" do
      Kotoshu.setup(:en, want: %i[spelling])

      expect(Kotoshu.setup?(:en)).to be(true)
    end

    it "returns false for an unrelated language even after another is set up" do
      Kotoshu.setup(:en, want: %i[spelling])

      expect(Kotoshu.setup?(:de)).to be(false)
    end
  end

  describe "two-stage model enforcement" do
    it "raises ResourceNotSetupError on cold correct? without setup" do
      expect { Kotoshu.correct?("hello") }
        .to raise_error(Kotoshu::ResourceNotSetupError)
    end

    it "raises ResourceNotSetupError on cold check without setup" do
      expect { Kotoshu.check("hello world") }
        .to raise_error(Kotoshu::ResourceNotSetupError)
    end
  end

  describe "idempotent setup" do
    it "returns :cached on the second setup without force" do
      Kotoshu.setup(:en, want: %i[spelling])
      second = Kotoshu.setup(:en, want: %i[spelling])

      expect(second.spelling).to eq(:cached)
    end

    it "re-downloads with force: true" do
      Kotoshu.setup(:en, want: %i[spelling])
      second = Kotoshu.setup(:en, want: %i[spelling], force: true)

      expect(second.spelling).to eq(:downloaded)
    end
  end
end
