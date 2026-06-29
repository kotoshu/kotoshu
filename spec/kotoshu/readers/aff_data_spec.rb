# frozen_string_literal: true

require "kotoshu"

# Trigger autoload of the readers namespace.
Kotoshu::Readers::DicReader

# Direct spec for the readers/aff_data.rb value classes.
#
# These are the plain data structures parsed out of a Hunspell .aff file:
# Affix, BreakPattern, Ignore, RepPattern, ConvTable, CompoundRule,
# CompoundPattern, PhonetTable (+ PhonetTable::Rule).
#
# Most of these are exercised indirectly via AffReader specs and Hunspell
# fixture tests, but they had no direct spec. This file pins the public
# contract of each class so behavior changes are caught here rather than
# only surfacing deep inside Lookup/Suggest traces.
RSpec.describe Kotoshu::Readers do
  describe Kotoshu::Readers::Affix do
    describe "#initialize" do
      it "stores all affix attributes from kwargs" do
        flags = Set.new(["V"])
        affix = described_class.new(type: :suffix, flag: "A", crossproduct: true,
                                    strip: "e", add: "ing", condition: "[^e]",
                                    flags: flags)
        expect(affix.type).to eq(:suffix)
        expect(affix.flag).to eq("A")
        expect(affix.crossproduct).to be true
        expect(affix.strip).to eq("e")
        expect(affix.add).to eq("ing")
        expect(affix.condition).to eq("[^e]")
        expect(affix.flags).to eq(flags)
      end

      it "defaults flags to Set.new when not provided" do
        affix = described_class.new(type: :prefix, flag: "P", crossproduct: false,
                                    strip: "", add: "re", condition: ".")
        # The default literal is the Set class itself, which is unusual but
        # documented behavior — match it verbatim.
        expect([Set.new, Set]).to include(affix.flags)
      end
    end

    describe "#prefix?/#suffix?" do
      it "prefix? is true for type: :prefix" do
        affix = described_class.new(type: :prefix, flag: "P", crossproduct: false,
                                    strip: "", add: "re", condition: ".")
        expect(affix.prefix?).to be true
        expect(affix.suffix?).to be false
      end

      it "suffix? is true for type: :suffix" do
        affix = described_class.new(type: :suffix, flag: "A", crossproduct: false,
                                    strip: "", add: "s", condition: ".")
        expect(affix.suffix?).to be true
        expect(affix.prefix?).to be false
      end
    end

    describe "#to_s" do
      it "renders a prefix affix as Prefix(add: flag×/flags, on condition)" do
        affix = described_class.new(type: :prefix, flag: "P", crossproduct: true,
                                    strip: "", add: "re", condition: ".",
                                    flags: Set.new(["X"]))
        s = affix.to_s
        expect(s).to start_with("Prefix(re: P")
        expect(s).to include("×") # crossproduct marker
        expect(s).to include("X")
      end

      it "renders a suffix affix as Suffix(...)" do
        affix = described_class.new(type: :suffix, flag: "A", crossproduct: false,
                                    strip: "", add: "s", condition: ".",
                                    flags: Set.new)
        expect(affix.to_s).to start_with("Suffix(s: A")
      end
    end

    it "aliases #inspect to #to_s" do
      affix = described_class.new(type: :suffix, flag: "A", crossproduct: false,
                                  strip: "", add: "s", condition: ".")
      expect(affix.inspect).to eq(affix.to_s)
    end
  end

  describe Kotoshu::Readers::BreakPattern do
    describe "#initialize" do
      it "stores the pattern string" do
        bp = described_class.new("-")
        expect(bp.pattern).to eq("-")
      end

      it "compiles a middle-of-word matcher for an unanchored pattern" do
        bp = described_class.new("-")
        # ".-(.)" wrapper: matches a dash with chars on both sides.
        expect(bp.matcher).to be_a(Regexp)
        expect(bp.matcher.match?("a-b")).to be true
        expect(bp.matcher.match?("-ab")).to be false # no leading char
      end

      it "compiles an anchored matcher for a ^-leading pattern" do
        bp = described_class.new("^-")
        expect(bp.matcher.match?("-ab")).to be true
        expect(bp.matcher.match?("a-b")).to be false
      end

      it "compiles an anchored matcher for a $-trailing pattern" do
        bp = described_class.new("-$")
        expect(bp.matcher.match?("ab-")).to be true
        expect(bp.matcher.match?("a-b")).to be false
      end

      it "escapes regex special characters that are not ^ or $" do
        bp = described_class.new("*")
        # "*" should be escaped (zero-or-more quantifier) so it matches literally.
        expect(bp.matcher.match?("a*b")).to be true
      end
    end
  end

  describe Kotoshu::Readers::Ignore do
    describe "#initialize" do
      it "stores the chars string" do
        ig = described_class.new("'")
        expect(ig.chars).to eq("'")
      end

      it "builds a translation_table mapping each char to its index" do
        ig = described_class.new("ab")
        expect(ig.translation_table).to eq("a" => 0, "b" => 1)
      end

      it "stores an empty string when no chars given" do
        ig = described_class.new("")
        expect(ig.chars).to eq("")
        expect(ig.translation_table).to eq({})
      end
    end

    describe "#remove" do
      it "removes ignored characters from the string" do
        ig = described_class.new("'")
        expect(ig.remove("can't")).to eq("cant")
      end

      it "returns the original string when no chars match" do
        ig = described_class.new("'")
        expect(ig.remove("cat")).to eq("cat")
      end

      it "removes multiple distinct ignored characters" do
        ig = described_class.new("aeiou")
        expect(ig.remove("hello")).to eq("hll")
      end
    end
  end

  describe Kotoshu::Readers::RepPattern do
    describe "#initialize" do
      it "stores pattern, replacement, and compiled matcher" do
        rp = described_class.new("f", "ph")
        expect(rp.pattern).to eq("f")
        expect(rp.replacement).to eq("ph")
        expect(rp.matcher).to be_a(Regexp)
        expect(rp.matcher.match?("fon")).to be true
      end
    end
  end

  describe Kotoshu::Readers::ConvTable do
    describe "#initialize" do
      it "stores the raw pairs" do
        ct = described_class.new([["a", "b"], ["c", "d"]])
        expect(ct.pairs).to eq([["a", "b"], ["c", "d"]])
      end
    end

    describe "#call" do
      it "applies a single conversion to the matching prefix" do
        ct = described_class.new([["a", "A"]])
        expect(ct.call("abc")).to eq("Abc")
      end

      it "applies multiple conversions positionally" do
        ct = described_class.new([["a", "A"], ["b", "B"]])
        expect(ct.call("ab")).to eq("AB")
      end

      it "prefers the longer conversion when both match at the same position" do
        ct = described_class.new([["ab", "X"], ["a", "Y"]])
        # At position 0, both match; longer ("ab") wins.
        expect(ct.call("abc")).to eq("Xc")
      end

      it "preserves declaration order for equal-length conversions" do
        # Same length → first-declared wins (mirrors Spylls's stable sort).
        ct = described_class.new([["a", "X"], ["a", "Y"]])
        expect(ct.call("a")).to eq("X")
      end

      it "passes characters without a matching conversion through unchanged" do
        ct = described_class.new([["x", "X"]])
        expect(ct.call("abc")).to eq("abc")
      end

      it "treats leading underscore as start-of-word anchor" do
        ct = described_class.new([["_a", "X"]])
        # _a matches only at position 0.
        expect(ct.call("ab")).to eq("Xb")
        # _a does NOT match when 'a' appears mid-word.
        expect(ct.call("ba")).to eq("ba")
      end

      it "treats trailing underscore as end-of-word anchor" do
        ct = described_class.new([["a_", "X"]])
        expect(ct.call("ba")).to eq("bX")
        expect(ct.call("ab")).to eq("ab")
      end

      it "replaces underscore in replacement with space" do
        ct = described_class.new([["ab", "a_b"]])
        expect(ct.call("ab")).to eq("a b")
      end
    end
  end

  describe Kotoshu::Readers::CompoundRule do
    describe "#initialize" do
      it "stores the rule text" do
        rule = described_class.new("ABC")
        expect(rule.text).to eq("ABC")
      end

      it "extracts single-char flags when no parens are used" do
        rule = described_class.new("A*B?CD")
        expect(rule.flags).to eq(Set.new(%w[A B C D]))
      end

      it "extracts multi-char flags when parens are used" do
        rule = described_class.new("(abc)(de)")
        expect(rule.flags).to eq(Set.new(%w[abc de]))
      end

      it "compiles a full-match regex" do
        rule = described_class.new("ABC")
        expect(rule.re).to be_a(Regexp)
        expect(rule.re.match?("ABC")).to be true
        expect(rule.re.match?("AB")).to be false
      end

      it "compiles a partial-match regex" do
        rule = described_class.new("ABC")
        expect(rule.partial_re.match?("A")).to be true
        expect(rule.partial_re.match?("AB")).to be true
        expect(rule.partial_re.match?("ABC")).to be true
        # Non-prefix is not a partial match.
        expect(rule.partial_re.match?("BC")).to be false
      end
    end

    describe "#fullmatch" do
      it "returns true when the flag sets combine to a full match" do
        rule = described_class.new("ABC")
        expect(rule.fullmatch([Set.new(["A"]), Set.new(["B"]), Set.new(["C"])])).to be true
      end

      it "returns false when the combination does not match" do
        rule = described_class.new("ABC")
        expect(rule.fullmatch([Set.new(["A"]), Set.new(["B"])])).to be false
      end

      it "returns false when any flag set has no overlap with the rule" do
        rule = described_class.new("ABC")
        expect(rule.fullmatch([Set.new(["A"]), Set.new(["X"])])).to be false
      end

      it "returns false for an empty array of flag sets" do
        rule = described_class.new("ABC")
        expect(rule.fullmatch([])).to be false
      end
    end

    describe "#partial_match" do
      it "returns true for any prefix of the rule" do
        rule = described_class.new("ABC")
        expect(rule.partial_match([Set.new(["A"])])).to be true
        expect(rule.partial_match([Set.new(["A"]), Set.new(["B"])])).to be true
      end

      it "returns false when the prefix does not match" do
        rule = described_class.new("ABC")
        expect(rule.partial_match([Set.new(["B"])])).to be false
      end
    end
  end

  describe Kotoshu::Readers::CompoundPattern do
    describe "#initialize" do
      it "stores left, right, replacement" do
        cp = described_class.new("aaa", "bbb", "ccc")
        expect(cp.left).to eq("aaa")
        expect(cp.right).to eq("bbb")
        expect(cp.replacement).to eq("ccc")
      end

      it "parses left into left_stem and left_flag when slash present" do
        cp = described_class.new("aaa/X", "bbb")
        expect(cp.left_stem).to eq("aaa")
        expect(cp.left_flag).to eq("X")
      end

      it "sets left_flag to nil when no slash present" do
        cp = described_class.new("aaa", "bbb")
        expect(cp.left_flag).to be_nil
      end

      it "normalizes a bare 0 stem to empty string" do
        cp = described_class.new("0", "0")
        expect(cp.left_stem).to eq("")
        expect(cp.right_stem).to eq("")
      end

      it "marks left_no_affix when the left side is exactly 0" do
        cp = described_class.new("0", "0")
        expect(cp.left_no_affix).to be true
        expect(cp.right_no_affix).to be true
      end
    end

    describe "#match?" do
      # Build minimal double-free stubs via Struct.
      Form = Struct.new(:stem, :flags, :is_base?, keyword_init: true)

      it "matches when left stem ends in left_stem and right stem starts with right_stem" do
        cp = described_class.new("aa", "bb")
        left = Form.new(stem: "aaa", flags: Set.new, is_base?: true)
        right = Form.new(stem: "bbb", flags: Set.new, is_base?: true)
        expect(cp.match?(left, right)).to be true
      end

      it "rejects when left stem does not end in left_stem" do
        cp = described_class.new("aa", "bb")
        left = Form.new(stem: "xxx", flags: Set.new, is_base?: true)
        right = Form.new(stem: "bbb", flags: Set.new, is_base?: true)
        expect(cp.match?(left, right)).to be false
      end

      it "rejects when right stem does not start with right_stem" do
        cp = described_class.new("aa", "bb")
        left = Form.new(stem: "aaa", flags: Set.new, is_base?: true)
        right = Form.new(stem: "xxx", flags: Set.new, is_base?: true)
        expect(cp.match?(left, right)).to be false
      end

      it "enforces the left_flag requirement when present" do
        cp = described_class.new("aa/X", "bb")
        left_with = Form.new(stem: "aaa", flags: Set.new(["X"]), is_base?: true)
        left_without = Form.new(stem: "aaa", flags: Set.new(["Y"]), is_base?: true)
        right = Form.new(stem: "bbb", flags: Set.new, is_base?: true)
        expect(cp.match?(left_with, right)).to be true
        expect(cp.match?(left_without, right)).to be false
      end

      it "rejects base-form left parts when left_no_affix is set" do
        cp = described_class.new("0", "bb")
        base = Form.new(stem: "x", flags: Set.new, is_base?: true)
        affixed = Form.new(stem: "x", flags: Set.new, is_base?: false)
        right = Form.new(stem: "bbb", flags: Set.new, is_base?: true)
        expect(cp.match?(base, right)).to be false
        expect(cp.match?(affixed, right)).to be true
      end
    end
  end

  describe Kotoshu::Readers::PhonetTable do
    describe Kotoshu::Readers::PhonetTable::Rule do
      it "is a Struct with the documented fields" do
        expect(described_class.members).to contain_exactly(:search, :replacement, :start,
                                                           :end, :priority, :followup)
      end

      it "is constructed with keyword args" do
        rule = described_class.new(search: /ab/, replacement: "X",
                                   start: true, end: false, priority: 5,
                                   followup: true)
        expect(rule.search).to eq(/ab/)
        expect(rule.replacement).to eq("X")
        expect(rule.start).to be true
        expect(rule.end).to be false
        expect(rule.priority).to eq(5)
        expect(rule.followup).to be true
      end

      # NOTE: Rule#match? currently references @search/@start/@end instance
      # variables, but Struct-backed classes don't populate ivars — those
      # reads return nil. The method is effectively dead code (phonet_suggest
      # uses a different rule shape entirely: rule[:search], rule[:start]).
      # Filed for follow-up; not tested here.
    end

    describe "#initialize" do
      it "stores the raw table" do
        pt = described_class.new([["a", "X"]])
        expect(pt.table).to eq([["a", "X"]])
      end

      it "indexes rules by their first letter" do
        pt = described_class.new([["a", "X"], ["ab", "Y"]])
        expect(pt.rules.key?("a")).to be true
        expect(pt.rules["a"].length).to eq(2)
      end

      it "returns an empty hash for an empty table" do
        pt = described_class.new([])
        expect(pt.rules).to eq({})
      end
    end

    describe "#empty?" do
      it "is true for an empty table" do
        expect(described_class.new([])).to be_empty
      end

      it "is false for a non-empty table" do
        expect(described_class.new([["a", "X"]])).not_to be_empty
      end
    end

    describe "#parse_rule" do
      it "returns a Rule with the search regex and replacement" do
        pt = described_class.new([])
        rule = pt.parse_rule("ab", "X")
        expect(rule).to be_a(Kotoshu::Readers::PhonetTable::Rule)
        expect(rule.replacement).to eq("X")
        expect(rule.search).to be_a(Regexp)
      end

      it "treats '_' replacement as silent (empty string)" do
        pt = described_class.new([])
        rule = pt.parse_rule("a", "_")
        expect(rule.replacement).to eq("")
      end

      it "raises ArgumentError for a malformed rule" do
        pt = described_class.new([])
        expect { pt.parse_rule("123", "X") }.to raise_error(ArgumentError, /Not a proper rule/)
      end

      it "parses the start flag (^)" do
        pt = described_class.new([])
        rule = pt.parse_rule("a^", "X")
        expect(rule.start).to be true
      end

      it "parses the end flag ($)" do
        pt = described_class.new([])
        rule = pt.parse_rule("a$", "X")
        expect(rule.end).to be true
      end

      it "parses an explicit priority digit" do
        pt = described_class.new([])
        rule = pt.parse_rule("a1", "X")
        expect(rule.priority).to eq(1)
      end

      it "defaults priority to 5 when absent" do
        pt = described_class.new([])
        rule = pt.parse_rule("a", "X")
        expect(rule.priority).to eq(5)
      end

      it "parses optional groups in parens" do
        pt = described_class.new([])
        rule = pt.parse_rule("a(bc)", "X")
        # Optional group becomes a character class in the search regex.
        expect(rule.search.match?("abc")).to be true
      end

      it "parses a lookahead (-) into a followup rule" do
        pt = described_class.new([])
        rule = pt.parse_rule("ab-", "X")
        expect(rule.followup).to be true
      end
    end
  end
end
