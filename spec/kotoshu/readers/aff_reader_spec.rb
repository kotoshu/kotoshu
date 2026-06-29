# frozen_string_literal: true

require "kotoshu"
require "tempfile"

# Direct spec for Readers::AffReader — the Hunspell .aff parser.
#
# Existing coverage in spec/unit/hunspell/aff_reader_spec.rb exercises
# REP/MAP/PFX/SFX/FLAG formats/AF aliases (with allow() stubs). This spec
# focuses on the directives the existing spec does NOT cover, plus the
# constructor and encoding-detection helpers — and uses no stubs (the
# AffReader is constructed with nil path and read against a StringReader).
RSpec.describe Kotoshu::Readers::AffReader do
  def read_aff(content)
    reader = described_class.new(nil)
    source = Kotoshu::Readers::StringReader.new(content)
    reader.read(source)
  end

  describe "#initialize" do
    it "exposes path, encoding, flag_format readers" do
      reader = described_class.new(nil, encoding: "UTF-8")
      expect(reader.path).to be_nil
      expect(reader.encoding).to eq("UTF-8")
      expect(reader.flag_format).to eq("short")
    end

    it "defaults flag_format to short" do
      expect(described_class.new(nil).flag_format).to eq("short")
    end

    it "defaults encoding to UTF-8 when path is nil" do
      expect(described_class.new(nil).encoding).to eq("UTF-8")
    end

    it "defaults encoding to UTF-8 when path is empty" do
      expect(described_class.new("").encoding).to eq("UTF-8")
    end
  end

  describe "STRING directives" do
    it "parses SET as a raw string" do
      result = read_aff("SET ISO8859-1\n")
      expect(result["SET"]).to eq("ISO8859-1")
    end

    it "parses KEY as a raw string" do
      result = read_aff("KEY qwertyuiop|asdfghjkl|zxcvbnm\n")
      expect(result["KEY"]).to eq("qwertyuiop|asdfghjkl|zxcvbnm")
    end

    it "parses TRY as a raw string" do
      result = read_aff("TRY aabcdefghijklmnopqrstuvwxyz\n")
      expect(result["TRY"]).to eq("aabcdefghijklmnopqrstuvwxyz")
    end

    it "parses WORDCHARS as a raw string" do
      result = read_aff("WORDCHARS abc\n")
      expect(result["WORDCHARS"]).to eq("abc")
    end

    it "parses LANG as a raw string" do
      result = read_aff("LANG en_US\n")
      expect(result["LANG"]).to eq("en_US")
    end
  end

  describe "INTEGER directives" do
    %w[MAXDIFF MAXNGRAMSUGS MAXCPDSUGS COMPOUNDMIN COMPOUNDWORDMAX].each do |dir|
      it "parses #{dir} as an integer" do
        result = read_aff("#{dir} 5\n")
        expect(result[dir]).to eq(5)
      end
    end

    it "returns nil for INTEGER directives with no value" do
      result = read_aff("MAXDIFF\n")
      expect(result["MAXDIFF"]).to be_nil
    end
  end

  describe "BOOLEAN directives" do
    %w[COMPLEXPREFIXES FULLSTRIP NOSPLITSUGS CHECKSHARPS
       CHECKCOMPOUNDCASE CHECKCOMPOUNDDUP CHECKCOMPOUNDREP CHECKCOMPOUNDTRIPLE
       SIMPLIFIEDTRIPLE ONLYMAXDIFF COMPOUNDMORESUFFIXES].each do |dir|
      it "#{dir} parses as true" do
        result = read_aff("#{dir}\n")
        expect(result[dir]).to be true
      end
    end
  end

  describe "FLAG directives (single-flag value)" do
    %w[KEEPCASE CIRCUMFIX NEEDAFFIX FORBIDDENWORD WARN
       COMPOUNDFLAG COMPOUNDBEGIN COMPOUNDMIDDLE COMPOUNDEND
       ONLYINCOMPOUND COMPOUNDPERMITFLAG COMPOUNDFORBIDFLAG FORCEUCASE
       SUBSTANDARD SYLLABLENUM COMPOUNDROOT].each do |dir|
      it "#{dir} parses as a single flag string" do
        result = read_aff("#{dir} A\n")
        expect(result[dir]).to eq("A")
      end
    end
  end

  describe "synonym resolution" do
    it "rewrites PSEUDOROOT to NEEDAFFIX" do
      result = read_aff("PSEUDOROOT A\n")
      expect(result["NEEDAFFIX"]).to eq("A")
      expect(result.key?("PSEUDOROOT")).to be false
    end

    it "rewrites COMPOUNDLAST to COMPOUNDEND" do
      result = read_aff("COMPOUNDLAST A\n")
      expect(result["COMPOUNDEND"]).to eq("A")
      expect(result.key?("COMPOUNDLAST")).to be false
    end
  end

  describe "IGNORE directive" do
    it "returns an Ignore instance exposing the chars" do
      result = read_aff("IGNORE '\n")
      ignore = result["IGNORE"]
      expect(ignore).to be_a(Kotoshu::Readers::Ignore)
      expect(ignore.chars).to eq("'")
    end

    it "returns an Ignore instance even with no chars" do
      result = read_aff("IGNORE\n")
      ignore = result["IGNORE"]
      expect(ignore).to be_a(Kotoshu::Readers::Ignore)
      expect(ignore.chars).to eq("")
    end
  end

  describe "BREAK directive" do
    it "parses count + N break patterns" do
      content = <<~AFF
        BREAK 2
        BREAK -
        BREAK n't
      AFF
      result = read_aff(content)
      expect(result["BREAK"]).to all(be_a(Kotoshu::Readers::BreakPattern))
      expect(result["BREAK"].map(&:pattern)).to contain_exactly("-", "n't")
    end

    it "returns an empty array when count is 0" do
      result = read_aff("BREAK 0\n")
      expect(result["BREAK"]).to eq([])
    end
  end

  describe "COMPOUNDRULE directive" do
    it "parses count + N compound rules" do
      content = <<~AFF
        COMPOUNDRULE 1
        COMPOUNDRULE (A)(B)
      AFF
      result = read_aff(content)
      expect(result["COMPOUNDRULE"]).to all(be_a(Kotoshu::Readers::CompoundRule))
      expect(result["COMPOUNDRULE"].first.text).to eq("(A)(B)")
    end
  end

  describe "ICONV / OCONV directives" do
    it "parses ICONV count + N conversion pairs" do
      content = <<~AFF
        ICONV 2
        ICONV á a
        ICONV é e
      AFF
      result = read_aff(content)
      conv = result["ICONV"]
      expect(conv).to be_a(Kotoshu::Readers::ConvTable)
      expect(conv.pairs).to contain_exactly(["á", "a"], ["é", "e"])
    end

    it "parses OCONV count + N conversion pairs" do
      content = <<~AFF
        OCONV 1
        OCONV a á
      AFF
      result = read_aff(content)
      conv = result["OCONV"]
      expect(conv).to be_a(Kotoshu::Readers::ConvTable)
      expect(conv.pairs).to contain_exactly(["a", "á"])
    end
  end

  describe "CHECKCOMPOUNDPATTERN directive" do
    it "parses count + N compound patterns" do
      content = <<~AFF
        CHECKCOMPOUNDPATTERN 1
        CHECKCOMPOUNDPATTERN 0 foo bar
      AFF
      result = read_aff(content)
      pat = result["CHECKCOMPOUNDPATTERN"].first
      expect(pat).to be_a(Kotoshu::Readers::CompoundPattern)
      expect(pat.left).to eq("0")
      expect(pat.right).to eq("foo")
      expect(pat.replacement).to eq("bar")
    end
  end

  describe "AM directive (morphological aliases)" do
    it "parses count + N morph alias sets" do
      content = <<~AFF
        AM 2
        AM st:foo
        AM po:noun
      AFF
      result = read_aff(content)
      expect(result["AM"]).to eq({
                                   "1" => Set.new(["st:foo"]),
                                   "2" => Set.new(["po:noun"])
                                 })
    end
  end

  describe "COMPOUNDSYLLABLE directive" do
    it "returns a [count, flag] pair" do
      result = read_aff("COMPOUNDSYLLABLE 3 A\n")
      expect(result["COMPOUNDSYLLABLE"]).to eq([3, "A"])
    end
  end

  describe "PHONE directive" do
    it "parses count + N phone rules into a PhonetTable" do
      content = <<~AFF
        PHONE 1
        PHONE A a
      AFF
      result = read_aff(content)
      table = result["PHONE"]
      expect(table).to be_a(Kotoshu::Readers::PhonetTable)
      expect(table).not_to be_empty
    end
  end

  describe "FLAG format switching" do
    it "updates flag_format when FLAG is encountered" do
      result = read_aff("FLAG long\n")
      expect(result["FLAG"]).to eq("long")
    end

    it "applies the new flag format to FLAG directives that follow it" do
      content = <<~AFF
        FLAG long

        NOSUGGEST AB
      AFF
      result = read_aff(content)
      # FLAG long means NOSUGGEST consumes 2 chars as one flag.
      expect(result["NOSUGGEST"]).to eq("AB")
    end
  end

  describe "SFX / PFX grouping" do
    it "groups SFX entries under their flag" do
      content = <<~AFF
        SFX A Y 2
        SFX A 0 s .
        SFX A 0 es .
      AFF
      result = read_aff(content)
      expect(result["SFX"]).to be_a(Hash)
      expect(result["SFX"]["A"]).to be_an(Array)
      expect(result["SFX"]["A"].length).to eq(2)
      expect(result["SFX"]["A"].map(&:add)).to contain_exactly("s", "es")
      expect(result["SFX"]["A"].first.flag).to eq("A")
      expect(result["SFX"]["A"].first).to be_suffix
    end

    it "groups PFX entries under their flag" do
      content = <<~AFF
        PFX A Y 1
        PFX A 0 re .
      AFF
      result = read_aff(content)
      expect(result["PFX"]["A"].first.add).to eq("re")
      expect(result["PFX"]["A"].first).to be_prefix
    end

    it "treats strip/add value '0' as the empty string" do
      content = <<~AFF
        SFX A Y 1
        SFX A 0 s .
      AFF
      result = read_aff(content)
      sfx = result["SFX"]["A"].first
      expect(sfx.strip).to eq("")
      expect(sfx.add).to eq("s")
    end

    it "parses flags embedded in the add field via '/X'" do
      content = <<~AFF
        SFX A Y 1
        SFX A 0 able/CD .
      AFF
      result = read_aff(content)
      sfx = result["SFX"]["A"].first
      expect(sfx.add).to eq("able")
      expect(sfx.flags).to contain_exactly("C", "D")
    end

    it "parses crossproduct Y as true and N as false" do
      content_y = <<~AFF
        SFX A Y 1
        SFX A 0 s .
      AFF
      content_n = <<~AFF
        SFX A N 1
        SFX A 0 s .
      AFF
      expect(read_aff(content_y)["SFX"]["A"].first.crossproduct).to be true
      expect(read_aff(content_n)["SFX"]["A"].first.crossproduct).to be false
    end
  end

  describe "AF directive (flag aliases)" do
    it "builds a positional index → flag-set map" do
      content = <<~AFF
        AF 2
        AF ABC
        AF DE
      AFF
      result = read_aff(content)
      expect(result["AF"]["1"]).to contain_exactly("A", "B", "C")
      expect(result["AF"]["2"]).to contain_exactly("D", "E")
    end
  end

  describe "lines that are not directives" do
    it "ignores non-alphabetic lines" do
      result = read_aff("123\n# comment\n")
      expect(result.key?("123")).to be false
    end

    it "ignores lowercase lines (directives must be all caps)" do
      result = read_aff("foo bar\n")
      expect(result.key?("foo")).to be false
    end

    it "ignores unknown directives" do
      result = read_aff("BOGUS value\n")
      expect(result.key?("BOGUS")).to be false
    end
  end

  describe "encoding detection from real files" do
    it "uses the SET directive when present" do
      Tempfile.create(["aff", ".aff"]) do |f|
        f.write("SET ISO8859-1\n")
        f.flush
        reader = described_class.new(f.path)
        expect(reader.encoding).to eq("ISO-8859-1")
      end
    end

    it "normalizes ISO8859-N to ISO-8859-N" do
      Tempfile.create(["aff", ".aff"]) do |f|
        f.write("SET ISO8859-15\n")
        f.flush
        reader = described_class.new(f.path)
        expect(reader.encoding).to eq("ISO-8859-15")
      end
    end

    it "passes UTF-8 through unchanged" do
      Tempfile.create(["aff", ".aff"]) do |f|
        f.write("SET UTF-8\n")
        f.flush
        reader = described_class.new(f.path)
        expect(reader.encoding).to eq("UTF-8")
      end
    end

    it "defaults to UTF-8 when SET is missing and bytes are valid UTF-8" do
      Tempfile.create(["aff", ".aff"]) do |f|
        f.write("TRY abc\n")
        f.flush
        reader = described_class.new(f.path)
        expect(reader.encoding).to eq("UTF-8")
      end
    end

    it "defaults to ISO-8859-1 when SET is missing and bytes are not valid UTF-8" do
      Tempfile.create(["aff", ".aff"]) do |f|
        f.binmode
        f.write("\xff\xfe TRY abc\n")
        f.flush
        reader = described_class.new(f.path)
        expect(reader.encoding).to eq("ISO-8859-1")
      end
    end
  end
end
