# frozen_string_literal: true

require "kotoshu"

# Direct spec for all Kotoshu exception classes.
#
# Each error class carries structured metadata (paths, keys, hashes)
# that callers and audit logs depend on. This spec pins the public
# contract: the message format and the readers.
RSpec.describe Kotoshu do
  describe "Error" do
    it "is a StandardError" do
      expect(Kotoshu::Error).to be < StandardError
    end

    it "accepts a message" do
      err = Kotoshu::Error.new("boom")
      expect(err.message).to eq("boom")
    end
  end

  describe "DictionaryNotFoundError" do
    it "is a Kotoshu::Error" do
      expect(Kotoshu::DictionaryNotFoundError).to be < Kotoshu::Error
    end

    it "exposes the path reader" do
      err = Kotoshu::DictionaryNotFoundError.new("/path/to/dic.dic")
      expect(err.path).to eq("/path/to/dic.dic")
    end

    it "synthesizes a default message that includes the path" do
      err = Kotoshu::DictionaryNotFoundError.new("/x/y.dic")
      expect(err.message).to eq("Dictionary not found: /x/y.dic")
    end

    it "honours an explicit message override" do
      err = Kotoshu::DictionaryNotFoundError.new("/x/y.dic", "custom")
      expect(err.message).to eq("custom")
    end
  end

  describe "InvalidDictionaryFormatError" do
    it "exposes path and details readers" do
      err = Kotoshu::InvalidDictionaryFormatError.new("/p.dic", "bad header")
      expect(err.path).to eq("/p.dic")
      expect(err.details).to eq("bad header")
    end

    it "includes the path in the message" do
      err = Kotoshu::InvalidDictionaryFormatError.new("/p.dic")
      expect(err.message).to include("/p.dic")
    end

    it "includes the details in the message when given" do
      err = Kotoshu::InvalidDictionaryFormatError.new("/p.dic", "bad header")
      expect(err.message).to include("bad header")
    end

    it "formats cleanly with nil details" do
      err = Kotoshu::InvalidDictionaryFormatError.new("/p.dic")
      expect(err.message).to eq("Invalid dictionary format: /p.dic")
    end
  end

  describe "ConfigurationError" do
    it "exposes the key reader" do
      err = Kotoshu::ConfigurationError.new("bad", key: :dictionary_type)
      expect(err.key).to eq(:dictionary_type)
    end

    it "defaults key to nil" do
      err = Kotoshu::ConfigurationError.new("bad")
      expect(err.key).to be_nil
    end

    it "passes the message through unchanged" do
      err = Kotoshu::ConfigurationError.new("bad value")
      expect(err.message).to eq("bad value")
    end
  end

  describe "SpellcheckError" do
    it "exposes the word reader" do
      err = Kotoshu::SpellcheckError.new("fail", word: "hellp")
      expect(err.word).to eq("hellp")
    end

    it "defaults word to nil" do
      expect(Kotoshu::SpellcheckError.new("fail").word).to be_nil
    end
  end

  describe "AffixRuleError" do
    it "exposes the rule reader" do
      err = Kotoshu::AffixRuleError.new("bad rule", rule: "PFX A Y 1 re")
      expect(err.rule).to eq("PFX A Y 1 re")
    end

    it "defaults rule to nil" do
      expect(Kotoshu::AffixRuleError.new("bad").rule).to be_nil
    end
  end

  describe "ResourceNotCachedError" do
    it "exposes language and resource_type" do
      err = Kotoshu::ResourceNotCachedError.new("en", "model")
      expect(err.language).to eq("en")
      expect(err.resource_type).to eq("model")
    end

    it "mentions the remediation command in the message" do
      err = Kotoshu::ResourceNotCachedError.new("fr", "spelling")
      expect(err.message).to include("fr")
      expect(err.message).to include("kotoshu cache download")
    end
  end

  describe "ResourceNotSetupError" do
    it "exposes language and the default resource_type" do
      err = Kotoshu::ResourceNotSetupError.new("en")
      expect(err.language).to eq("en")
      expect(err.resource_type).to eq("spelling")
    end

    it "accepts an explicit resource_type" do
      err = Kotoshu::ResourceNotSetupError.new("en", "model")
      expect(err.resource_type).to eq("model")
    end

    it "mentions setup in the message" do
      err = Kotoshu::ResourceNotSetupError.new("en")
      expect(err.message).to include("kotoshu setup en")
      expect(err.message).to include("Kotoshu.setup(:en)")
    end
  end

  describe "ResourceResolutionError" do
    it "exposes the language reader" do
      err = Kotoshu::ResourceResolutionError.new("xx", "unsupported")
      expect(err.language).to eq("xx")
    end

    it "formats the message with the reason" do
      err = Kotoshu::ResourceResolutionError.new("xx", "unsupported")
      expect(err.message).to include("xx")
      expect(err.message).to include("unsupported")
    end
  end

  describe "IntegrityError" do
    let(:err) do
      Kotoshu::IntegrityError.new(
        "en/model.onnx",
        expected: "aaa",
        actual: "bbb",
        url: "https://example.com/model.onnx",
        remediation: "Re-download."
      )
    end

    it "exposes all five readers" do
      expect(err.resource_id).to eq("en/model.onnx")
      expect(err.expected).to eq("aaa")
      expect(err.actual).to eq("bbb")
      expect(err.url).to eq("https://example.com/model.onnx")
      expect(err.remediation).to eq("Re-download.")
    end

    it "includes resource_id, expected and actual hashes in the message" do
      expect(err.message).to include("en/model.onnx")
      expect(err.message).to include("sha256=aaa")
      expect(err.message).to include("sha256=bbb")
    end

    it "includes the url when given" do
      expect(err.message).to include("url: https://example.com/model.onnx")
    end

    it "includes the remediation hint when given" do
      expect(err.message).to include("Re-download.")
    end

    it "omits url and remediation segments when nil" do
      bare = Kotoshu::IntegrityError.new(
        "en/dic.dic",
        expected: "x",
        actual: "y"
      )
      expect(bare.message).not_to include("url:")
      expect(bare.message).not_to include("Re-download")
    end
  end

  describe "SuikaUnavailable" do
    it "mentions the gem name in the message" do
      err = Kotoshu::SuikaUnavailable.new
      expect(err.message).to include("suika gem not loaded")
    end

    it "includes the install hint" do
      err = Kotoshu::SuikaUnavailable.new
      expect(err.message).to include("gem install suika")
    end

    it "appends the optional detail when given" do
      err = Kotoshu::SuikaUnavailable.new("load failed")
      expect(err.message).to include("(load failed)")
    end
  end
end
