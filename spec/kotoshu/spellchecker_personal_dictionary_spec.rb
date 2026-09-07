# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

# The personal dictionary in the check path (plan 105).
#
# `kotoshu personal add recieve` then `kotoshu check` must not flag the
# word: Spellchecker#check drops personal-dictionary words at result
# assembly with the same semantics the LSP applies to diagnostics —
# case-insensitive, no suppression metadata, suggestions unaffected.
# These specs use a real tmpdir-backed personal.dic — no doubles.
RSpec.describe "Spellchecker#check with the personal dictionary" do
  let(:tmpdir) { Dir.mktmpdir("kotoshu-personal-check") }
  let(:personal_dic) { File.join(tmpdir, "personal.dic") }

  around do |example|
    original = ENV.fetch("KOTOSHU_PERSONAL_DIC", nil)
    ENV["KOTOSHU_PERSONAL_DIC"] = personal_dic
    begin
      example.run
    ensure
      ENV["KOTOSHU_PERSONAL_DIC"] = original
    end
  end

  after { FileUtils.rm_rf(tmpdir) if File.exist?(tmpdir) }

  def spellchecker(dictionary_path: "spec/fixtures/words.txt",
                   dictionary_type: :plain_text,
                   language: "en-US",
                   **kwargs)
    Kotoshu::Spellchecker.new(
      dictionary_path: dictionary_path,
      dictionary_type: dictionary_type,
      language: language,
      **kwargs
    )
  end

  describe "add-then-check round trip" do
    it "does not flag a word that was just added" do
      Kotoshu::PersonalDictionary.add_word("wrold")

      result = spellchecker.check("hello wrold")

      expect(result.success?).to be true
      expect(result.errors).to be_empty
    end

    it "is case-insensitive in both directions" do
      Kotoshu::PersonalDictionary.add_word("WROLD")

      result = spellchecker.check("Hello Wrold")

      expect(result.success?).to be true
    end

    it "still counts the personal word toward word_count" do
      Kotoshu::PersonalDictionary.add_word("wrold")

      result = spellchecker.check("hello wrold")

      expect(result.word_count).to eq(2)
    end

    it "keeps flagging other misspellings in the same text" do
      Kotoshu::PersonalDictionary.add_word("wrold")

      result = spellchecker.check("wrold helo")

      expect(result.errors.map(&:word)).to eq(["helo"])
    end

    it "leaves no suppression metadata on the remaining errors" do
      Kotoshu::PersonalDictionary.add_word("wrold")

      result = spellchecker.check("wrold helo")

      expect(result.suppressed_count).to eq(0)
      expect(result.errors.first.suppressed?).to be false
      expect(result.errors.first.suppressed_by).to be_nil
    end
  end

  describe "loading semantics" do
    it "loads the personal dictionary once per process (no hot reload)" do
      checker = spellchecker
      expect(checker.check("hello wrold").errors.map(&:word)).to eq(["wrold"])

      Kotoshu::PersonalDictionary.add_word("wrold")

      # Same instance, snapshot taken on the first check: still flagged.
      expect(checker.check("hello wrold").errors.map(&:word)).to eq(["wrold"])

      # A fresh spellchecker (the next process) reads the addition.
      expect(spellchecker.check("hello wrold").success?).to be true
    end
  end

  describe "opt-out" do
    before { Kotoshu::PersonalDictionary.add_word("wrold") }

    it "flags the word again with personal_dictionary: false" do
      result = spellchecker(personal_dictionary: false).check("hello wrold")

      expect(result.failed?).to be true
      expect(result.errors.map(&:word)).to eq(["wrold"])
    end

    it "flags the word again with KOTOSHU_PERSONAL_DICTIONARY=false" do
      ENV["KOTOSHU_PERSONAL_DICTIONARY"] = "false"
      begin
        result = spellchecker.check("hello wrold")

        expect(result.failed?).to be true
        expect(result.errors.map(&:word)).to eq(["wrold"])
      ensure
        ENV.delete("KOTOSHU_PERSONAL_DICTIONARY")
      end
    end

    it "reads the configuration at load time, not at construction" do
      checker = spellchecker
      Kotoshu::PersonalDictionary.add_word("helo")
      checker.config.personal_dictionary = false

      result = checker.check("wrold helo")

      expect(result.errors.map(&:word)).to contain_exactly("wrold", "helo")
    end
  end

  describe "suggest stays untouched" do
    it "still suggests corrections for a personal word" do
      Kotoshu::PersonalDictionary.add_word("wrold")

      suggestions = spellchecker.suggest("wrold")

      expect(suggestions.to_words).to include("world")
    end

    it "still answers correct? false for a personal word" do
      Kotoshu::PersonalDictionary.add_word("wrold")

      expect(spellchecker.correct?("wrold")).to be false
    end
  end

  describe "with no personal dictionary on disk" do
    it "behaves exactly as before" do
      result = spellchecker.check("hello wrold")

      expect(result.errors.map(&:word)).to eq(["wrold"])
    end
  end
end
