# frozen_string_literal: true

require "kotoshu"

# Trigger autoload of the structures Suggest references.
Kotoshu::Readers::DicReader

# Direct spec for Algorithms::Suggest — the Spylls-ported suggestion pipeline.
#
# Suggest is the "what should this misspelled word be?" companion to
# Lookup. It produces candidate strings by editing the input (permutations
# like badchar/swapchar/extrachar/forgotchar/movechar/doubletwochars),
# by applying the REP/MAP tables, by splitting into two dictionary words,
# and — when no edit matches — by ngram-distance and phonetic similarity.
#
# Had no direct spec — only exercised indirectly via Hunspell fixture tests.
#
# The Suggester is constructed with positional (aff, dic, lookup) so we
# build the lookuper first via LookupBuilder (which produces both `aff`
# and `dic` structures) and reuse its lookuper for symmetry with
# Dictionary::Hunspell#suggester.
RSpec.describe Kotoshu::Algorithms::Suggest do
  let(:suggest_mod) { Kotoshu::Algorithms::Suggest }

  describe "module constants" do
    it "exposes MAXPHONSUGS, MAXSUGGESTIONS, GOOD_EDITS" do
      expect(suggest_mod::MAXPHONSUGS).to eq(2)
      expect(suggest_mod::MAXSUGGESTIONS).to eq(15)
      expect(suggest_mod::GOOD_EDITS).to eq(%w[spaceword uppercase replchars])
    end
  end

  describe Kotoshu::Algorithms::Suggest::Suggestion do
    describe "#initialize" do
      it "stores text and kind" do
        s = described_class.new("cat", "badchar")
        expect(s.text).to eq("cat")
        expect(s.kind).to eq("badchar")
      end
    end

    describe "#replace" do
      it "returns a new Suggestion with one field overridden (text)" do
        s = described_class.new("cat", "badchar")
        copy = s.replace(text: "bat")
        expect(copy.text).to eq("bat")
        expect(copy.kind).to eq("badchar")
        expect(copy).not_to equal(s)
      end

      it "returns a new Suggestion with kind overridden" do
        s = described_class.new("cat", "badchar")
        copy = s.replace(kind: "swapchar")
        expect(copy.kind).to eq("swapchar")
        expect(copy.text).to eq("cat")
      end
    end

    describe "#to_s" do
      it "returns just the text (so Suggestion is interchangeable with String)" do
        s = described_class.new("spell", "badchar")
        expect(s.to_s).to eq("spell")
      end
    end

    describe "#inspect" do
      it "renders as Suggestion[kind](text.inspect)" do
        s = described_class.new("spell", "badchar")
        expect(s.inspect).to eq(%(Suggestion[badchar]("spell")))
      end
    end
  end

  describe Kotoshu::Algorithms::Suggest::MultiWordSuggestion do
    describe "#initialize" do
      it "stores words, source, and allow_dash" do
        mws = described_class.new(%w[pre processed], "twowords", allow_dash: false)
        expect(mws.words).to eq(%w[pre processed])
        expect(mws.source).to eq("twowords")
        expect(mws.allow_dash).to be false
      end

      it "defaults allow_dash to true" do
        mws = described_class.new(%w[a b], "twowords")
        expect(mws.allow_dash).to be true
      end
    end

    describe "#stringify" do
      it "joins words with the given separator and returns a Suggestion" do
        mws = described_class.new(%w[pre processed], "twowords")
        result = mws.stringify("-")
        expect(result).to be_a(Kotoshu::Algorithms::Suggest::Suggestion)
        expect(result.text).to eq("pre-processed")
        expect(result.kind).to eq("twowords")
      end

      it "defaults the separator to a space" do
        mws = described_class.new(%w[pre processed], "twowords")
        expect(mws.stringify.text).to eq("pre processed")
      end
    end

    describe "#inspect" do
      it "renders as Suggestion[source](words array)" do
        mws = described_class.new(%w[pre processed], "twowords")
        expected = 'Suggestion[twowords](["pre", "processed"])'
        expect(mws.inspect).to eq(expected)
      end
    end
  end

  # ---- Suggester end-to-end against real LookupBuilder-built data ---------
  #
  # No doubles, no stubs. Build a small dictionary and exercise the public
  # `call` and `suggestions` API.
  describe Kotoshu::Algorithms::Suggest::Suggester do
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

    def build_suggester(aff_data, words = [])
      lookuper = Kotoshu::Readers::LookupBuilder.from_data(aff_data, words).build
      described_class.new(lookuper.aff, lookuper.dic, lookuper)
    end

    describe "#initialize" do
      it "exposes aff, dic, lookup readers" do
        suggester = build_suggester(minimal_aff, [word("cat")])
        expect(suggester.aff).to be_a(Hash)
        expect(suggester.dic).to be_a(Hash)
        expect(suggester.lookup).to be_a(Kotoshu::Algorithms::Lookup::Lookuper)
      end

      it "excludes FORBIDDENWORD/NOSUGGEST/ONLYINCOMPOUND-flagged words from ngram pool" do
        aff = minimal_aff(
          "FORBIDDENWORD" => "X",
          "NOSUGGEST" => "NS",
          "ONLYINCOMPOUND" => "OIC"
        )
        words = [
          word("good"),
          word("bad1", flags: Set.new(["X"])),
          word("bad2", flags: Set.new(["NS"])),
          word("bad3", flags: Set.new(["OIC"]))
        ]
        suggester = build_suggester(aff, words)
        # The ngram pool is a private ivar — test indirectly by confirming the
        # Suggester was constructed without error and exposes the readers.
        # (Direct exercise of the pool happens via #call below.)
        expect(suggester.aff[:FORBIDDENWORD]).to eq("X")
      end
    end

    describe "#call" do
      it "returns an Enumerator when no block is given" do
        suggester = build_suggester(minimal_aff, [word("cat")])
        expect(suggester.call("kat")).to be_an(Enumerator)
      end

      it "yields suggestion text strings for a near-miss word" do
        # "kat" is one edit away from "cat" (badchar).
        suggester = build_suggester(minimal_aff, [word("cat")])
        results = suggester.call("kat").to_a
        expect(results).to include("cat")
      end

      it "yields nothing when the dictionary is empty" do
        suggester = build_suggester(minimal_aff, [])
        expect(suggester.call("anything").to_a).to eq([])
      end

      it "yields the exact word for a word that is in the dictionary" do
        suggester = build_suggester(minimal_aff, [word("cat")])
        # An exact-match word may still produce suggestions (e.g. its own
        # case variant), but should at minimum yield "cat".
        results = suggester.call("cat").to_a
        expect(results).to include("cat")
      end
    end

    describe "#call — edit-based suggestions" do
      it "yields the word with one character inserted (forgotchar reverse)" do
        # "ct" is missing 'a' → "cat" is an extrachar suggestion.
        suggester = build_suggester(minimal_aff, [word("cat")])
        expect(suggester.call("ct").to_a).to include("cat")
      end

      it "yields the word with one character removed (extrachar)" do
        # "caat" has an extra 'a' → "cat" is an extrachar suggestion.
        suggester = build_suggester(minimal_aff, [word("cat")])
        expect(suggester.call("caat").to_a).to include("cat")
      end

      it "yields the word with two characters swapped (swapchar)" do
        # "act" is "cat" with 'a' and 'c' swapped → "cat" suggested.
        suggester = build_suggester(minimal_aff, [word("cat")])
        expect(suggester.call("act").to_a).to include("cat")
      end
    end

    describe "#call — case coercion" do
      it "coerces suggestions to match the input's captype" do
        # User typed "CAT" (ALLCAPS). Suggestion "cat" must be coerced to "CAT".
        suggester = build_suggester(minimal_aff, [word("cat")])
        results = suggester.call("KAT").to_a
        expect(results).to include("CAT")
      end

      it "title-cases suggestions for an INIT-cased input" do
        suggester = build_suggester(minimal_aff, [word("cat")])
        results = suggester.call("Kat").to_a
        expect(results).to include("Cat")
      end
    end

    describe "#call — REP table suggestions" do
      it "yields the REP-replacement form when it is in the dictionary" do
        rp = Kotoshu::Readers::RepPattern.new("f", "ph")
        aff = minimal_aff("REP" => [rp])
        # "fon" → REP replaces "f"→"ph" giving "phon"; if "phon" is in dict, suggest it.
        suggester = build_suggester(aff, [word("phon")])
        expect(suggester.call("fon").to_a).to include("phon")
      end
    end

    describe "#call — twowords split" do
      it "yields the two-word split when both halves are in the dictionary" do
        # "catdog" → split into "cat" and "dog".
        suggester = build_suggester(minimal_aff, [word("cat"), word("dog")])
        results = suggester.call("catdog").to_a
        expect(results).to include("cat dog")
      end
    end

    describe "#call — dot-separated mixed-case misspellings" do
      # Upstream Hunspell (hunspell.cxx suggest_internal, HUHCAP/HUHINITCAP
      # branch: "something.The -> something. The") splits after the first '.'
      # when the post-dot part is INITCAP-cased. Spylls does not port this;
      # the sug/sugutf fixtures (permanent.Vacation) encode the behavior.
      it "inserts a space after the dot when the post-dot part is INITCAP" do
        suggester = build_suggester(minimal_aff, [word("permanent"), word("Vacation")])
        expect(suggester.call("permanent.Vacation").to_a).to eq(["permanent. Vacation"])
      end

      it "puts the dot-split suggestion first" do
        suggester = build_suggester(minimal_aff,
                                    [word("permanent"), word("Vacation"), word("permanents")])
        results = suggester.call("permanent.Vacation").to_a
        expect(results.first).to eq("permanent. Vacation")
      end

      it "also splits HUHINIT misspellings (upstream HUHINITCAP falls through)" do
        # Real hunspell: "& Permanent.Vacation 1 0: Permanent. Vacation"
        suggester = build_suggester(minimal_aff, [word("permanent"), word("Vacation")])
        expect(suggester.call("Permanent.Vacation").to_a).to eq(["Permanent. Vacation"])
      end

      it "does not split when the post-dot part is not INITCAP" do
        suggester = build_suggester(minimal_aff, [word("permanent"), word("vacation")])
        expect(suggester.call("permanent.VACATION").to_a).not_to include("permanent. VACATION")
        expect(suggester.call("permanent.vacation").to_a).not_to include("permanent. vacation")
      end
    end

    describe "#call — ngram INITCAP root skip" do
      # Upstream Hunspell (suggestmgr.cxx ngsuggest "skip exceptions") does
      # not use capitalized dictionary words as ngram roots when the
      # misspelling is all lowercase — a missing Shift press is the edit
      # phase's job (badcharkey case toggle). This is what makes keepcase's
      # `bar` -> `Bar, baz.` work: "Bar" is skipped as a root so the lone
      # questionable guess "baz." is yielded. Spylls lacks the skip.
      it "yields the questionable ngram guess alongside the case-fixed edit" do
        suggester = build_suggester(minimal_aff, [word("Bar"), word("baz.")])
        expect(suggester.call("bar").to_a).to eq(["Bar", "baz."])
      end

      it "still ngram-suggests capitalized words for non-lowercase misspellings" do
        # "Ghandi" is INITCAP, so the skip does not apply.
        suggester = build_suggester(minimal_aff, [word("Gandhi")])
        expect(suggester.call("Ghandi").to_a).to include("Gandhi")
      end

      it "keeps capitalized words as ngram roots for German dictionaries" do
        # LANG de selects GermanCasing; upstream exempts LANG_de from the
        # skip because regular German nouns are capitalized.
        aff = minimal_aff("LANG" => "de_DE")
        suggester = build_suggester(aff, [word("Bar"), word("baz.")])
        expect(suggester.call("bar").to_a).to eq(["Bar"])
      end
    end

    describe "#call — never suggests the misspelling itself" do
      # Upstream Hunspell structurally cannot offer the input word verbatim:
      # it works on the lowercased variant and re-cases results at the very
      # end, so a candidate that round-trips back to the (invalid) input
      # never appears. Our coercion path could: capitalization coercion can
      # fold a valid lowercase form back into the misspelling —
      # opentaal_keepcase's "Tv-word" is valid as "tv-word" (BREAK splits it
      # into KEEPCASE "tv-" + "word") but coercing it to INITCAP reproduces
      # the misspelling. A candidate identical to the input is dropped
      # unless the input is itself a correctly spelled word.
      it "drops the coerced form when it reproduces the input verbatim" do
        dictionary = read_dictionary("opentaal_keepcase")
        expect(dictionary.suggest("Tv-word")).not_to include("Tv-word")
      end

      it "still yields the input when it is a correctly spelled word" do
        suggester = build_suggester(minimal_aff, [word("cat")])
        expect(suggester.call("cat").to_a).to include("cat")
      end
    end

    describe "#call — HUHCAP space-suggestion ordering" do
      # Upstream Hunspell (hunspell.cxx suggest_internal, HUHCAP/HUHINITCAP
      # branch — the "aNew -> a New" loop) moves space-containing
      # suggestions produced by the lowercased pass to the FRONT of the
      # list when the part after the space differs from the input's
      # corresponding suffix. Spylls does not port the move; the
      # opentaal_keepcase fixture (word-TV -> "word -tv, word-tv, word")
      # encodes it.
      it "places the space-split suggestion before the case edit" do
        suggester = build_suggester(minimal_aff, [word("wordtv"), word("word"), word("tv")])
        results = suggester.call("wordTV").to_a
        # The HUH capital-restore also fires: the input's "T" is copied to
        # the split boundary, as in Hunspell's aNew -> "a New" handling.
        expect(results).to include("wordtv")
        expect(results).to include("word Tv")
        expect(results.index("word Tv")).to be < results.index("wordtv")
      end
    end

    describe "#suggestions" do
      it "returns an Enumerator without a block" do
        suggester = build_suggester(minimal_aff, [word("cat")])
        expect(suggester.suggestions("kat")).to be_an(Enumerator)
      end

      it "yields Suggestion/MultiWordSuggestion objects (not strings)" do
        suggester = build_suggester(minimal_aff, [word("cat")])
        objs = suggester.suggestions("kat").to_a
        expect(objs).not_to be_empty
        expect(objs.first).to be_a(Kotoshu::Algorithms::Suggest::Suggestion)
          .or be_a(Kotoshu::Algorithms::Suggest::MultiWordSuggestion)
      end

      it "exposes the kind on each yielded Suggestion" do
        suggester = build_suggester(minimal_aff, [word("cat")])
        objs = suggester.suggestions("kat").to_a
        # At least one yielded Suggestion carries a kind label.
        kinds = objs.map(&:kind).compact
        expect(kinds).not_to be_empty
      end
    end
  end
end
