# frozen_string_literal: true

require "spec_helper"

# Script classification for module-less languages (plan 107): every
# staged language without a gem module still gets the plan-91 word
# extraction for its script; unknown codes keep the ASCII fallback.
RSpec.describe Kotoshu::Language::Script do
  describe ".script_for" do
    it "classifies the staged non-Latin languages" do
      expect(described_class.script_for("mk")).to eq(:cyrillic)
      expect(described_class.script_for("mn")).to eq(:cyrillic)
      expect(described_class.script_for("el")).to eq(:greek)
      expect(described_class.script_for("el-polyton")).to eq(:greek)
      expect(described_class.script_for("hy")).to eq(:armenian)
      expect(described_class.script_for("hyw")).to eq(:armenian)
      expect(described_class.script_for("ka")).to eq(:georgian)
      expect(described_class.script_for("ne")).to eq(:devanagari)
      expect(described_class.script_for("ko")).to eq(:hangul)
    end

    it "defaults to latin" do
      expect(described_class.script_for("is")).to eq(:latin)
      expect(described_class.script_for("cy")).to eq(:latin)
      expect(described_class.script_for("xx")).to eq(:latin)
      expect(described_class.script_for(nil)).to eq(:latin)
    end

    it "normalizes region variants like the resource manager does" do
      expect(described_class.script_for("sv-FI")).to eq(:latin)
      expect(described_class.script_for("mk-MK")).to eq(:cyrillic)
      expect(described_class.script_for("ko-KR")).to eq(:hangul)
    end
  end

  describe ".tokenizer_for" do
    it "serves the shared Latin tokenizer for staged Latin languages" do
      expect(described_class.tokenizer_for("is"))
        .to be_a(Kotoshu::Language::Tokenizer::LatinTokenizer)
      expect(described_class.tokenizer_for("gd"))
        .to be_a(Kotoshu::Language::Tokenizer::LatinTokenizer)
    end

    it "reuses the dedicated script tokenizers" do
      expect(described_class.tokenizer_for("mk"))
        .to be_a(Kotoshu::Language::Tokenizer::CyrillicTokenizer)
      expect(described_class.tokenizer_for("el-polyton"))
        .to be_a(Kotoshu::Language::Tokenizer::GreekTokenizer)
    end

    it "serves a script tokenizer for scripts without a dedicated class" do
      ko = described_class.tokenizer_for("ko")
      expect(ko).to be_a(Kotoshu::Language::Tokenizer::ScriptTokenizer)
      expect(ko.spellcheck_word_regex).to eq(/\p{Hangul}/)

      ne = described_class.tokenizer_for("ne")
      expect(ne.spellcheck_word_regex).to eq(/\p{Devanagari}/)

      hyw = described_class.tokenizer_for("hyw")
      expect(hyw.spellcheck_word_regex).to eq(/\p{Armenian}/)
    end

    it "returns nil for languages outside the manifest" do
      expect(described_class.tokenizer_for("xx")).to be_nil
      expect(described_class.tokenizer_for("")).to be_nil
      expect(described_class.tokenizer_for(nil)).to be_nil
    end

    it "keeps every script token a word character and digits out" do
      tokenizer = described_class.tokenizer_for("ne")
      expect(tokenizer.spellcheck_word_regex.match?("क")).to be(true)
      expect(tokenizer.spellcheck_word_regex.match?("ा")).to be(true)
      expect(tokenizer.spellcheck_word_regex.match?("5")).to be(false)

      tokenizer = described_class.tokenizer_for("ko")
      expect(tokenizer.spellcheck_word_regex.match?("한")).to be(true)
      expect(tokenizer.spellcheck_word_regex.match?("ㄱ")).to be(true)
      expect(tokenizer.spellcheck_word_regex.match?("a")).to be(false)
    end
  end
end

RSpec.describe Kotoshu::Language::Tokenizer::ScriptTokenizer do
  subject(:tokenizer) { described_class.new(word_regex: /\p{Georgian}/) }

  it "tokenizes runs of script characters" do
    expect(tokenizer.tokenize("საქართველო არის ქვეყანა"))
      .to contain_exactly("საქართველო", "არის", "ქვეყანა")
  end

  it "stops at non-script characters" do
    expect(tokenizer.tokenize("ka-ka სახელი!"))
      .to contain_exactly("სახელი")
  end

  it "exposes the regex through the plan-91 contract" do
    expect(tokenizer.spellcheck_word_regex).to eq(/\p{Georgian}/)
    expect(tokenizer.word_boundary_regex).to eq(/\p{Georgian}/)
  end

  it "handles empty and nil text" do
    expect(tokenizer.tokenize("")).to eq([])
    expect(tokenizer.tokenize(nil)).to eq([])
  end
end
