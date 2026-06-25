# frozen_string: true

require "spec_helper"

RSpec.describe "en_US Hunspell correctness" do
  aff_path = File.expand_path("../../integrational/fixtures/en_US.aff", __dir__)
  dic_path = File.expand_path("../../integrational/fixtures/en_US.dic", __dir__)

  before(:all) do
    skip "en_US fixtures missing" unless File.exist?(aff_path) && File.exist?(dic_path)

    @dictionary = Kotoshu::Dictionary::Hunspell.new(
      dic_path: dic_path,
      aff_path: aff_path,
      language_code: "en-US"
    )
    @spellchecker = Kotoshu::Spellchecker.new(dictionary: @dictionary)
  end

  let(:spellchecker) { @spellchecker }
  let(:dictionary) { @dictionary }

  context "loading the dictionary" do
    it "loads a non-trivial number of words" do
      expect(dictionary.size).to be > 10_000
    end

    it "detects ISO-8859-1 encoding from the SET directive" do
      reader = Kotoshu::Readers::AffReader.new(aff_path)
      reader.read # populates @encoding
      expect(reader.encoding).to eq("ISO-8859-1")
    end
  end

  context "correctly-spelled English words" do
    %w[
      hello world ruby programming test
      cats dogs running quickly taller happiest
      computer keyboard language dictionary
    ].each do |word|
      it "accepts #{word.inspect}" do
        expect(spellchecker.correct?(word)).to eq(true)
      end
    end
  end

  context "common misspellings" do
    %w[helo wrld programmng tesst recieve seperate accross beleive enviroment].each do |word|
      it "rejects #{word.inspect}" do
        expect(spellchecker.correct?(word)).to eq(false)
      end
    end
  end

  context "affix-driven inflections" do
    {
      "cats" => "plural",
      "dogs" => "plural",
      "running" => "gerund",
      "quickly" => "adverb",
      "taller" => "comparative",
      "happiest" => "superlative"
    }.each do |word, form|
      it "accepts #{word.inspect} (#{form})" do
        expect(spellchecker.correct?(word)).to eq(true)
      end
    end
  end

  # 0.2.0 release acceptance: suggest("helo")[0] == "hello".
  # Kept minimal because each suggest() call iterates the full dictionary
  # through multiple strategies (~10s per call). The full suggestion
  # matrix lives in en_us_suggestion_quality_spec.rb tagged :slow.
  context "release acceptance suggestion test" do
    it "suggests 'hello' as the top correction for 'helo'" do
      top = spellchecker.suggest("helo").to_words.first
      expect(top).to eq("hello")
    end
  end
end
