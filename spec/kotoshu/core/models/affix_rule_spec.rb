# frozen_string_literal: true

require "kotoshu"

# Direct spec for Models::AffixRule — the Hunspell-style affix rule
# value object that powers morphological expansion (prefix/suffix
# stripping and adding).
#
# AffixRule is an immutable, frozen value object that compiles a
# Hunspell condition string into a Regexp. It is the per-rule shape
# parsed from .aff files and consulted during affix-driven suggestion
# generation. Had no direct spec — only exercised indirectly.
RSpec.describe Kotoshu::Models::AffixRule do
  describe "TYPES constant" do
    it "maps :prefix to PFX and :suffix to SFX" do
      expect(described_class::TYPES).to eq(prefix: "PFX", suffix: "SFX")
    end

    it "is frozen" do
      expect(described_class::TYPES).to be_frozen
    end
  end

  describe "#initialize" do
    it "accepts a valid prefix rule" do
      rule = described_class.new(type: :prefix, flag: "A", strip: "", add: "re", condition: ".")
      expect(rule).to be_prefix
    end

    it "accepts a valid suffix rule" do
      rule = described_class.new(type: :suffix, flag: "B", strip: "e", add: "ing", condition: "e")
      expect(rule).to be_suffix
    end

    it "raises ArgumentError for an invalid type" do
      expect do
        described_class.new(type: :infix, flag: "A", strip: "", add: "x")
      end.to raise_error(ArgumentError, /Invalid type: infix/)
    end

    it "raises ArgumentError when flag is empty" do
      expect do
        described_class.new(type: :prefix, flag: "", strip: "", add: "x")
      end.to raise_error(ArgumentError, /Flag cannot be empty/)
    end

    it "raises ArgumentError when flag is nil" do
      expect do
        described_class.new(type: :prefix, flag: nil, strip: "", add: "x")
      end.to raise_error(ArgumentError, /Flag cannot be empty/)
    end

    it "defaults condition to '.' (match-any)" do
      rule = described_class.new(type: :prefix, flag: "A", strip: "", add: "re")
      expect(rule.applies_to?("anything")).to be true
    end

    it "defaults cross_product to false" do
      rule = described_class.new(type: :prefix, flag: "A", strip: "", add: "re")
      expect(rule.cross_product).to be false
    end

    it "freezes the rule on initialization" do
      rule = described_class.new(type: :prefix, flag: "A", strip: "", add: "re")
      expect(rule).to be_frozen
    end

    it "freezes the string attributes" do
      rule = described_class.new(type: :prefix, flag: "A", strip: "x", add: "re")
      expect(rule.flag).to be_frozen
      expect(rule.strip).to be_frozen
      expect(rule.add).to be_frozen
    end

    it "preserves an explicit Regexp condition as-is" do
      regex = /^foo/
      rule = described_class.new(type: :prefix, flag: "A", strip: "", add: "x", condition: regex)
      expect(rule.condition).to be(regex)
    end
  end

  describe "#prefix? / #suffix?" do
    it "prefix? is true for a prefix rule" do
      rule = described_class.new(type: :prefix, flag: "A", strip: "", add: "re")
      expect(rule.prefix?).to be true
      expect(rule.suffix?).to be false
    end

    it "suffix? is true for a suffix rule" do
      rule = described_class.new(type: :suffix, flag: "A", strip: "", add: "ing")
      expect(rule.suffix?).to be true
      expect(rule.prefix?).to be false
    end
  end

  describe "#applies_to?" do
    let(:rule) do
      described_class.new(type: :suffix, flag: "V", strip: "e", add: "ing", condition: "e")
    end

    it "returns true when the word matches the condition" do
      expect(rule.applies_to?("make")).to be true
    end

    it "returns false when the word does not match" do
      expect(rule.applies_to?("song")).to be false
    end

    it "returns false for nil" do
      expect(rule.applies_to?(nil)).to be false
    end

    it "returns false for an empty string" do
      expect(rule.applies_to?("")).to be false
    end
  end

  describe "#apply" do
    context "with a prefix rule" do
      let(:rule) do
        described_class.new(type: :prefix, flag: "A", strip: "", add: "re", condition: ".")
      end

      it "prepends the prefix" do
        expect(rule.apply("do")).to eq("redo")
      end

      it "returns nil when the rule does not apply (strip mismatch)" do
        stripping = described_class.new(type: :prefix, flag: "A", strip: "un", add: "re", condition: ".")
        expect(stripping.apply("do")).to be_nil
      end

      it "strips then adds when strip is non-empty" do
        stripping = described_class.new(type: :prefix, flag: "A", strip: "un", add: "re", condition: ".")
        expect(stripping.apply("undo")).to eq("redo")
      end
    end

    context "with a suffix rule" do
      let(:rule) do
        described_class.new(type: :suffix, flag: "V", strip: "e", add: "ing", condition: "e")
      end

      it "strips the suffix and adds the new one" do
        expect(rule.apply("make")).to eq("making")
      end

      it "returns nil when the rule's condition does not match" do
        expect(rule.apply("song")).to be_nil
      end

      it "returns nil when the strip mismatch fails" do
        # 'song' ends in 'g' not 'e', so strip mismatch.
        expect(rule.apply("song")).to be_nil
      end
    end
  end

  describe "#remove" do
    context "with a prefix rule" do
      let(:rule) do
        described_class.new(type: :prefix, flag: "A", strip: "", add: "re", condition: ".")
      end

      it "removes the prefix and restores the strip" do
        expect(rule.remove("redo")).to eq("do")
      end

      it "returns nil when the word does not start with the added prefix" do
        expect(rule.remove("song")).to be_nil
      end
    end

    context "with a suffix rule" do
      let(:rule) do
        described_class.new(type: :suffix, flag: "V", strip: "e", add: "ing", condition: "e")
      end

      it "removes the suffix and restores the strip" do
        expect(rule.remove("making")).to eq("make")
      end
    end
  end

  describe "#to_hunspell" do
    it "formats a prefix rule as a PFX line" do
      rule = described_class.new(type: :prefix, flag: "A", strip: "", add: "re",
                                 condition: ".", cross_product: true)
      expect(rule.to_hunspell).to eq("PFX A Y 0 re .")
    end

    it "formats a suffix rule as an SFX line" do
      rule = described_class.new(type: :suffix, flag: "V", strip: "e", add: "ing",
                                 condition: "e", cross_product: false)
      expect(rule.to_hunspell).to eq("SFX V N e ing e")
    end

    it "uses 0 for empty strip" do
      rule = described_class.new(type: :suffix, flag: "X", strip: "", add: "s", condition: ".")
      expect(rule.to_hunspell).to include(" 0 s")
    end
  end

  describe "#== / #eql?" do
    it "equals a rule with identical attributes" do
      a = described_class.new(type: :prefix, flag: "A", strip: "", add: "re")
      b = described_class.new(type: :prefix, flag: "A", strip: "", add: "re")
      expect(a).to eq(b)
      expect(a.eql?(b)).to be true
    end

    it "differs when any attribute differs" do
      a = described_class.new(type: :prefix, flag: "A", strip: "", add: "re")
      b = described_class.new(type: :prefix, flag: "B", strip: "", add: "re")
      expect(a).not_to eq(b)
    end

    it "returns false for a non-AffixRule" do
      a = described_class.new(type: :prefix, flag: "A", strip: "", add: "re")
      expect(a).not_to eq("not a rule")
    end
  end

  describe "#hash" do
    it "is consistent for equal rules" do
      a = described_class.new(type: :prefix, flag: "A", strip: "", add: "re")
      b = described_class.new(type: :prefix, flag: "A", strip: "", add: "re")
      expect(a.hash).to eq(b.hash)
    end
  end

  describe "#<=>" do
    it "orders rules by flag" do
      a = described_class.new(type: :prefix, flag: "A", strip: "", add: "re")
      b = described_class.new(type: :prefix, flag: "B", strip: "", add: "re")
      expect([b, a].sort).to eq([a, b])
    end

    it "returns nil when compared to a non-AffixRule" do
      a = described_class.new(type: :prefix, flag: "A", strip: "", add: "re")
      expect(a <=> "not a rule").to be_nil
    end
  end

  describe ".from_hunspell" do
    it "parses a prefix rule line" do
      rule = described_class.from_hunspell("PFX A Y 0 re .", :prefix)
      expect(rule).to be_prefix
      expect(rule.flag).to eq("A")
      expect(rule.strip).to eq("")
      expect(rule.add).to eq("re")
      expect(rule.cross_product).to be true
    end

    it "parses a suffix rule line" do
      rule = described_class.from_hunspell("SFX V N e ing e", :suffix)
      expect(rule).to be_suffix
      expect(rule.flag).to eq("V")
      expect(rule.strip).to eq("e")
      expect(rule.add).to eq("ing")
      expect(rule.cross_product).to be false
    end

    it "treats '0' strip as empty" do
      rule = described_class.from_hunspell("PFX A Y 0 re .", :prefix)
      expect(rule.strip).to eq("")
    end

    it "defaults the condition to '.' when missing" do
      rule = described_class.from_hunspell("PFX A Y 0 re", :prefix)
      expect(rule.condition).to be_a(Regexp)
      expect(rule.applies_to?("anything")).to be true
    end

    it "returns nil when the line is too short" do
      expect(described_class.from_hunspell("PFX A", :prefix)).to be_nil
    end
  end
end
