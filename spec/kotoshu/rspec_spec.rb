# frozen_string_literal: true

require "spec_helper"
require "fileutils"
require "tmpdir"
require "kotoshu/rspec"

# RSpec matcher specs (plan 89, item 2): real matchers against the
# real engine, asserting the real failure messages.
RSpec.describe Kotoshu::Rspec::Matchers do
  include described_class

  EN_AFF = File.expand_path("../integrational/fixtures/en_US.aff", __dir__)
  EN_DIC = File.expand_path("../integrational/fixtures/en_US.dic", __dir__)

  before(:all) do
    skip "en_US fixtures missing" unless File.exist?(EN_AFF) && File.exist?(EN_DIC)
    @dir = Dir.mktmpdir
    cache_dir = File.join(@dir, "cache", "languages", "en", "spelling")
    FileUtils.mkdir_p(cache_dir)
    FileUtils.cp(EN_AFF, File.join(cache_dir, "index.aff"))
    FileUtils.cp(EN_DIC, File.join(cache_dir, "index.dic"))
    File.write(File.join(cache_dir, "metadata.json"), {
      "language" => "en",
      "type" => "spelling",
      "version" => "2026-01-01T00:00:00Z",
      "cached_at" => Time.now.utc.iso8601,
      "source" => "fixture"
    }.to_json)
    @old_env = %w[KOTOSHU_CACHE_PATH XDG_CONFIG_HOME XDG_DATA_HOME].to_h { |k| [k, ENV.fetch(k, nil)] }
    ENV["KOTOSHU_CACHE_PATH"] = File.join(@dir, "cache")
    ENV["XDG_CONFIG_HOME"] = File.join(@dir, "config")
    ENV["XDG_DATA_HOME"] = File.join(@dir, "local")
    Kotoshu::Configuration.reset
    Kotoshu.reset_spellchecker
  end

  after(:all) do
    Kotoshu::Configuration.reset
    Kotoshu.reset_spellchecker
    @old_env&.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    FileUtils.remove_entry(@dir) if @dir
  end

  describe "#expect_words" do
    it "returns a real expectation target composable with .to" do
      expect(expect_words("hello", "world")).to respond_to(:to)
    end
  end

  describe "all_be_spelled_correctly" do
    it "passes when every word is correct" do
      expect_words("hello", "world").to all_be_spelled_correctly
    end

    it "fails naming the misspelled words with suggestions" do
      matcher = all_be_spelled_correctly
      expect(matcher.matches?(%w[hello helo])).to be(false)

      message = matcher.failure_message
      expect(message).to include("expected all words to be spelled correctly")
      expect(message).to include('"helo"')
    end

    it "negates honestly" do
      matcher = all_be_spelled_correctly
      expect(matcher.matches?(%w[hello])).to be(true)
      expect(matcher.failure_message_when_negated).to eq(
        "expected some words to be misspelled, but all were correct"
      )
    end
  end

  describe "be_spelled_correctly" do
    it "passes for a correct word" do
      expect("hello").to be_spelled_correctly
    end

    it "fails for a misspelled word" do
      matcher = be_spelled_correctly
      expect(matcher.matches?("helo")).to be(false)
      expect(matcher.failure_message).to include('"helo"')
    end

    it "checks whole documents when the text has whitespace" do
      matcher = be_spelled_correctly
      expect(matcher.matches?("hello wrold")).to be(false)
      expect(matcher.failure_message).to include("expected the document")
      expect(matcher.failure_message).to include('"wrold"')
    end

    it "passes for a clean document" do
      expect("hello world").to be_spelled_correctly
    end

    it "negates honestly for documents" do
      matcher = be_spelled_correctly
      expect(matcher.matches?("hello world")).to be(true)
      expect(matcher.failure_message_when_negated).to eq(
        "expected the document to have misspellings, but it is clean"
      )
    end

    it "accepts a language option" do
      matcher = be_spelled_correctly(in: "en")
      expect(matcher.matches?("hello")).to be(true)
    end
  end

  describe "#expect_document" do
    it "checks the file contents as a document" do
      path = File.join(@dir, "doc.txt")
      File.write(path, "hello world\n")

      expect_document(path).to be_spelled_correctly
    end
  end
end
