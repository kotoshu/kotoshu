# frozen_string_literal: true

require "kotoshu"

# Direct spec for Readers::ConditionChecker — the abstract affix-condition
# checker and its concrete subclasses (Passthrough, LatinScript).
#
# Hunspell affix rules carry regex-like conditions that the stem must
# satisfy before an affix applies. Different scripts need different
# interpretations. Had no direct spec — only exercised indirectly via
# Hunspell fixture tests.
RSpec.describe Kotoshu::Readers::ConditionChecker do
  describe ".compile" do
    it "returns a LatinScriptConditionChecker for :latin script" do
      checker = described_class.compile("[^y]", script: :latin, type: :suffix)
      expect(checker).to be_a(Kotoshu::Readers::LatinScriptConditionChecker)
    end

    it "returns a PassthroughConditionChecker for unsupported scripts" do
      checker = described_class.compile("[^y]", script: :arabic, type: :suffix)
      expect(checker).to be_a(Kotoshu::Readers::PassthroughConditionChecker)
    end

    it "defaults to :latin script" do
      checker = described_class.compile("[^y]", type: :suffix)
      expect(checker).to be_a(Kotoshu::Readers::LatinScriptConditionChecker)
    end
  end

  describe "#matches? (abstract)" do
    it "raises NotImplementedError on the base class" do
      expect do
        described_class.new.matches?("anything")
      end.to raise_error(NotImplementedError, /must implement #matches\?/)
    end
  end
end

RSpec.describe Kotoshu::Readers::PassthroughConditionChecker do
  describe "#matches?" do
    it "always returns true" do
      checker = described_class.new
      expect(checker.matches?("anything")).to be true
      expect(checker.matches?("")).to be true
      expect(checker.matches?("[^y]")).to be true
    end
  end
end

RSpec.describe Kotoshu::Readers::LatinScriptConditionChecker do
  describe ".compile" do
    it "builds a suffix checker (anchored at end)" do
      checker = described_class.compile("y", type: :suffix)
      expect(checker.anchor).to eq(:ending)
      expect(checker.type).to eq(:suffix)
    end

    it "builds a prefix checker (anchored at start)" do
      checker = described_class.compile("ij", type: :prefix)
      expect(checker.anchor).to eq(:start)
      expect(checker.type).to eq(:prefix)
    end

    it "exposes condition, type, anchor, and pattern readers" do
      checker = described_class.compile("[^y]", type: :suffix)
      expect(checker.condition).to eq("[^y]")
      expect(checker.pattern).to be_a(Regexp)
    end
  end

  describe "#matches? for suffix conditions" do
    it "'.' matches any stem" do
      checker = described_class.compile(".", type: :suffix)
      expect(checker.matches?("anything")).to be true
      expect(checker.matches?("x")).to be true
    end

    it "'y' matches stems ending in y" do
      checker = described_class.compile("y", type: :suffix)
      expect(checker.matches?("fly")).to be true
      expect(checker.matches?("try")).to be true
      expect(checker.matches?("hello")).to be false
    end

    it "'[^y]' matches stems NOT ending in y" do
      checker = described_class.compile("[^y]", type: :suffix)
      expect(checker.matches?("hello")).to be true
      expect(checker.matches?("fly")).to be false
    end

    it "'[aeiou]y' matches stems ending in vowel + y" do
      checker = described_class.compile("[aeiou]y", type: :suffix)
      expect(checker.matches?("stay")).to be true # a + y
      expect(checker.matches?("key")).to be true  # e + y
      expect(checker.matches?("boy")).to be true  # o + y
      expect(checker.matches?("fly")).to be false # consonant + y
    end

    it "handles nil/empty condition as match-any" do
      nil_checker = described_class.compile(nil, type: :suffix)
      empty_checker = described_class.compile("", type: :suffix)
      expect(nil_checker.matches?("anything")).to be true
      expect(empty_checker.matches?("anything")).to be true
    end
  end

  describe "#matches? for prefix conditions" do
    it "'ij' matches stems starting with ij" do
      checker = described_class.compile("ij", type: :prefix)
      expect(checker.matches?("ijsland")).to be true
      expect(checker.matches?("island")).to be false
    end

    it "'wr.' matches stems starting with wr + any char" do
      checker = described_class.compile("wr.", type: :prefix)
      expect(checker.matches?("write")).to be true
      expect(checker.matches?("wrong")).to be true
      expect(checker.matches?("wrap")).to be true
      expect(checker.matches?("wri")).to be true
      expect(checker.matches?("wr")).to be false # needs at least 3 chars
    end
  end

  describe "distinguishing prefix vs suffix anchoring with the same condition" do
    it "the same 'ab' condition matches different stems as prefix vs suffix" do
      as_prefix = described_class.compile("ab", type: :prefix)
      as_suffix = described_class.compile("ab", type: :suffix)

      # 'abxyz' matches the prefix 'ab' but not the suffix 'ab'.
      expect(as_prefix.matches?("abxyz")).to be true
      expect(as_suffix.matches?("abxyz")).to be false

      # 'xyzab' matches the suffix 'ab' but not the prefix 'ab'.
      expect(as_prefix.matches?("xyzab")).to be false
      expect(as_suffix.matches?("xyzab")).to be true
    end
  end

  describe "literal dash handling" do
    it "treats '-' as a literal char, not a range" do
      # The condition "ab-cd" should be parsed with dashes escaped so it
      # matches the literal string "ab-cd", not interpreted as a range.
      checker = described_class.compile("a-e", type: :suffix)
      expect(checker.matches?("testa-e")).to be true
      # Should not match words ending in any of a,b,c,d,e (which would
      # happen if '-' were treated as a range inside the regex).
      expect(checker.matches?("testa")).to be false
    end
  end
end
