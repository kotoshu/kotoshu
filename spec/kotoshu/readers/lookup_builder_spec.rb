# frozen_string_literal: true

require "kotoshu"

# Word is defined in kotoshu/readers/dic_reader.rb at the Readers namespace
# level. LookupBuilder never references it directly, so the autoload never
# fires. Reference DicReader to load the file.
Kotoshu::Readers::DicReader

# Direct spec for Readers::LookupBuilder and Readers::PhRepExtractor.
#
# LookupBuilder translates the raw aff/dic structures (from AffReader/DicReader)
# into the lookup-ready shape consumed by Algorithms::Lookup::Lookuper: builds
# suffix/prefix indexes, applies Hunspell upstream defaults for the suggester
# directives, selects the right Casing strategy from LANG/CHECKSHARPS, strips
# IGNORE chars at read time, and folds dictionary `ph:` morph data into REP.
#
# PhRepExtractor adapts the three `ph:` payload forms (simple, star, arrow)
# into REP entries and alt_spellings — Hunspell 1.7+ behavior.
#
# Had no direct spec — only exercised indirectly via Hunspell fixture tests.
RSpec.describe Kotoshu::Readers::LookupBuilder do
  # Helpers that build real domain objects (no doubles, no stubs).
  def affix(add:, type: :suffix, flag: "A", crossproduct: false, strip: "", condition: ".", flags: Set.new)
    Kotoshu::Readers::Affix.new(type:, flag:, crossproduct:, strip:,
                                add:, condition:, flags:)
  end

  def word(stem, flags: Set.new, morph_data: [])
    Kotoshu::Readers::Word.new(stem:, flags:, morph_data:)
  end

  def minimal_aff(overrides = {})
    {
      "SFX" => {},
      "PFX" => {},
      "FLAG" => "short"
    }.merge(overrides)
  end

  describe ".new" do
    it "exposes aff_path, dic_path, encoding, script, aff_data, words readers" do
      builder = described_class.new("a.aff", "a.dic")
      expect(builder.aff_path).to eq("a.aff")
      expect(builder.dic_path).to eq("a.dic")
      expect(builder.encoding).to eq("UTF-8")
      expect(builder.script).to eq(:latin)
      expect(builder.aff_data).to be_nil
      expect(builder.words).to be_nil
    end

    it "honors the encoding and script keyword args" do
      builder = described_class.new("a.aff", "a.dic",
                                    encoding: "ISO-8859-1", script: :arabic)
      expect(builder.encoding).to eq("ISO-8859-1")
      expect(builder.script).to eq(:arabic)
    end
  end

  describe ".from_data" do
    it "returns a builder with aff_data and words populated" do
      aff_data = minimal_aff
      words = [word("cat")]
      builder = described_class.from_data(aff_data, words)
      expect(builder.aff_data).to eq(aff_data)
      expect(builder.words).to eq(words)
    end

    it "yields a buildable Lookuper without touching the filesystem" do
      # aff_path and dic_path are nil; build must NOT attempt to read files.
      builder = described_class.from_data(minimal_aff, [word("cat")])
      lookuper = builder.build
      expect(lookuper).to be_a(Kotoshu::Algorithms::Lookup::Lookuper)
    end
  end

  describe "#build — suffix index" do
    it "indexes suffixes by the first char of the REVERSED add string" do
      sfx = affix(flag: "A", add: "ed")
      aff_data = minimal_aff("SFX" => { "A" => [sfx] })
      lookuper = described_class.from_data(aff_data, []).build
      # 'ed'.reverse = 'de'; first char is 'd'.
      expect(lookuper.aff[:suffixes_index].keys).to include("d")
    end

    it "groups suffix entries under their flag" do
      sfx1 = affix(flag: "A", add: "s")
      sfx2 = affix(flag: "A", add: "es")
      sfx3 = affix(flag: "B", add: "ing")
      aff_data = minimal_aff("SFX" => { "A" => [sfx1, sfx2], "B" => [sfx3] })
      lookuper = described_class.from_data(aff_data, []).build
      expect(lookuper.aff[:suffixes_by_flag]["A"].length).to eq(2)
      expect(lookuper.aff[:suffixes_by_flag]["B"].length).to eq(1)
    end
  end

  describe "#build — prefix index" do
    it "indexes prefixes by the first char of the add string" do
      pfx = affix(type: :prefix, flag: "P", add: "re")
      aff_data = minimal_aff("PFX" => { "P" => [pfx] })
      lookuper = described_class.from_data(aff_data, []).build
      expect(lookuper.aff[:prefixes_index].keys).to include("r")
    end

    it "groups prefix entries under their flag" do
      pfx = affix(type: :prefix, flag: "P", add: "re")
      aff_data = minimal_aff("PFX" => { "P" => [pfx] })
      lookuper = described_class.from_data(aff_data, []).build
      expect(lookuper.aff[:prefixes_by_flag]["P"].length).to eq(1)
    end
  end

  describe "#build — IGNORE chars are stripped at read time" do
    it "removes IGNORE chars from dictionary stems" do
      ignore = Kotoshu::Readers::Ignore.new("'")
      aff_data = minimal_aff("IGNORE" => ignore)
      words = [word("ca't")]
      lookuper = described_class.from_data(aff_data, words).build
      stems = lookuper.dic[:words].map { |e| e[:stem] }
      expect(stems).to eq(["cat"])
    end

    it "removes IGNORE chars from affix add strings" do
      ignore = Kotoshu::Readers::Ignore.new("'")
      sfx = affix(flag: "A", add: "'s")
      aff_data = minimal_aff("IGNORE" => ignore, "SFX" => { "A" => [sfx] })
      lookuper = described_class.from_data(aff_data, []).build
      # 's'.reverse = 's'; first char is 's' (NOT "'").
      entries = lookuper.aff[:suffixes_index]["s"]
      expect(entries).not_to be_nil
      expect(entries.first[:affix]).to eq("s")
    end
  end

  describe "#build — casing selection" do
    it "uses the standard Casing when no LANG or CHECKSHARPS is set" do
      lookuper = described_class.from_data(minimal_aff, []).build
      expect(lookuper.aff[:casing]).to be_a(Kotoshu::Algorithms::Capitalization::Casing)
    end

    it "uses GermanCasing when CHECKSHARPS is true" do
      aff_data = minimal_aff("CHECKSHARPS" => true)
      lookuper = described_class.from_data(aff_data, []).build
      expect(lookuper.aff[:casing]).to be_a(Kotoshu::Algorithms::Capitalization::GermanCasing)
    end

    it "uses GermanCasing when LANG starts with 'de'" do
      aff_data = minimal_aff("LANG" => "de_DE")
      lookuper = described_class.from_data(aff_data, []).build
      expect(lookuper.aff[:casing]).to be_a(Kotoshu::Algorithms::Capitalization::GermanCasing)
    end

    it "uses TurkicCasing when LANG starts with 'tr'" do
      aff_data = minimal_aff("LANG" => "tr_TR")
      lookuper = described_class.from_data(aff_data, []).build
      expect(lookuper.aff[:casing]).to be_a(Kotoshu::Algorithms::Capitalization::TurkicCasing)
    end

    it "uses TurkicCasing when LANG starts with 'az'" do
      aff_data = minimal_aff("LANG" => "az_AZ")
      lookuper = described_class.from_data(aff_data, []).build
      expect(lookuper.aff[:casing]).to be_a(Kotoshu::Algorithms::Capitalization::TurkicCasing)
    end

    it "CHECKSHARPS takes precedence over LANG" do
      # LANG=tr triggers Turkic, but CHECKSHARPS forces German.
      aff_data = minimal_aff("LANG" => "tr_TR", "CHECKSHARPS" => true)
      lookuper = described_class.from_data(aff_data, []).build
      expect(lookuper.aff[:casing]).to be_a(Kotoshu::Algorithms::Capitalization::GermanCasing)
    end
  end

  describe "#build — suggester defaults" do
    it "applies DEFAULT_MAX_NGRAM_SUGS when MAXNGRAMSUGS is absent" do
      lookuper = described_class.from_data(minimal_aff, []).build
      expect(lookuper.aff[:MAXNGRAMSUGS])
        .to eq(Kotoshu::Readers::LookupBuilder::DEFAULT_MAX_NGRAM_SUGS)
    end

    it "honors an explicit MAXNGRAMSUGS" do
      aff_data = minimal_aff("MAXNGRAMSUGS" => 10)
      lookuper = described_class.from_data(aff_data, []).build
      expect(lookuper.aff[:MAXNGRAMSUGS]).to eq(10)
    end

    it "applies DEFAULT_MAX_CPD_SUGS when MAXCPDSUGS is absent" do
      lookuper = described_class.from_data(minimal_aff, []).build
      expect(lookuper.aff[:MAXCPDSUGS])
        .to eq(Kotoshu::Readers::LookupBuilder::DEFAULT_MAX_CPD_SUGS)
    end

    it "applies DEFAULT_MAX_DIFF when MAXDIFF is absent" do
      lookuper = described_class.from_data(minimal_aff, []).build
      expect(lookuper.aff[:MAXDIFF])
        .to eq(Kotoshu::Readers::LookupBuilder::DEFAULT_MAX_DIFF)
    end
  end

  describe "#build — BREAK defaults" do
    it "synthesizes the Spylls default BREAK table when BREAK is nil" do
      lookuper = described_class.from_data(minimal_aff, []).build
      patterns = lookuper.aff[:BREAK].map { |b| b[:pattern] }
      expect(patterns).to contain_exactly("-", "^-", "-$")
    end

    it "honors an explicit non-empty BREAK directive" do
      bp = Kotoshu::Readers::BreakPattern.new("n't")
      aff_data = minimal_aff("BREAK" => [bp])
      lookuper = described_class.from_data(aff_data, []).build
      expect(lookuper.aff[:BREAK].map { |b| b[:pattern] }).to eq(["n't"])
    end

    it "treats explicit empty BREAK ([]) as DISABLED — no defaults synthesized" do
      # `BREAK 0` in the .aff is the documented way to disable hyphen breaking.
      aff_data = minimal_aff("BREAK" => [])
      lookuper = described_class.from_data(aff_data, []).build
      expect(lookuper.aff[:BREAK]).to eq([])
    end
  end

  describe "#build — REP table adaptation" do
    it "adapts RepPattern instances to the {:regexp, :pattern, :replacement} shape" do
      rp = Kotoshu::Readers::RepPattern.new("f", "ph")
      aff_data = minimal_aff("REP" => [rp])
      lookuper = described_class.from_data(aff_data, []).build
      entry = lookuper.aff[:REP].first
      expect(entry[:pattern]).to eq("f")
      expect(entry[:replacement]).to eq("ph")
      expect(entry[:regexp]).to be_a(Regexp)
    end

    it "returns an empty REP table when REP is absent" do
      lookuper = described_class.from_data(minimal_aff, []).build
      expect(lookuper.aff[:REP]).to eq([])
    end
  end

  describe "#build — single-value flag pass-through" do
    it "forwards KEEPCASE/FORBIDDENWORD/NEEDAFFIX/etc. verbatim" do
      aff_data = minimal_aff(
        "KEEPCASE" => "K",
        "FORBIDDENWORD" => "X",
        "NEEDAFFIX" => "*",
        "CIRCUMFIX" => "C"
      )
      lookuper = described_class.from_data(aff_data, []).build
      expect(lookuper.aff[:KEEPCASE]).to eq("K")
      expect(lookuper.aff[:FORBIDDENWORD]).to eq("X")
      expect(lookuper.aff[:NEEDAFFIX]).to eq("*")
      expect(lookuper.aff[:CIRCUMFIX]).to eq("C")
    end

    it "forwards compound-directive flags verbatim" do
      aff_data = minimal_aff(
        "COMPOUNDBEGIN" => "B",
        "COMPOUNDMIDDLE" => "M",
        "COMPOUNDEND" => "E",
        "COMPOUNDFLAG" => "F"
      )
      lookuper = described_class.from_data(aff_data, []).build
      expect(lookuper.aff[:COMPOUNDBEGIN]).to eq("B")
      expect(lookuper.aff[:COMPOUNDMIDDLE]).to eq("M")
      expect(lookuper.aff[:COMPOUNDEND]).to eq("E")
      expect(lookuper.aff[:COMPOUNDFLAG]).to eq("F")
    end

    it "forwards COMPOUNDMIN/COMPOUNDWORDMAX verbatim (nil when absent)" do
      lookuper = described_class.from_data(minimal_aff, []).build
      expect(lookuper.aff[:COMPOUNDMIN]).to be_nil
      expect(lookuper.aff[:COMPOUNDWORDMAX]).to be_nil
    end
  end

  describe "#build — dic structure" do
    it "indexes dictionary stems for exact lookup" do
      words = [word("cat"), word("dog")]
      lookuper = described_class.from_data(minimal_aff, words).build
      homonyms = lookuper.dic[:homonyms].call("cat")
      expect(homonyms.map { |e| e[:stem] }).to eq(["cat"])
    end

    it "indexes dictionary stems for case-insensitive lookup when capitalized" do
      # "Cat" is INIT-cased → contributes a lowercased entry too.
      words = [word("Cat")]
      lookuper = described_class.from_data(minimal_aff, words).build
      homonyms = lookuper.dic[:homonyms].call("cat", ignorecase: true)
      expect(homonyms.map { |e| e[:stem] }).to eq(["Cat"])
    end

    it "does NOT lowercase-index already-lowercase stems (NO captype)" do
      # "cat" is NO-cased → does not contribute to lowercase_index.
      words = [word("cat")]
      lookuper = described_class.from_data(minimal_aff, words).build
      # ignorecase against a NO-cased entry: the lowercase index is empty,
      # so the lookup falls through to an empty result. (The exact-stem
      # index still has it.)
      expect(lookuper.dic[:homonyms].call("cat", ignorecase: true)).to eq([])
    end

    it "has_flag returns true when at least one entry has the flag (any)" do
      words = [word("cat", flags: Set.new(["A"]))]
      lookuper = described_class.from_data(minimal_aff, words).build
      expect(lookuper.dic[:has_flag].call("cat", "A")).to be true
    end

    it "has_flag returns false when no entry has the flag" do
      words = [word("cat", flags: Set.new(["A"]))]
      lookuper = described_class.from_data(minimal_aff, words).build
      expect(lookuper.dic[:has_flag].call("cat", "B")).to be false
    end

    it "has_flag returns false when there are no entries for the stem at all" do
      lookuper = described_class.from_data(minimal_aff, []).build
      expect(lookuper.dic[:has_flag].call("ghost", "A")).to be false
    end

    it "has_flag with for_all: true requires every entry to have the flag" do
      words = [word("bank", flags: Set.new(["A"])), word("bank", flags: Set.new(["B"]))]
      lookuper = described_class.from_data(minimal_aff, words).build
      expect(lookuper.dic[:has_flag].call("bank", "A", for_all: true)).to be false
      expect(lookuper.dic[:has_flag].call("bank", "A", for_all: false)).to be true
    end
  end

  describe "#build — ph: morph data folds into REP and alt_spellings" do
    it "extracts simple ph: payloads as alt_spellings on the word entry" do
      words = [word("which", morph_data: ["ph:wich"])]
      lookuper = described_class.from_data(minimal_aff, words).build
      entry = lookuper.dic[:words].first
      expect(entry[:alt_spellings]).to contain_exactly("wich")
    end

    it "appends a simple ph: payload to aff[:REP] as (wich, which)" do
      words = [word("which", morph_data: ["ph:wich"])]
      lookuper = described_class.from_data(minimal_aff, words).build
      rep = lookuper.aff[:REP].first
      expect(rep[:pattern]).to eq("wich")
      expect(rep[:replacement]).to eq("which")
    end

    it "extracts star ph: payloads as REP with trimmed pattern and stem" do
      # ph:prity* against "pretty" → REP(prit, prett).
      words = [word("pretty", morph_data: ["ph:prity*"])]
      lookuper = described_class.from_data(minimal_aff, words).build
      rep = lookuper.aff[:REP].first
      expect(rep[:pattern]).to eq("prit")
      expect(rep[:replacement]).to eq("prett")
    end

    it "star ph: payloads are NOT exposed as alt_spellings" do
      words = [word("pretty", morph_data: ["ph:prity*"])]
      lookuper = described_class.from_data(minimal_aff, words).build
      expect(lookuper.dic[:words].first[:alt_spellings]).to eq([])
    end

    it "extracts arrow ph: payloads as an explicit (from, to) REP pair" do
      words = [word("happy", morph_data: ["ph:hepi->happi"])]
      lookuper = described_class.from_data(minimal_aff, words).build
      rep = lookuper.aff[:REP].first
      expect(rep[:pattern]).to eq("hepi")
      expect(rep[:replacement]).to eq("happi")
    end

    it "arrow ph: payloads are NOT exposed as alt_spellings" do
      words = [word("happy", morph_data: ["ph:hepi->happi"])]
      lookuper = described_class.from_data(minimal_aff, words).build
      expect(lookuper.dic[:words].first[:alt_spellings]).to eq([])
    end

    it "ignores morph-data tokens that are not ph: payloads" do
      words = [word("cat", morph_data: ["st:cat", "po:noun"])]
      lookuper = described_class.from_data(minimal_aff, words).build
      expect(lookuper.aff[:REP]).to eq([])
      expect(lookuper.dic[:words].first[:alt_spellings]).to eq([])
    end
  end

  describe "PhRepExtractor module" do
    let(:extractor) { Kotoshu::Readers::PhRepExtractor }

    describe ".simple_alt_spellings" do
      it "returns only the simple payloads (no star, no arrow)" do
        expect(extractor.simple_alt_spellings("which", %w[wich prity*]))
          .to eq(["wich"])
      end

      it "returns empty for an empty ph_tokens array" do
        expect(extractor.simple_alt_spellings("x", [])).to eq([])
      end
    end

    describe ".append_to_aff" do
      it "is a no-op when ph_tokens is nil" do
        aff = {}
        extractor.append_to_aff(aff, "x", nil)
        expect(aff).to eq({})
      end

      it "is a no-op when ph_tokens is empty" do
        aff = {}
        extractor.append_to_aff(aff, "x", [])
        expect(aff).to eq({})
      end

      it "appends each payload as a REP-shaped hash" do
        aff = {}
        extractor.append_to_aff(aff, "which", ["wich"])
        expect(aff[:REP].length).to eq(1)
        expect(aff[:REP].first[:pattern]).to eq("wich")
        expect(aff[:REP].first[:replacement]).to eq("which")
      end

      it "appends to an existing REP array without overwriting" do
        aff = { REP: [{ pattern: "existing", replacement: "x", regexp: /x/ }] }
        extractor.append_to_aff(aff, "which", ["wich"])
        expect(aff[:REP].length).to eq(2)
      end
    end

    describe ".build_rep" do
      it "dispatches to star_rep when token ends with *" do
        rep = extractor.build_rep("pretty", "prity*")
        expect(rep.pattern).to eq("prit")
        expect(rep.replacement).to eq("prett")
      end

      it "dispatches to arrow_rep when token contains ->" do
        rep = extractor.build_rep("happy", "hepi->happi")
        expect(rep.pattern).to eq("hepi")
        expect(rep.replacement).to eq("happi")
      end

      it "dispatches to simple_rep otherwise" do
        rep = extractor.build_rep("which", "wich")
        expect(rep.pattern).to eq("wich")
        expect(rep.replacement).to eq("which")
      end
    end

    describe ".star_rep" do
      it "strips the last two chars of the pattern and the last char of the stem" do
        rep = extractor.star_rep("pretty", "prity*")
        expect(rep.pattern).to eq("prit")
        expect(rep.replacement).to eq("prett")
      end

      it "returns nil when the pattern is too short" do
        expect(extractor.star_rep("cat", "a*")).to be_nil
      end

      it "returns nil when the stem is too short" do
        expect(extractor.star_rep("c", "ab*")).to be_nil
      end
    end

    describe ".arrow_rep" do
      it "splits on -> into a (from, to) pair" do
        rep = extractor.arrow_rep("hepi->happi")
        expect(rep.pattern).to eq("hepi")
        expect(rep.replacement).to eq("happi")
      end

      it "returns nil when the from side is empty" do
        expect(extractor.arrow_rep("->happi")).to be_nil
      end

      it "returns nil when the to side is empty" do
        expect(extractor.arrow_rep("hepi->")).to be_nil
      end

      it "returns nil when there is no -> at all" do
        # split('->', 2) on a string with no arrow returns [whole, nil];
        # arrow_rep guards on nil 'to'.
        expect(extractor.arrow_rep("noarrow")).to be_nil
      end
    end

    describe ".simple_rep" do
      it "uses the token as the pattern and the stem as the replacement" do
        rep = extractor.simple_rep("which", "wich")
        expect(rep.pattern).to eq("wich")
        expect(rep.replacement).to eq("which")
      end

      it "returns nil when the token is empty" do
        expect(extractor.simple_rep("which", "")).to be_nil
      end
    end
  end
end
