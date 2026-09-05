# frozen_string_literal: true

require "spec_helper"

# Inline ignore directives flowing through the Spellchecker facade
# (TODO.impl/82 Track A): suppressed words leave +errors+ and surface
# in +suppressed_errors+, marked suppressed_by "inline".
#
# Uses the offline plain-text fixture dictionary: hello/world/ruby/test/
# code/spelling/dictionary/kotoshu are correct; anything else (wrld,
# helo) is not. Directive keywords like "disable" or "next" are NOT in
# that dictionary, so directive comments themselves contribute
# suppressed entries - the directive line is never spellchecked, which
# is exactly the product behavior.
RSpec.describe Kotoshu::Spellchecker, "#check with ignore directives" do
  let(:spellchecker) do
    Kotoshu::Spellchecker.new(
      dictionary_path: "spec/fixtures/words.txt",
      dictionary_type: :plain_text,
      language: "en-US"
    )
  end

  it "keeps reporting misspellings without directives" do
    result = spellchecker.check("wrld helo\n")

    expect(result.errors.map(&:word)).to eq(%w[wrld helo])
    expect(result).to be_failed
    expect(result.suppressed_count).to eq(0)
  end

  it "moves errors on a disable-line into suppressed_errors" do
    result = spellchecker.check("kotoshu:disable-line wrld helo\n")

    expect(result.errors).to eq([])
    expect(result).to be_success
    expect(result.suppressed_errors.map(&:word)).to include("wrld", "helo")
  end

  it "marks suppressed entries with suppressed and suppressed_by" do
    result = spellchecker.check("kotoshu:disable-line wrld\n")
    entry = result.suppressed_errors.find { |e| e.word == "wrld" }

    expect(entry).to be_suppressed
    expect(entry.suppressed_by).to eq(Kotoshu::Models::Result::WordResult::SUPPRESSED_BY_INLINE)
    expect(entry.position).to be >= 0
  end

  it "suppresses only the listed words of disable-next-line" do
    source = "kotoshu:disable-next-line wrld\nwrld helo\n"
    result = spellchecker.check(source)

    expect(result.errors.map(&:word)).to eq(%w[helo])
    expect(result.suppressed_errors.select { |e| e.word == "wrld" }.size).to eq(2)
    expect(result.suppressed_errors.map(&:word)).not_to include("helo")
  end

  it "suppresses the whole next line without a word list" do
    source = "kotoshu:disable-next-line\nwrld helo\nhello world\n"
    result = spellchecker.check(source)

    expect(result.errors).to eq([])
    expect(result.suppressed_errors.map(&:word)).to include("wrld", "helo")
    # line 3 is untouched
    expect(result.suppressed_errors.map(&:word)).not_to include("hello", "world")
  end

  it "recognizes markdown HTML-comment directives via the auto profile" do
    source = "wrld hello <!-- kotoshu:disable-line -->\n"
    result = spellchecker.check(source)

    expect(result.errors).to eq([])
    expect(result.suppressed_errors.map(&:word)).to include("wrld")
  end

  it "recognizes asciidoc // directives via the auto profile" do
    source = "// kotoshu:disable-next-line wrld\nwrld helo\n"
    result = spellchecker.check(source)

    expect(result.errors.map(&:word)).to eq(%w[helo])
    expect(result.suppressed_errors.select { |e| e.word == "wrld" }.size).to eq(2)
  end

  it "suppresses a disable-file block across lines" do
    source = +"hello world\n"
    source << "kotoshu:disable-file\n"
    source << "wrld\n"
    source << "helo\n"
    source << "kotoshu:enable-file\n"
    source << "wrld\n"
    result = spellchecker.check(source)

    expect(result.errors.map(&:word)).to eq(%w[wrld])
    expect(result.suppressed_errors.map(&:word)).to include("wrld", "helo")
  end

  it "does not count suppressed words as failures but keeps the word count" do
    result = spellchecker.check("kotoshu:disable-line wrld\n")

    expect(result).to be_success
    expect(result.word_count).to eq(4)
  end
end
