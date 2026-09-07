# frozen_string_literal: true

require "spec_helper"

# Hangul tokenizer (plan 108): an eojeol is a run of Hangul syllables
# plus any bare jamo that escaped IME composition.
RSpec.describe Kotoshu::Language::Tokenizer::HangulTokenizer do
  subject(:tokenizer) { described_class.new }

  it "tokenizes space-delimited eojeol" do
    expect(tokenizer.tokenize("한국어 텍스트입니다"))
      .to contain_exactly("한국어", "텍스트입니다")
  end

  it "keeps bare jamo attached to the preceding block" do
    # ㄱ (compatibility jamo) after a syllable stays in the token
    expect(tokenizer.tokenize("학굑 사람"))
      .to contain_exactly("학굑", "사람")
  end

  it "stops at Latin, digits and punctuation" do
    expect(tokenizer.tokenize("SEOUL 서울123! 안녕"))
      .to contain_exactly("서울", "안녕")
  end

  it "exposes the eojeol set through the plan-91 contract" do
    expect(tokenizer.spellcheck_word_regex.match?("한")).to be(true)
    expect(tokenizer.spellcheck_word_regex.match?("ᄀ")).to be(true)
    expect(tokenizer.spellcheck_word_regex.match?("ㅟ")).to be(true)
    expect(tokenizer.spellcheck_word_regex.match?("a")).to be(false)
    expect(tokenizer.spellcheck_word_regex.match?("5")).to be(false)
    expect(tokenizer.spellcheck_word_regex.match?("'")).to be(false)
  end

  it "handles empty and nil text" do
    expect(tokenizer.tokenize("")).to eq([])
    expect(tokenizer.tokenize(nil)).to eq([])
  end
end

# Devanagari tokenizer (plan 108): matras and virama conjuncts stay
# attached to the base consonant — one script run is one word.
RSpec.describe Kotoshu::Language::Tokenizer::DevanagariTokenizer do
  subject(:tokenizer) { described_class.new }

  it "tokenizes words and keeps matras attached" do
    expect(tokenizer.tokenize("यो नेपाली पाठ हो"))
      .to contain_exactly("यो", "नेपाली", "पाठ", "हो")
  end

  it "keeps virama conjuncts intact" do
    expect(tokenizer.tokenize("विद्यालय विदयालय"))
      .to contain_exactly("विद्यालय", "विदयालय")
  end

  it "stops at the danda, Latin and digits" do
    expect(tokenizer.tokenize("किताब। kitab ४२ घर॥"))
      .to contain_exactly("किताब", "घर")
  end

  it "keeps ZWJ/ZWNJ conjunct spellings in-word" do
    expect(tokenizer.tokenize("क्‍ष श्री"))
      .to contain_exactly("क्‍ष", "श्री")
  end

  it "exposes the grapheme set through the plan-91 contract" do
    expect(tokenizer.spellcheck_word_regex.match?("क")).to be(true)
    expect(tokenizer.spellcheck_word_regex.match?("ि")).to be(true) # matra
    expect(tokenizer.spellcheck_word_regex.match?("्")).to be(true) # virama
    expect(tokenizer.spellcheck_word_regex.match?("a")).to be(false)
    expect(tokenizer.spellcheck_word_regex.match?("5")).to be(false)
  end

  it "handles empty and nil text" do
    expect(tokenizer.tokenize("")).to eq([])
    expect(tokenizer.tokenize(nil)).to eq([])
  end
end
