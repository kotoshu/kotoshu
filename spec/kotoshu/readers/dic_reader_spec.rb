# frozen_string_literal: true

require "kotoshu"
require "tempfile"

# Direct spec for Readers::DicReader and Readers::Word (the dic-line parser).
#
# Hunspell .dic files are `<count>\n<stem[/flags][\tmorph]>\n...`. The parser
# must split stem from flags at the first UNESCAPED slash (Hunspell allows
# `\/` for literal `/` in a word), split morph data on tab OR on the first
# `key:value` token (real-world ph.* fixtures use spaces, not tabs), and
# respect FLAG short/long/num/UTF-8 formats plus AF flag aliases.
#
# Had no direct spec — only exercised indirectly via Hunspell fixture tests.
RSpec.describe Kotoshu::Readers::DicReader do
  let(:word_const) { Kotoshu::Readers::Word } # rubocop:disable RSpec/LeakyConstantDeclaration

  describe Kotoshu::Readers::Word do
    describe ".from_line (bare stem)" do
      it "parses a bare stem with no flags or morph data" do
        w = described_class.from_line("hello") # rubocop:disable RSpec/DescribedClass
        expect(w.stem).to eq("hello")
        expect(w.flags).to be_empty
        expect(w.morph_data).to be_empty
      end

      it "strips surrounding whitespace from the head" do
        w = described_class.from_line("  hello  ")
        expect(w.stem).to eq("hello")
      end
    end

    describe ".from_line (stem/flags with FLAG short)" do
      it "splits stem and flags at the unescaped slash" do
        w = described_class.from_line("cat/ABC", flag_format: "short")
        expect(w.stem).to eq("cat")
        expect(w.flags).to contain_exactly("A", "B", "C")
      end

      it "returns empty flags when no flag_format is in context" do
        # Without flag_format, the raw flag string is split into chars.
        w = described_class.from_line("cat/ABC")
        expect(w.stem).to eq("cat")
        expect(w.flags).to contain_exactly("A", "B", "C")
      end

      it "returns empty flags when flags string is empty" do
        w = described_class.from_line("cat/", flag_format: "short")
        expect(w.stem).to eq("cat")
        expect(w.flags).to be_empty
      end
    end

    describe ".from_line (escaped slash)" do
      it "treats \\/ as a literal slash inside the stem" do
        w = described_class.from_line("foo\\/bar")
        expect(w.stem).to eq("foo/bar")
        expect(w.flags).to be_empty
      end

      it "treats \\/ as literal and splits at the next unescaped slash" do
        w = described_class.from_line("foo\\/bar/A", flag_format: "short")
        expect(w.stem).to eq("foo/bar")
        expect(w.flags).to contain_exactly("A")
      end
    end

    describe ".from_line (leading slash)" do
      it "treats a leading slash as part of the stem, not empty-stem+flags" do
        # Without this special case, "/abc" would parse as stem="" + flags="abc".
        w = described_class.from_line("/abc")
        expect(w.stem).to eq("/abc")
        expect(w.flags).to be_empty
      end

      it "parses a single-slash entry as a word whose only char is /" do
        w = described_class.from_line("/")
        expect(w.stem).to eq("/")
        expect(w.flags).to be_empty
      end
    end

    describe ".from_line (morph data via tab)" do
      it "splits stem from morph data on the tab" do
        w = described_class.from_line("cat\tph:wih st:cat")
        expect(w.stem).to eq("cat")
        expect(w.morph_data).to contain_exactly("ph:wih", "st:cat")
        expect(w.flags).to be_empty
      end

      it "preserves the slash-split before the morph split" do
        w = described_class.from_line("cat/A\tph:wih", flag_format: "short")
        expect(w.stem).to eq("cat")
        expect(w.flags).to contain_exactly("A")
        expect(w.morph_data).to contain_exactly("ph:wih")
      end
    end

    describe ".from_line (morph data via key:value fallback)" do
      it "splits before the first key:value token when no tab is present" do
        # ph.* fixtures use spaces between stem and morph data.
        w = described_class.from_line("cat ph:wih st:cat")
        expect(w.stem).to eq("cat")
        expect(w.morph_data).to contain_exactly("ph:wih", "st:cat")
      end
    end

    describe ".from_line (FLAG long format)" do
      it "groups flag chars into 2-char tokens" do
        w = described_class.from_line("cat/ABCD", flag_format: "long")
        expect(w.flags).to contain_exactly("AB", "CD")
      end
    end

    describe ".from_line (FLAG num format)" do
      it "extracts numeric flag tokens" do
        w = described_class.from_line("cat/1,2,3", flag_format: "num")
        expect(w.flags).to contain_exactly("1", "2", "3")
      end
    end

    describe ".from_line (FLAG UTF-8 format)" do
      it "treats flag string as chars" do
        w = described_class.from_line("cat/ABC", flag_format: "UTF-8")
        expect(w.flags).to contain_exactly("A", "B", "C")
      end
    end

    describe ".from_line (AF flag aliases)" do
      it "resolves a numeric alias through flag_synonyms" do
        synonyms = { "1" => Set.new(%w[A B]) }
        w = described_class.from_line("cat/1",
                                      flag_format: "num",
                                      flag_synonyms: synonyms)
        expect(w.flags).to contain_exactly("A", "B")
      end

      it "returns empty set for an unknown alias index" do
        synonyms = { "1" => Set.new(%w[A]) }
        w = described_class.from_line("cat/99",
                                      flag_format: "num",
                                      flag_synonyms: synonyms)
        expect(w.flags).to be_empty
      end

      it "does not consult aliases when synonyms is empty" do
        # Without this guard, num dictionaries with no AF would collapse every
        # numeric flag to the empty set.
        w = described_class.from_line("cat/123", flag_format: "num")
        expect(w.flags).to contain_exactly("123")
      end
    end

    describe ".split_stem_and_morph" do
      it "splits on a tab when one is present" do
        head, morph = described_class.split_stem_and_morph("cat\tph:wih")
        expect(head).to eq("cat")
        expect(morph).to eq("ph:wih")
      end

      it "splits before the first key:value token when no tab is present" do
        # The leading whitespace before the first key:value token is captured
        # as part of the morph portion; parse_morph_data strips it later.
        head, morph = described_class.split_stem_and_morph("cat ph:wih st:cat")
        expect(head).to eq("cat")
        expect(morph).to eq(" ph:wih st:cat")
      end

      it "returns the whole line with empty morph when no separator is found" do
        head, morph = described_class.split_stem_and_morph("hello")
        expect(head).to eq("hello")
        expect(morph).to eq("")
      end
    end

    describe ".parse_morph_data" do
      it "returns empty array for nil" do
        expect(described_class.parse_morph_data(nil)).to eq([])
      end

      it "returns empty array for empty string" do
        expect(described_class.parse_morph_data("")).to eq([])
      end

      it "returns a single token" do
        expect(described_class.parse_morph_data("ph:wih")).to eq(["ph:wih"])
      end

      it "splits whitespace-separated tokens" do
        expect(described_class.parse_morph_data("ph:wih st:cat po:noun"))
          .to eq(%w[ph:wih st:cat po:noun])
      end

      it "collapses runs of whitespace" do
        expect(described_class.parse_morph_data("ph:wih   st:cat"))
          .to eq(%w[ph:wih st:cat])
      end
    end

    describe ".parse_flags" do
      it "returns empty set for nil" do
        expect(described_class.parse_flags(nil, "short")).to be_empty
      end

      it "returns empty set for empty string" do
        expect(described_class.parse_flags("", "short")).to be_empty
      end

      it "splits chars for short format" do
        expect(described_class.parse_flags("ABC", "short"))
          .to contain_exactly("A", "B", "C")
      end

      it "groups 2-char tokens for long format" do
        expect(described_class.parse_flags("ABCDEF", "long"))
          .to contain_exactly("AB", "CD", "EF")
      end

      it "extracts digit runs for num format" do
        expect(described_class.parse_flags("1,23,456", "num"))
          .to contain_exactly("1", "23", "456")
      end

      it "splits chars for UTF-8 format" do
        expect(described_class.parse_flags("ABC", "UTF-8"))
          .to contain_exactly("A", "B", "C")
      end

      it "falls back to char splitting for unknown formats" do
        expect(described_class.parse_flags("ABC", "bogus"))
          .to contain_exactly("A", "B", "C")
      end

      it "resolves AF aliases for pure-digit strings when synonyms exist" do
        synonyms = { "1" => Set.new(%w[A B]) }
        expect(described_class.parse_flags("1", "num", synonyms))
          .to contain_exactly("A", "B")
      end

      it "does not consult aliases when synonyms is empty" do
        expect(described_class.parse_flags("1", "num"))
          .to contain_exactly("1")
      end

      it "does not consult aliases for non-digit strings even with synonyms" do
        synonyms = { "1" => Set.new(%w[A]) }
        expect(described_class.parse_flags("AB", "short", synonyms))
          .to contain_exactly("A", "B")
      end
    end

    describe ".unescaped_slash_index" do
      it "returns nil for a string with no slash" do
        expect(described_class.unescaped_slash_index("hello")).to be_nil
      end

      it "returns the index of the first unescaped slash" do
        expect(described_class.unescaped_slash_index("a/b")).to eq(1)
      end

      it "skips an escaped slash and finds the next unescaped one" do
        expect(described_class.unescaped_slash_index("a\\/b/c")).to eq(4)
      end

      it "returns nil when every slash is escaped" do
        expect(described_class.unescaped_slash_index("a\\/b")).to be_nil
      end

      it "finds a slash at position 0" do
        expect(described_class.unescaped_slash_index("/abc")).to eq(0)
      end
    end
  end

  describe "Word struct shape" do
    it "exposes stem, flags, morph_data readers (keyword_init)" do
      w = Kotoshu::Readers::Word.new(stem: "x", flags: Set.new(["A"]),
                                     morph_data: ["ph:y"])
      expect(w.stem).to eq("x")
      expect(w.flags).to contain_exactly("A")
      expect(w.morph_data).to eq(["ph:y"])
    end
  end

  describe "#initialize" do
    it "exposes path, encoding, flag_format, flag_synonyms readers" do
      synonyms = { "1" => Set.new(%w[A]) }
      reader = described_class.new("en_US.dic",
                                   encoding: "ISO-8859-1",
                                   flag_format: "long",
                                   flag_synonyms: synonyms)
      expect(reader.path).to eq("en_US.dic")
      expect(reader.encoding).to eq("ISO-8859-1")
      expect(reader.flag_format).to eq("long")
      expect(reader.flag_synonyms).to eq(synonyms)
    end

    it "defaults encoding, flag_format, and flag_synonyms" do
      reader = described_class.new("en_US.dic")
      expect(reader.encoding).to eq("UTF-8")
      expect(reader.flag_format).to eq("short")
      expect(reader.flag_synonyms).to eq({})
    end
  end

  describe "#read" do
    it "skips the first line (word count header)" do
      Tempfile.create(["dic", ".dic"]) do |f|
        f.write("3\nfoo\nbar\nbaz\n")
        f.flush
        words = described_class.new(f.path).read
        expect(words.map(&:stem)).to contain_exactly("foo", "bar", "baz")
      end
    end

    it "parses flags using the configured flag_format" do
      Tempfile.create(["dic", ".dic"]) do |f|
        f.write("1\ncat/AB\n")
        f.flush
        words = described_class.new(f.path, flag_format: "long").read
        expect(words.first.stem).to eq("cat")
        expect(words.first.flags).to contain_exactly("AB")
      end
    end

    it "parses morph data following the tab" do
      Tempfile.create(["dic", ".dic"]) do |f|
        f.write("1\ncat\tph:wih st:cat\n")
        f.flush
        words = described_class.new(f.path).read
        expect(words.first.morph_data).to contain_exactly("ph:wih", "st:cat")
      end
    end

    it "returns an empty array for an empty dic body" do
      Tempfile.create(["dic", ".dic"]) do |f|
        f.write("0\n")
        f.flush
        expect(described_class.new(f.path).read).to eq([])
      end
    end

    it "resolves AF aliases when flag_synonyms is configured" do
      Tempfile.create(["dic", ".dic"]) do |f|
        f.write("1\ncat/1\n")
        f.flush
        synonyms = { "1" => Set.new(%w[A B]) }
        words = described_class.new(f.path,
                                    flag_format: "num",
                                    flag_synonyms: synonyms).read
        expect(words.first.flags).to contain_exactly("A", "B")
      end
    end
  end
end
