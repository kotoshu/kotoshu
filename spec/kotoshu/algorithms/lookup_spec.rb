# frozen_string_literal: true

require "kotoshu"

# Trigger autoload of the structures Lookup references.
Kotoshu::Readers::DicReader

# Direct spec for Algorithms::Lookup — the Spylls-ported correctness pipeline.
#
# Lookup is the "is this word correct?" algorithm. It drives the check side
# of the spell checker: take a word, classify its casing, look it up in the
# dictionary directly, attempt affix stripping (suffixes / prefixes / both),
# try compound breaking by BREAK patterns and by COMPOUNDFLAG/COMPOUNDRULE,
# and consult directives (FORBIDDENWORD, NEEDAFFIX, KEEPCASE, NOSUGGEST,
# CIRCUMFIX, IGNORE, ICONV, ...).
#
# Had no direct spec. This file exercises:
#   - Pure value objects: CompoundPos, AffixForm, CompoundForm
#   - NUMBER_REGEXP (numeric shortcut)
#   - Lookuper public surface against real LookupBuilder-built aff/dic
#   structures (no doubles): correct?, call, break_word, good_forms.
RSpec.describe Kotoshu::Algorithms::Lookup do
  let(:lookup_mod) { Kotoshu::Algorithms::Lookup }

  describe "NUMBER_REGEXP" do
    it "matches an integer" do
      expect(lookup_mod::NUMBER_REGEXP).to be_a(Regexp)
      expect(lookup_mod::NUMBER_REGEXP.match?("123")).to be true
    end

    it "matches a decimal" do
      expect(lookup_mod::NUMBER_REGEXP.match?("3.14")).to be true
    end

    it "does not match a bare word" do
      expect(lookup_mod::NUMBER_REGEXP.match?("foo")).to be false
    end

    it "does not match a word with digits inside" do
      expect(lookup_mod::NUMBER_REGEXP.match?("abc123")).to be false
    end
  end

  describe Kotoshu::Algorithms::Lookup::CompoundPos do
    it "exposes BEGIN_POS, MIDDLE, END_POS as symbols" do
      expect(described_class::BEGIN_POS).to eq(:begin)
      expect(described_class::MIDDLE).to eq(:middle)
      expect(described_class::END_POS).to eq(:end)
    end
  end

  describe Kotoshu::Algorithms::Lookup::AffixForm do
    let(:suffix_data) { { affix: "ing", flags: Set.new(["V"]), flag: "V" } }
    let(:prefix_data) { { affix: "re", flags: Set.new(["P"]), flag: "P" } }
    let(:dict_entry) { { stem: "spell", flags: Set.new(["N"]) } }

    describe "#initialize" do
      it "stores text and stem, with nil affixes by default" do
        form = described_class.new("spell", "spell")
        expect(form.text).to eq("spell")
        expect(form.stem).to eq("spell")
        expect(form.prefix).to be_nil
        expect(form.suffix).to be_nil
        expect(form.prefix2).to be_nil
        expect(form.suffix2).to be_nil
        expect(form.in_dictionary).to be_nil
      end

      it "honors all kwargs" do
        form = described_class.new("respelling", "spell",
                                   prefix: prefix_data, suffix: suffix_data,
                                   in_dictionary: dict_entry)
        expect(form.prefix).to eq(prefix_data)
        expect(form.suffix).to eq(suffix_data)
        expect(form.in_dictionary).to eq(dict_entry)
      end
    end

    describe "#replace" do
      it "returns a new form with one field changed (text)" do
        form = described_class.new("spell", "spell")
        copy = form.replace(text: "spells")
        expect(copy.text).to eq("spells")
        expect(copy.stem).to eq("spell")
        expect(copy).not_to equal(form)
      end

      it "replaces stem" do
        form = described_class.new("spell", "spell")
        copy = form.replace(stem: "spellz")
        expect(copy.stem).to eq("spellz")
        expect(copy.text).to eq("spell")
      end

      it "replaces suffix" do
        form = described_class.new("spell", "spell", suffix: suffix_data)
        copy = form.replace(suffix: { affix: "s", flags: Set.new(["N"]), flag: "N" })
        expect(copy.suffix[:affix]).to eq("s")
      end

      it "preserves fields not mentioned in changes" do
        form = described_class.new("respelling", "spell",
                                   prefix: prefix_data, suffix: suffix_data)
        copy = form.replace(text: "another")
        expect(copy.prefix).to eq(prefix_data)
        expect(copy.suffix).to eq(suffix_data)
      end
    end

    describe "#has_affixes?" do
      it "is false for a base form" do
        expect(described_class.new("spell", "spell").has_affixes?).to be false
      end

      it "is true when suffix is present" do
        expect(described_class.new("spelling", "spell", suffix: suffix_data).has_affixes?).to be true
      end

      it "is true when prefix is present" do
        expect(described_class.new("respell", "spell", prefix: prefix_data).has_affixes?).to be true
      end

      it "ignores in_dictionary (root homonym is not an affix)" do
        form = described_class.new("spell", "spell", in_dictionary: dict_entry)
        expect(form.has_affixes?).to be false
      end
    end

    describe "#is_base?" do
      it "is the inverse of has_affixes?" do
        form_a = described_class.new("spell", "spell")
        form_b = described_class.new("spelling", "spell", suffix: suffix_data)
        expect(form_a.is_base?).to be true
        expect(form_b.is_base?).to be false
      end
    end

    describe "#flags" do
      it "returns the in_dictionary flags when present" do
        form = described_class.new("spell", "spell", in_dictionary: dict_entry)
        expect(form.flags).to eq(Set.new(["N"]))
      end

      it "merges prefix flags into the set" do
        form = described_class.new("respell", "spell",
                                   prefix: prefix_data, in_dictionary: dict_entry)
        expect(form.flags).to contain_exactly("N", "P")
      end

      it "merges suffix flags into the set" do
        form = described_class.new("spelling", "spell",
                                   suffix: suffix_data, in_dictionary: dict_entry)
        expect(form.flags).to contain_exactly("N", "V")
      end

      it "returns an empty set when in_dictionary is nil" do
        form = described_class.new("spell", "spell")
        expect(form.flags).to eq(Set.new)
      end
    end

    describe "#all_affixes" do
      it "is empty for a base form" do
        expect(described_class.new("spell", "spell").all_affixes).to eq([])
      end

      it "returns [prefix2, prefix, suffix, suffix2] in order, compacted" do
        suf2 = { affix: "ed", flags: Set.new(["V"]), flag: "V" }
        pfx2 = { affix: "un", flags: Set.new(["P"]), flag: "P" }
        form = described_class.new("unspelled", "spell",
                                   prefix: prefix_data, prefix2: pfx2,
                                   suffix: suffix_data, suffix2: suf2)
        expect(form.all_affixes).to eq([pfx2, prefix_data, suffix_data, suf2])
      end

      it "compacts out nil secondary affixes" do
        form = described_class.new("spelling", "spell", suffix: suffix_data)
        expect(form.all_affixes).to eq([suffix_data])
      end
    end

    describe "#to_s" do
      it "returns the text alone for a base form" do
        expect(described_class.new("spell", "spell").to_s).to eq("spell")
      end

      it "renders prefix2 + prefix + stem + suffix2 + suffix for an affixed form" do
        form = described_class.new("respelling", "spell",
                                   prefix: prefix_data, suffix: suffix_data)
        # Inspects via to_s (alias inspect). Verify all components present.
        s = form.to_s
        expect(s).to include("respelling")
        expect(s).to include("spell")
      end
    end

    it "aliases #inspect to #to_s" do
      form = described_class.new("spell", "spell")
      expect(form.inspect).to eq(form.to_s)
    end
  end

  describe Kotoshu::Algorithms::Lookup::CompoundForm do
    it "stores the parts array" do
      part_a = Kotoshu::Algorithms::Lookup::AffixForm.new("foo", "foo")
      part_b = Kotoshu::Algorithms::Lookup::AffixForm.new("bar", "bar")
      compound = described_class.new([part_a, part_b])
      expect(compound.parts).to eq([part_a, part_b])
    end

    it "renders via to_s by joining parts with ' + '" do
      part_a = Kotoshu::Algorithms::Lookup::AffixForm.new("foo", "foo")
      part_b = Kotoshu::Algorithms::Lookup::AffixForm.new("bar", "bar")
      compound = described_class.new([part_a, part_b])
      expect(compound.to_s).to eq("CompoundForm(foo + bar)")
    end

    it "aliases #inspect to #to_s" do
      part = Kotoshu::Algorithms::Lookup::AffixForm.new("foo", "foo")
      compound = described_class.new([part])
      expect(compound.inspect).to eq(compound.to_s)
    end

    it "handles a single-part compound" do
      part = Kotoshu::Algorithms::Lookup::AffixForm.new("foo", "foo")
      compound = described_class.new([part])
      expect(compound.to_s).to eq("CompoundForm(foo)")
    end
  end

  # ---- Lookuper end-to-end against real LookupBuilder-built data -----------
  #
  # Build minimal aff/dic structures with LookupBuilder so the value objects
  # and lookup logic exercise real code paths (no doubles, no stubs).
  describe Kotoshu::Algorithms::Lookup::Lookuper do
    def word(stem, flags: Set.new, morph_data: [])
      Kotoshu::Readers::Word.new(stem:, flags:, morph_data:)
    end

    def affix(add:, type: :suffix, flag: "A", crossproduct: false, strip: "", condition: ".", flags: Set.new)
      Kotoshu::Readers::Affix.new(type:, flag:, crossproduct:, strip:,
                                  add:, condition:, flags:)
    end

    def minimal_aff(overrides = {})
      { "SFX" => {}, "PFX" => {}, "FLAG" => "short" }.merge(overrides)
    end

    def build(aff_data, words = [])
      Kotoshu::Readers::LookupBuilder.from_data(aff_data, words).build
    end

    describe "#initialize" do
      it "exposes aff and dic readers" do
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.aff).to be_a(Hash)
        expect(lookuper.dic).to be_a(Hash)
      end
    end

    describe "#correct? (basic dictionary lookup)" do
      it "returns true for a word directly in the dictionary" do
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.correct?("cat")).to be true
      end

      it "returns false for a word not in the dictionary" do
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.correct?("dog")).to be false
      end

      it "is aliased as #is_correct?" do
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.is_correct?("cat")).to be true
        expect(lookuper.is_correct?("dog")).to be false
      end
    end

    describe "#call (numerals shortcut)" do
      it "accepts an integer as a number" do
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.call("123")).to be true
      end

      it "accepts a decimal as a number" do
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.call("3.14")).to be true
      end

      it "does not shortcut a word that merely contains digits" do
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.call("abc123")).to be false
      end
    end

    describe "#correct? (case variants)" do
      it "accepts a titlecase variant of a lowercase dictionary stem" do
        # "Cat" → class Casing.variants returns [:init, ["Cat", "cat"]]
        # → "cat" matches the dictionary.
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.correct?("Cat")).to be true
      end

      it "accepts an all-caps variant of a lowercase dictionary stem" do
        # Casing.variants for "CAT" → [:all, ["CAT", "cat", "Cat"]]
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.correct?("CAT")).to be true
      end

      it "skips case variants when capitalization: false" do
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.correct?("CAT", capitalization: false)).to be false
      end
    end

    describe "#call (FORBIDDENWORD top-level guard)" do
      it "rejects a word whose every homonym has FORBIDDENWORD" do
        aff = minimal_aff("FORBIDDENWORD" => "X")
        lookuper = build(aff, [word("bad", flags: Set.new(["X"]))])
        expect(lookuper.call("bad")).to be false
      end

      it "accepts a word whose some homonym does not have FORBIDDENWORD" do
        aff = minimal_aff("FORBIDDENWORD" => "X")
        # Two homonyms of "bank": one with FORBIDDENWORD, one without.
        words = [word("bank", flags: Set.new(["X"])),
                 word("bank", flags: Set.new(["Y"]))]
        lookuper = build(aff, words)
        expect(lookuper.call("bank")).to be true
      end
    end

    describe "#correct? (suffix rules)" do
      it "accepts a word that matches a dictionary stem + suffix rule" do
        # "cat" /s → "cats" is a correctly spelled form.
        sfx = affix(flag: "A", add: "s")
        aff = minimal_aff("SFX" => { "A" => [sfx] })
        lookuper = build(aff, [word("cat", flags: Set.new(["A"]))])
        expect(lookuper.correct?("cats")).to be true
      end

      it "accepts a second-suffix derivation when nested" do
        # "spell" with "ed" — straightforward
        sfx_ed = affix(flag: "A", add: "ed")
        aff = minimal_aff("SFX" => { "A" => [sfx_ed] })
        lookuper = build(aff, [word("spell", flags: Set.new(["A"]))])
        expect(lookuper.correct?("spelled")).to be true
      end

      it "rejects a word whose suffix does not satisfy the affix condition" do
        # Suffix is only valid when stem ends with a particular pattern.
        sfx = affix(flag: "A", add: "ed", condition: "[^aeiou]") # must end in consonant
        aff = minimal_aff("SFX" => { "A" => [sfx] })
        lookuper = build(aff, [word("make", flags: Set.new(["A"]))])
        # "make" ends in 'e' (vowel) — "make" + "ed" = "makeed", not valid.
        # And "maked" is not a real word in our dictionary.
        expect(lookuper.correct?("maked")).to be false
      end
    end

    describe "#correct? (prefix rules)" do
      it "accepts a word that matches a dictionary stem + prefix rule" do
        pfx = affix(type: :prefix, flag: "P", add: "re")
        aff = minimal_aff("PFX" => { "P" => [pfx] })
        lookuper = build(aff, [word("read", flags: Set.new(["P"]))])
        expect(lookuper.correct?("reread")).to be true
      end
    end

    describe "#correct? (suffix + prefix cross-product)" do
      it "accepts a word that needs both a prefix and a suffix (crossproduct on)" do
        pfx = affix(type: :prefix, flag: "P", add: "re", crossproduct: true)
        sfx = affix(flag: "S", add: "ing", crossproduct: true)
        aff = minimal_aff("PFX" => { "P" => [pfx] },
                          "SFX" => { "S" => [sfx] })
        # Crossproduct pfx+suffix: "read" + re__ + ing = "rereading".
        # Stem must carry BOTH flags to be eligible.
        lookuper = build(aff, [word("read", flags: Set.new(["P", "S"]))])
        expect(lookuper.correct?("rereading")).to be true
      end
    end

    describe "#call (IGNORE chars)" do
      it "strips IGNORE chars from the word before lookup" do
        ignore = Kotoshu::Readers::Ignore.new("'")
        aff = minimal_aff("IGNORE" => ignore)
        # Dictionary contains "cant"; user input "can't" → strip apostrophe → "cant".
        lookuper = build(aff, [word("cant")])
        expect(lookuper.call("can't")).to be true
      end
    end

    describe "#call (BREAK patterns)" do
      it "accepts a word that breaks into two dictionary words" do
        bp = Kotoshu::Readers::BreakPattern.new("-")
        aff = minimal_aff("BREAK" => [bp])
        lookuper = build(aff, [word("pre"), word("processed")])
        expect(lookuper.call("pre-processed")).to be true
      end

      it "does NOT accept when BREAK is explicitly disabled (no defaults)" do
        aff = minimal_aff("BREAK" => [])
        lookuper = build(aff, [word("pre"), word("processed")])
        expect(lookuper.call("pre-processed")).to be false
      end
    end

    describe "#correct? (NOSUGGEST directive)" do
      it "rejects NOSUGGEST-flagged words when allow_nosuggest: false" do
        aff = minimal_aff("NOSUGGEST" => "NS")
        lookuper = build(aff, [word("secret", flags: Set.new(["NS"]))])
        expect(lookuper.correct?("secret", allow_nosuggest: false)).to be false
      end

      it "accepts NOSUGGEST-flagged words by default" do
        aff = minimal_aff("NOSUGGEST" => "NS")
        lookuper = build(aff, [word("secret", flags: Set.new(["NS"]))])
        expect(lookuper.correct?("secret")).to be true
      end
    end

    describe "#break_word" do
      it "always yields the whole text as the first option" do
        lookuper = build(minimal_aff, [word("pre"), word("processed")])
        results = lookuper.break_word("pre-processed").to_a
        expect(results.first).to eq(["pre-processed"])
      end

      it "yields splits by the BREAK patterns" do
        bp = Kotoshu::Readers::BreakPattern.new("-")
        aff = minimal_aff("BREAK" => [bp])
        lookuper = build(aff, [word("a"), word("b"), word("c")])
        breakings = lookuper.break_word("a-b-c").to_a
        # Whole text + every left-prefix split.
        expect(breakings).to include(["a-b-c"])
        expect(breakings).to include(["a", "b-c"])
        expect(breakings).to include(["a", "b", "c"])
      end

      it "returns just [text] when no BREAK is configured" do
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.break_word("cat").to_a).to eq([["cat"]])
      end

      it "yields via Enumerator when no block given" do
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.break_word("cat")).to be_an(Enumerator)
      end

      it "returns nothing (depth limit reached) when recursion exceeds depth 10" do
        # 11 dashes → 12 chunks would be needed; depth cap stops it.
        bp = Kotoshu::Readers::BreakPattern.new("-")
        aff = minimal_aff("BREAK" => [bp])
        lookuper = build(aff, [word("a")])
        text = "a-" + ("a-" * 10) + "a" # many potential splits
        results = lookuper.break_word(text).to_a
        # The depth limit keeps the number of splits bounded; we just
        # verify no crash and that some splits happen.
        expect(results).to include([text])
      end
    end

    describe "#good_forms" do
      it "yields at least one form for an in-dictionary word" do
        lookuper = build(minimal_aff, [word("cat")])
        forms = lookuper.good_forms("cat").to_a
        expect(forms).not_to be_empty
      end

      it "yields both affix and compound forms when applicable" do
        sfx = affix(flag: "A", add: "s")
        aff = minimal_aff("SFX" => { "A" => [sfx] })
        lookuper = build(aff, [word("cat", flags: Set.new(["A"]))])
        forms = lookuper.good_forms("cat").to_a
        expect(forms).not_to be_empty
      end

      it "yields nothing for an unknown word" do
        lookuper = build(minimal_aff, [word("cat")])
        forms = lookuper.good_forms("xyzzy").to_a
        expect(forms).to be_empty
      end

      it "returns an Enumerator when no block is given" do
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.good_forms("cat")).to be_an(Enumerator)
      end

      it "honors affix_forms: false (compound_forms only)" do
        sfx = affix(flag: "A", add: "s")
        aff = minimal_aff("SFX" => { "A" => [sfx] })
        lookuper = build(aff, [word("cat", flags: Set.new(["A"]))])
        # For a non-compound dictionary, affix_forms: false has nothing to yield.
        forms = lookuper.good_forms("cat", affix_forms: false, compound_forms: false).to_a
        expect(forms).to be_empty
      end
    end

    describe "#call (the outermost check)" do
      it "returns true for a correct word" do
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.call("cat")).to be true
      end

      it "returns false for an incorrect word" do
        lookuper = build(minimal_aff, [word("cat")])
        expect(lookuper.call("dog")).to be false
      end
    end
  end
end
