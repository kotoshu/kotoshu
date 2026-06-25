# frozen_string: true

require "spec_helper"

# Comprehensive suggestion-quality regression spec.
# Tagged :slow because each suggest() call iterates the full 60K-word
# dictionary through multiple strategies (~10s per call). Not run by
# default; invoke with `rspec --tag slow`.
RSpec.describe "en_US suggestion quality", :slow do
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

  # Top suggestion must match the obvious correction.
  top_match_pairs = {
    "helo" => "hello",
    "wrld" => "world",
    "recieve" => "receive",
    "seperate" => "separate",
    "accross" => "across",
    "beleive" => "believe",
    "enviroment" => "environment"
  }

  top_match_pairs.each do |bad, expected|
    it "suggests #{expected.inspect} as the top correction for #{bad.inspect}" do
      top = spellchecker.suggest(bad).to_words.first
      expect(top).to eq(expected)
    end
  end

  # For contested cases, the expected word should appear in the top 10.
  top_n_pairs = {
    "tesst" => "test",
    "definitly" => "definitely",
    "wendsday" => "wednesday"
  }

  top_n_pairs.each do |bad, expected|
    it "includes #{expected.inspect} in the top-10 corrections for #{bad.inspect}" do
      top = spellchecker.suggest(bad).to_words.first(10)
      expect(top).to include(expected)
    end
  end
end
