# frozen_string_literal: true

require "spec_helper"
require "json"

# The thirteen wave-1 language modules (plan 84, Track B): ca cs da
# el hu it nl pl ro sv tr uk vi. Each is a thin composition — shared
# Latin tokenizer, normalizer, registry entry — with real dictionary
# words from the fixture (no doubles).
RSpec.describe "wave-1 language modules" do
  MODULES = {
    "ca" => Kotoshu::Languages::Catalan,
    "cs" => Kotoshu::Languages::Czech,
    "da" => Kotoshu::Languages::Danish,
    "el" => Kotoshu::Languages::Greek,
    "hu" => Kotoshu::Languages::Hungarian,
    "it" => Kotoshu::Languages::Italian,
    "nl" => Kotoshu::Languages::Dutch,
    "pl" => Kotoshu::Languages::Polish,
    "ro" => Kotoshu::Languages::Romanian,
    "sv" => Kotoshu::Languages::Swedish,
    "tr" => Kotoshu::Languages::Turkish,
    "uk" => Kotoshu::Languages::Ukrainian,
    "vi" => Kotoshu::Languages::Vietnamese
  }.freeze

  fixture_path = File.expand_path("../../fixtures/languages/wave1_languages.json", __dir__)
  fixture = JSON.parse(File.read(fixture_path))
  LANGUAGES_FIXTURE = fixture.freeze

  def fixture_for(code)
    LANGUAGES_FIXTURE.fetch("languages").fetch(code)
  end

  RSpec.shared_examples "a registered language module" do |code, klass|
    it "registers #{code} in the language registry" do
      expect(Kotoshu::Language.get(code)).to eq(klass)
      expect(Kotoshu::Language.registered?(code)).to be true
    end

    it "exposes the code and name" do
      language = klass.new
      expect(language.code).to eq(code)
      expect(language.name).not_to be_empty
    end

    it "builds the singleton instance" do
      expect(klass.instance).to be_a(klass)
    end

    it "declares default dictionary paths" do
      expect(klass.new.default_dictionary_paths).not_to be_empty
    end
  end

  MODULES.each do |code, klass|
    describe klass do
      include_examples "a registered language module", code, klass
    end
  end

  describe "tokenization against real dictionary words" do
    LANGUAGES_FIXTURE["languages"].each do |code, data|
      it "tokenizes a real #{code} sentence into its words" do
        language = MODULES.fetch(code).new
        tokens = language.tokenize(data.fetch("sentence"))
        expect(tokens).to include(*data.fetch("tokens"))
      end

      it "keeps real #{code} words as single tokens" do
        language = MODULES.fetch(code).new
        data.fetch("words").each do |word|
          expect(language.tokenize(word)).to contain_exactly(word)
        end
      end

      it "normalizes real lowercase #{code} words to themselves" do
        language = MODULES.fetch(code).new
        data.fetch("words").each do |word|
          expect(language.normalize_word(word)).to eq(word)
        end
      end
    end
  end

  describe "expected folding exceptions" do
    it "folds Turkish uppercase words with the dotless-i pair" do
      language = Kotoshu::Languages::Turkish.new
      folding = fixture_for("tr").fetch("fold_cases")
      folding.each do |input, folded|
        expect(language.normalize_word(input)).to eq(folded)
      end
    end

    it "folds uppercase Greek with the final sigma" do
      language = Kotoshu::Languages::Greek.new
      fixture_for("el").fetch("folded_words").each do |folded|
        source = folded.upcase
        expect(language.normalize_word(source)).to eq(folded)
      end
    end

    it "folds uppercase Ukrainian with plain Cyrillic downcase" do
      language = Kotoshu::Languages::Ukrainian.new
      fixture_for("uk").fetch("folded_words").each do |folded|
        source = folded.upcase
        expect(language.normalize_word(source)).to eq(folded)
      end
    end
  end

  describe "script types" do
    it "reports cyrillic for Ukrainian" do
      expect(Kotoshu::Languages::Ukrainian.new.script_type).to eq(:cyrillic)
    end

    it "reports greek for Greek" do
      expect(Kotoshu::Languages::Greek.new.script_type).to eq(:greek)
    end

    it "reports latin for the Latin-script members" do
      %w[ca cs da hu it nl pl ro sv tr vi].each do |code|
        expect(MODULES.fetch(code).new.script_type).to eq(:latin)
      end
    end
  end

  describe "keyboard layout coverage" do
    it "gives every wave-1 language a layout that names it" do
      MODULES.each_key do |code|
        layout = Kotoshu::Keyboard.layout_for(code)
        expect(layout).to be_a(Kotoshu::Keyboard::Layout)
        expect(layout.supports_language?(code)).to be(true)
      end
    end
  end

  describe "the pre-existing ten modules are untouched" do
    it "keeps the original registrations" do
      %w[ar de en es fa fr he ja pt ru].each do |code|
        expect(Kotoshu::Language.registered?(code)).to be true
      end
    end

    it "keeps German and Portuguese on their own classes" do
      expect(Kotoshu::Language.get("de")).to eq(Kotoshu::Languages::German)
      expect(Kotoshu::Language.get("pt")).to eq(Kotoshu::Languages::Portuguese)
    end
  end
end
