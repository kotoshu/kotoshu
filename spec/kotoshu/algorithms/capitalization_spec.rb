# frozen_string_literal: true

require "kotoshu"

# Direct spec for Algorithms::Capitalization — the Spylls-ported casing model.
#
# Casing drives the lookup-and-suggest pipeline's case handling:
# `guess` classifies a word, `variants`/`corrections` produce lookup
# hypotheses, `coerce` restores the original case on a found suggestion.
# TurkicCasing handles i↔İ / ı↔I; GermanCasing handles SS↔ß.
#
# Had no direct spec — only exercised indirectly via Hunspell fixture tests.
RSpec.describe Kotoshu::Algorithms::Capitalization do
  describe "Type constants" do
    it "exposes the five captype symbols" do
      expect(described_class::Type::NO).to eq(:no)
      expect(described_class::Type::INIT).to eq(:init)
      expect(described_class::Type::ALL).to eq(:all)
      expect(described_class::Type::HUH).to eq(:huh)
      expect(described_class::Type::HUHINIT).to eq(:huhinit)
    end
  end

  describe Kotoshu::Algorithms::Capitalization::Casing do
    describe "#guess" do
      it "returns NO for all-lowercase" do
        expect(described_class.new.guess("foo")).to eq(:no)
      end

      it "returns ALL for all-uppercase" do
        expect(described_class.new.guess("FOO")).to eq(:all)
      end

      it "returns INIT for first-letter-capitalized only" do
        expect(described_class.new.guess("Foo")).to eq(:init)
      end

      it "returns HUHINIT for mixed case with capitalized first letter" do
        expect(described_class.new.guess("FooBar")).to eq(:huhinit)
      end

      it "returns HUH for mixed case with lowercase first letter" do
        expect(described_class.new.guess("fooBar")).to eq(:huh)
      end
    end

    describe "#lower" do
      it "returns the downcased word as a single-element array" do
        expect(described_class.new.lower("FOO")).to eq(["foo"])
      end

      it "returns empty array for nil" do
        expect(described_class.new.lower(nil)).to eq([])
      end

      it "returns empty array for empty string" do
        expect(described_class.new.lower("")).to eq([])
      end

      it "returns empty array when first char is İ (cannot be lowered in non-Turkic)" do
        expect(described_class.new.lower("İstanbul")).to eq([])
      end

      it "normalizes the Turkic 'i̇' (i with combining dot) to plain 'i'" do
        expect(described_class.new.lower("FİSH")).to eq(["fish"])
      end
    end

    describe "#upper" do
      it "upcases the word" do
        expect(described_class.new.upper("foo")).to eq("FOO")
      end
    end

    describe "#capitalize" do
      it "yields the word with first letter upper and the rest lower (titlecase)" do
        results = described_class.new.capitalize("fOO").to_a
        expect(results).to eq(["Foo"])
      end

      it "handles a single-character word" do
        results = described_class.new.capitalize("f").to_a
        expect(results).to eq(["F"])
      end

      it "returns an Enumerator when no block is given" do
        expect(described_class.new.capitalize("foo")).to be_an(Enumerator)
      end
    end

    describe "#lowerfirst" do
      it "yields the word with first letter lowercased and rest preserved" do
        results = described_class.new.lowerfirst("FOO").to_a
        expect(results).to eq(["fOO"])
      end

      it "returns an Enumerator when no block is given" do
        expect(described_class.new.lowerfirst("FOO")).to be_an(Enumerator)
      end
    end

    describe "#variants (correctly-spelled hypotheses)" do
      it "returns [NO, [word]] for an all-lowercase word" do
        captype, variants = described_class.new.variants("foo")
        expect(captype).to eq(:no)
        expect(variants).to eq(["foo"])
      end

      it "returns [INIT, [word, *lower]] for a titlecase word" do
        captype, variants = described_class.new.variants("Foo")
        expect(captype).to eq(:init)
        expect(variants).to eq(["Foo", "foo"])
      end

      it "returns [HUH, [word]] for a mixed-case word with lowercase first" do
        captype, variants = described_class.new.variants("fooBar")
        expect(captype).to eq(:huh)
        expect(variants).to eq(["fooBar"])
      end

      it "returns [HUHINIT, [word, *lowerfirst]] for a mixed-case word with capitalized first" do
        captype, variants = described_class.new.variants("FooBar")
        expect(captype).to eq(:huhinit)
        expect(variants).to contain_exactly("FooBar", "fooBar")
      end

      it "returns [ALL, [word, *lower, *capitalize]] for an all-caps word" do
        captype, variants = described_class.new.variants("FOO")
        expect(captype).to eq(:all)
        expect(variants).to contain_exactly("FOO", "foo", "Foo")
      end
    end

    describe "#corrections (misspelling hypotheses)" do
      it "returns [NO, [word]] for an all-lowercase word" do
        captype, corrections = described_class.new.corrections("foo")
        expect(captype).to eq(:no)
        expect(corrections).to eq(["foo"])
      end

      it "returns [INIT, [word, *lower]] for a titlecase word" do
        captype, corrections = described_class.new.corrections("Foo")
        expect(captype).to eq(:init)
        expect(corrections).to contain_exactly("Foo", "foo")
      end

      it "returns [HUH, [word, *lower]] for a mixed-case word with lowercase first" do
        captype, corrections = described_class.new.corrections("fooBar")
        expect(captype).to eq(:huh)
        expect(corrections).to contain_exactly("fooBar", "foobar")
      end

      it "returns [HUHINIT, [word, *lowerfirst, *lower, *capitalize]] for a mixed-case word with capitalized first" do
        captype, corrections = described_class.new.corrections("FooBar")
        expect(captype).to eq(:huhinit)
        # All four hypotheses: original, lowerfirst, fully lowered, capitalized.
        expect(corrections).to contain_exactly("FooBar", "fooBar", "foobar", "Foobar")
      end

      it "returns [ALL, [word, *lower, *capitalize]] for an all-caps word" do
        captype, corrections = described_class.new.corrections("FOO")
        expect(captype).to eq(:all)
        expect(corrections).to contain_exactly("FOO", "foo", "Foo")
      end
    end

    describe "#coerce" do
      it "leaves a NO-cased suggestion unchanged" do
        expect(described_class.new.coerce("kitten", :no)).to eq("kitten")
      end

      it "title-cases an INIT/HUHINIT-cased suggestion (capitalizes first letter)" do
        expect(described_class.new.coerce("kitten", :init)).to eq("Kitten")
        expect(described_class.new.coerce("kitten", :huhinit)).to eq("Kitten")
      end

      it "uppercases an ALL-cased suggestion" do
        expect(described_class.new.coerce("kitten", :all)).to eq("KITTEN")
      end
    end
  end

  describe Kotoshu::Algorithms::Capitalization::TurkicCasing do
    describe "#lower" do
      it "translates uppercase I → ı (dotless i)" do
        expect(described_class.new.lower("Izmir")).to eq(["ızmir"])
      end

      it "translates uppercase İ → i (dotted i)" do
        expect(described_class.new.lower("İzmir")).to eq(["izmir"])
      end

      it "translates both I and İ in the same word" do
        # I → ı, İ → i; then super downcases (no-op here).
        expect(described_class.new.lower("Iİ")).to eq(["ıi"])
      end
    end

    describe "#upper" do
      it "translates lowercase i → İ (dotted capital)" do
        expect(described_class.new.upper("izmir")).to eq("İZMİR")
      end

      it "translates lowercase ı → I (dotless capital)" do
        expect(described_class.new.upper("ız")).to eq("IZ")
      end
    end

    it "is a subclass of Casing" do
      expect(described_class).to be < Kotoshu::Algorithms::Capitalization::Casing
    end
  end

  describe Kotoshu::Algorithms::Capitalization::GermanCasing do
    describe "#sharp_s_variants" do
      it "returns empty when there is no 'ss' in the text" do
        expect(described_class.new.sharp_s_variants("foo")).to eq([])
      end

      it "replaces a single 'ss' with ß" do
        expect(described_class.new.sharp_s_variants("strasse")).to include("straße")
      end

      it "produces multiple variants when 'ss' appears more than once" do
        variants = described_class.new.sharp_s_variants("strassenss")
        # Both 'ss' occurrences can be replaced; the union includes the
        # first-only, second-only, and both-replaced variants.
        expect(variants).to include("straßenss")  # first only
        expect(variants).to include("strassenß")  # second only
        expect(variants).to include("straßenß")   # both replaced
      end
    end

    describe "#lower" do
      it "returns [lowered] when there is no SS in the source" do
        expect(described_class.new.lower("FOO")).to eq(["foo"])
      end

      it "returns both ß and ss variants for an SS-containing uppercase word" do
        variants = described_class.new.lower("STRASSE")
        expect(variants).to include("straße")
        expect(variants).to include("strasse")
      end
    end

    describe "#guess" do
      it "classifies a word containing ß + uppercase letters as ALL caps" do
        # STRAßE — ß is allowed in uppercased German words.
        expect(described_class.new.guess("STRAßE")).to eq(:all)
      end

      it "falls back to the parent guess when ß is not present" do
        expect(described_class.new.guess("Foo")).to eq(:init)
      end
    end

    it "is a subclass of Casing" do
      expect(described_class).to be < Kotoshu::Algorithms::Capitalization::Casing
    end
  end
end
