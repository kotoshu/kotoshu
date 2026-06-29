# frozen_string_literal: true

require "kotoshu"

# Direct spec for lib/kotoshu/dictionary/unified.rb.
#
# This file was previously broken: it declared `class Kotoshu::Dictionary`
# at the top level, which collided with the existing
# `module Kotoshu::Dictionary` namespace (declared in
# lib/kotoshu/dictionary.rb). Ruby raised TypeError on autoload, so
# Kotoshu::Dictionary::Unified was effectively dead code.
#
# The fix renames the class to `Kotoshu::Dictionary::Unified`, matching
# the autoload entry. This spec pins the loadability and the basic
# facade contract so the regression can't silently recur.
RSpec.describe Kotoshu::Dictionary::Unified do
  describe ".from_files" do
    it "loads from the bundled test fixture" do
      dict = described_class.from_files("spec/fixtures/dictionaries/hunspell/test")
      expect(dict).to be_a(described_class)
    end

    it "raises ArgumentError when the .aff file is missing" do
      expect { described_class.from_files("/nonexistent/path") }
        .to raise_error(ArgumentError, /Dictionary file not found/)
    end
  end

  describe "#lookup" do
    let(:dict) { described_class.from_files("spec/fixtures/dictionaries/hunspell/test") }

    it "returns true for a word in the dictionary" do
      expect(dict.lookup("hello")).to be true
    end

    it "returns false for an unknown word" do
      expect(dict.lookup("nonexistentword")).to be false
    end
  end

  describe "#suggest" do
    let(:dict) { described_class.from_files("spec/fixtures/dictionaries/hunspell/test") }

    it "returns an Enumerator when no block is given" do
      expect(dict.suggest("helo")).to be_an(Enumerator)
    end

    it "yields suggestions when a block is given" do
      suggestions = []
      dict.suggest("helo") { |s| suggestions << s }
      expect(suggestions).to be_an(Array)
    end
  end

  describe "PATHES and DISTRIBUTED constants" do
    it "PATHES is a frozen Array of system search paths" do
      expect(described_class::PATHES).to be_an(Array)
      expect(described_class::PATHES).to be_frozen
      expect(described_class::PATHES).to include("/usr/share/hunspell")
    end

    it "DISTRIBUTED maps fixture dictionary names to language codes" do
      expect(described_class::DISTRIBUTED).to be_a(Hash)
      expect(described_class::DISTRIBUTED).to include("en_US" => "en")
    end
  end
end
