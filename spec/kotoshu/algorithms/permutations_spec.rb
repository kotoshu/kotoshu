# frozen_string_literal: true

require "kotoshu"
require "set"

# Direct spec for Algorithms::Permutations — the Spylls-ported word-edit
# generators used by the Hunspell suggestion engine.
#
# Each method is a pure function (word, optional table) that yields edit
# variants. Had no direct spec — only exercised indirectly via integration
# tests on Hunspell's suggest fixture.
RSpec.describe Kotoshu::Algorithms::Permutations do
  def collect(word, method, *args)
    results = []
    described_class.public_send(method, word, *args) { |r| results << r }
    results
  end

  describe "MAX_CHAR_DISTANCE constant" do
    it "is 4" do
      expect(described_class::MAX_CHAR_DISTANCE).to eq(4)
    end
  end

  describe ".replchars" do
    let(:reptable) do
      [{ regexp: /ac/, replacement: "ex" }]
    end

    it "yields each replaced variant" do
      results = collect("acces", :replchars, reptable)
      expect(results).to include("exces")
    end

    it "yields a list variant when the replacement introduces a space" do
      spaced = [{ regexp: /foo/, replacement: "bar_baz" }]
      results = collect("foo", :replchars, spaced)
      expect(results).to include("bar baz")
      expect(results).to include(["bar", "baz"])
    end

    it "returns nothing (yields nothing) for words shorter than 2 chars" do
      results = collect("a", :replchars, reptable)
      expect(results).to be_empty
    end

    it "returns nothing for an empty reptable" do
      expect(collect("hello", :replchars, [])).to be_empty
    end

    it "returns nothing for a nil reptable" do
      expect(collect("hello", :replchars, nil)).to be_empty
    end

    it "yields multiple matches when the pattern occurs more than once" do
      multi = [{ regexp: /a/, replacement: "A" }]
      results = collect("banana", :replchars, multi)
      # Each 'a' occurrence yields a separate variant.
      expect(results.size).to be >= 3
    end
  end

  describe ".mapchars" do
    let(:maptable) do
      [Set.new(%w[a á ã])]
    end

    it "yields variants with mapped characters" do
      results = collect("anarchia", :mapchars, maptable)
      expect(results).to include("ánarchia")
    end

    it "recurses to map multiple positions" do
      results = collect("anarchia", :mapchars, maptable)
      expect(results).to include("ánárchia")
    end

    it "returns nothing for words shorter than 2 chars" do
      expect(collect("a", :mapchars, maptable)).to be_empty
    end

    it "returns nothing for nil maptable" do
      expect(collect("hello", :mapchars, nil)).to be_empty
    end

    it "returns nothing for empty maptable" do
      expect(collect("hello", :mapchars, [])).to be_empty
    end
  end

  describe ".swapchar" do
    it "yields single-adjacent swaps" do
      results = collect("abcd", :swapchar)
      expect(results).to include("bacd")
      expect(results).to include("acbd")
      expect(results).to include("abdc")
    end

    it "yields double swaps for 4-letter words" do
      results = collect("ahev", :swapchar)
      # 'ahev' -> 'have' via double swap
      expect(results).to include("have")
    end

    it "yields double swaps for 5-letter words" do
      results = collect("owudl", :swapchar)
      expect(results).to include("would")
    end

    it "returns nothing for words shorter than 2 chars" do
      expect(collect("a", :swapchar)).to be_empty
    end
  end

  describe ".longswapchar" do
    it "yields non-adjacent swaps within MAX_CHAR_DISTANCE" do
      results = collect("abcdef", :longswapchar)
      # swap positions 0 and 2 (distance 2): cbadef
      expect(results).to include("cbadef")
    end

    it "does not swap adjacent positions (those are swapchar's job)" do
      results = collect("abcd", :longswapchar)
      expect(results).not_to include("bacd")
    end

    it "returns nothing for words too short for non-adjacent swaps" do
      expect(collect("ab", :longswapchar)).to be_empty
    end
  end

  describe ".badcharkey" do
    let(:layout) { "qwertyuiop|asdfghjkl|zxcvbnm" }

    it "yields the uppercase variant when char is lowercase" do
      results = collect("hello", :badcharkey, layout)
      expect(results).to include("Hello")
    end

    it "does not yield uppercase for already-uppercase chars" do
      results = collect("HELLO", :badcharkey, layout)
      # Already uppercase — no uppercase variants yielded.
      expect(results).not_to include("HELLO")
    end

    it "yields adjacent-key variants" do
      results = collect("vat", :badcharkey, layout)
      # 'a' is at position 1 in 'asdfghjkl' (after the | at index 10).
      # Adjacent keys are 's' (right) and 'q'/'w' on top row.
      expect(results).to include("vst")
    end

    it "yields nothing for keys not in the layout" do
      # Special chars not in the layout get only the uppercase variant.
      results = collect("a!b", :badcharkey, layout)
      expect(results).to include("A!b")
    end
  end

  describe ".extrachar" do
    it "yields every single-char deletion" do
      results = collect("abc", :extrachar)
      expect(results).to contain_exactly("bc", "ac", "ab")
    end

    it "returns nothing for words shorter than 2 chars" do
      expect(collect("a", :extrachar)).to be_empty
    end
  end

  describe ".forgotchar" do
    it "yields every single-char insertion from trystring" do
      results = collect("ab", :forgotchar, "xy")
      expect(results).to include("xab", "axb", "abx")
      expect(results).to include("yab", "ayb", "aby")
    end

    it "returns nothing for nil trystring" do
      expect(collect("ab", :forgotchar, nil)).to be_empty
    end

    it "returns nothing for empty trystring" do
      expect(collect("ab", :forgotchar, "")).to be_empty
    end
  end

  describe ".movechar" do
    it "yields chars moved forward by 2-4 positions" do
      results = collect("abcde", :movechar)
      # Moving 'a' (pos 0) to pos 3: bcade
      expect(results).to include("bcade")
    end

    it "yields chars moved backward by 2-4 positions" do
      results = collect("abcde", :movechar)
      # Moving 'd' (pos 3) to pos 0: dabce
      expect(results).to include("dabce")
    end

    it "returns nothing for words shorter than 2 chars" do
      expect(collect("a", :movechar)).to be_empty
    end
  end

  describe ".badchar" do
    it "yields chars replaced with chars from trystring" do
      results = collect("abc", :badchar, "xy")
      expect(results).to include("xbc", "ayc", "abx")
      expect(results).to include("ybc", "ayc") # 'y' is also tried
    end

    it "does not yield when the replacement char equals the existing one" do
      results = collect("abc", :badchar, "a")
      # 'a' would replace position 0 with 'a' — skip.
      expect(results).not_to include("abc")
      # But 'a' replaces positions 1 and 2 with 'a'.
      expect(results).to include("aac", "aba")
    end

    it "returns nothing for nil trystring" do
      expect(collect("abc", :badchar, nil)).to be_empty
    end

    it "returns nothing for empty trystring" do
      expect(collect("abc", :badchar, "")).to be_empty
    end
  end

  describe ".doubletwochars" do
    it "collapses accidental doubling like 'vacacation' -> 'vacation'" do
      results = collect("vacacation", :doubletwochars)
      expect(results).to include("vacation")
    end

    it "returns nothing for words shorter than 5 chars" do
      expect(collect("abcd", :doubletwochars)).to be_empty
    end

    it "returns nothing when no doubling pattern is present" do
      expect(collect("hello", :doubletwochars)).to be_empty
    end
  end

  describe ".twowords" do
    it "yields every two-word split" do
      results = collect("hello", :twowords)
      expect(results).to include(["h", "ello"])
      expect(results).to include(["hel", "lo"])
      expect(results).to include(["hell", "o"])
    end

    it "yields (n-1) splits for an n-char word" do
      results = collect("abcd", :twowords)
      expect(results.size).to eq(3)
    end
  end
end
