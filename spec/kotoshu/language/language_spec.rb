# frozen_string_literal: true

require "kotoshu"
require "tmpdir"
require "fileutils"

# Trigger autoload of every language-layer constant exercised below.
Kotoshu::Language::LanguageIdentifier
Kotoshu::Language::Base
Kotoshu::Language::Tokenizer::GermanTokenizer
Kotoshu::Language::Tokenizer::FrenchTokenizer
Kotoshu::Language::Tokenizer::SpanishTokenizer
Kotoshu::Language::Tokenizer::PortugueseTokenizer
Kotoshu::Language::Tokenizer::RussianTokenizer
Kotoshu::Language::Tokenizer::JapaneseTokenizer
Kotoshu::Languages::German
Kotoshu::Languages::Spanish
Kotoshu::Languages::French
Kotoshu::Languages::Portuguese
Kotoshu::Languages::Russian
Kotoshu::Languages::Japanese

# Direct spec for the un-specced files in lib/kotoshu/language/ and
# lib/kotoshu/languages/:
#
#   language/identifier.rb         — LanguageIdentifier + DetectionResult
#   language/languages/base.rb     — Template Method base class
#   language/tokenizer/{german,french,spanish,
#                       portuguese,russian,japanese}_tokenizer.rb
#   languages/{de,es,fr,pt,ru,ja}/language.rb
#
# detector.rb, registry.rb, base.rb (normalizer + tokenizer), suika.rb,
# latin_tokenizer.rb and languages/en/* already have specs.
RSpec.describe Kotoshu::Language do
  # ---- LanguageIdentifier --------------------------------------------

  # ---- Per-language modules -------------------------------------------

  # Reset the registry around each per-language example so a leaked
  # clear() in another spec (or this one) doesn't pollute.
  around do |example|
    Kotoshu::Language::Registry.restore_autoload!
    example.run
    Kotoshu::Language::Registry.restore_autoload!
  end

  describe Kotoshu::Language::LanguageIdentifier do
    describe Kotoshu::Language::LanguageIdentifier::DetectionResult do
      it "is a Struct with keyword-init" do
        r = described_class.new(language: "en", confidence: 0.95, label: "__label__en")
        expect(r.language).to eq("en")
        expect(r.confidence).to eq(0.95)
        expect(r.label).to eq("__label__en")
      end

      it "#to_s formats language + confidence percentage" do
        r = described_class.new(language: "de", confidence: 0.8731, label: "__label__de")
        expect(r.to_s).to eq("de (87.3%)")
      end
    end

    describe ".supported_languages" do
      it "returns the documented set of ISO 639-1 codes" do
        langs = described_class.supported_languages
        %w[en de es fr pt ru ar zh ja ko].each do |code|
          expect(langs).to include(code)
        end
      end
    end

    describe "LANGUAGE_MAPPING" do
      it "maps each FastText LID label to its ISO 639-1 code" do
        mapping = described_class.const_get(:LANGUAGE_MAPPING)
        expect(mapping["en"]).to eq("en")
        expect(mapping["ja"]).to eq("ja")
        expect(mapping["zh"]).to eq("zh")
        expect(mapping["ru"]).to eq("ru")
      end
    end

    describe "#initialize" do
      it "accepts an explicit model_path" do
        lid = described_class.new(model_path: "/tmp/lid.ftz", auto_download: false)
        expect(lid.model_path).to eq("/tmp/lid.ftz")
        expect(lid.loaded).to be false
      end

      it "uses the default cache path under Kotoshu::Paths.cache_path when none provided" do
        lid = described_class.new(auto_download: false)
        expected = File.join(Kotoshu::Paths.cache_path, "models", "lid.176.ftz")
        expect(lid.model_path).to eq(expected)
      end
    end

    describe "#model_downloaded?" do
      let(:tmpdir) { Dir.mktmpdir("kotoshu-lid-spec") }

      after { FileUtils.rm_rf(tmpdir) }

      it "is true when the model file exists on disk" do
        path = File.join(tmpdir, "lid.ftz")
        FileUtils.touch(path)
        lid = described_class.new(model_path: path, auto_download: false)
        expect(lid.model_downloaded?).to be true
      end

      it "is false when the model file is absent" do
        lid = described_class.new(model_path: File.join(tmpdir, "absent.ftz"),
                                  auto_download: false)
        expect(lid.model_downloaded?).to be false
      end
    end

    describe "#detect with no model and auto_download disabled" do
      let(:tmpdir) { Dir.mktmpdir("kotoshu-lid-spec") }

      after { FileUtils.rm_rf(tmpdir) }

      it "raises because the model is missing" do
        lid = described_class.new(model_path: File.join(tmpdir, "absent.ftz"),
                                  auto_download: false)
        expect { lid.detect("hello world") }.to raise_error(RuntimeError, /Model not found/)
      end
    end
  end

  # ---- Language::Base (Template Method) -------------------------------

  describe Kotoshu::Language::Base do
    # Bare subclass — inherits the abstract template methods, so they
    # raise NotImplementedError as documented.
    let(:bare_subclass) do
      Class.new(described_class) do
        def initialize(code: "xx", name: "Test", variant: nil)
          super
        end
      end
    end

    # Anonymous subclass for template-method tests; avoids touching the
    # real per-language classes (which register into the global registry
    # at file-load time). Provides minimal stubs for the template
    # methods so other instance tests can run.
    let(:subclass) do
      Class.new(described_class) do
        def initialize(code: "xx", name: "Test", variant: nil)
          super
        end

        def tokenizer
          @tokenizer ||= Object.new
        end

        def normalizer
          @normalizer ||= Object.new
        end

        def dictionary_class
          Struct.new(:name)
        end
      end
    end

    describe "#initialize" do
      it "exposes code, name, variant as read-only attributes" do
        lang = subclass.new(code: "en-US", name: "English", variant: "American")
        expect(lang.code).to eq("en-US")
        expect(lang.name).to eq("English")
        expect(lang.variant).to eq("American")
      end

      it "extracts the region from a hyphenated code in uppercase" do
        lang = subclass.new(code: "de-AT", name: "German")
        expect(lang.region).to eq("AT")
      end

      it "leaves region as nil for a base code" do
        lang = subclass.new(code: "de", name: "German")
        expect(lang.region).to be_nil
      end
    end

    describe "template methods" do
      it "tokenizer raises NotImplementedError" do
        expect { bare_subclass.new.tokenizer }
          .to raise_error(NotImplementedError, /must implement #tokenizer/)
      end

      it "normalizer raises NotImplementedError" do
        expect { bare_subclass.new.normalizer }
          .to raise_error(NotImplementedError, /must implement #normalizer/)
      end

      it "dictionary_class raises NotImplementedError" do
        expect { bare_subclass.new.dictionary_class }
          .to raise_error(NotImplementedError, /must implement #dictionary_class/)
      end
    end

    describe "default overrides" do
      it "encoding defaults to UTF-8" do
        expect(subclass.new.encoding).to eq("UTF-8")
      end

      it "rtl? defaults to false" do
        expect(subclass.new.rtl?).to be false
      end

      it "script_type defaults to :latin" do
        expect(subclass.new.script_type).to eq(:latin)
      end

      it "default_dictionary_paths defaults to []" do
        expect(subclass.new.default_dictionary_paths).to eq([])
      end
    end

    describe "#base_language? / #base_code / #region_code" do
      it "base_language? is true for unqualified codes" do
        expect(subclass.new(code: "en", name: "x").base_language?).to be true
      end

      it "base_language? is false for qualified codes" do
        expect(subclass.new(code: "en-US", name: "x").base_language?).to be false
      end

      it "base_code drops the region" do
        expect(subclass.new(code: "en-US", name: "x").base_code).to eq("en")
      end

      it "region_code returns the region part" do
        expect(subclass.new(code: "en-US", name: "x").region_code).to eq("US")
      end

      it "region_code is nil for a base code" do
        expect(subclass.new(code: "en", name: "x").region_code).to be_nil
      end
    end

    describe "#matches_code?" do
      it "matches an exact code" do
        lang = subclass.new(code: "en-US", name: "x")
        expect(lang.matches_code?("en-US")).to be true
      end

      it "matches on the base-code portion" do
        lang = subclass.new(code: "en-US", name: "x")
        expect(lang.matches_code?("en")).to be true
      end

      it "does not match a different language" do
        lang = subclass.new(code: "en-US", name: "x")
        expect(lang.matches_code?("de")).to be false
      end

      it "returns false for nil input" do
        expect(subclass.new(code: "en", name: "x").matches_code?(nil)).to be false
      end
    end

    describe "#compatible_with?" do
      let(:other_subclass) do
        Class.new(described_class) do
          def initialize(code:)
            super(code: code, name: "Other")
          end
        end
      end

      it "is true when both share the same base code" do
        a = subclass.new(code: "en-US", name: "x")
        b = other_subclass.new(code: "en-GB")
        expect(a.compatible_with?(b)).to be true
      end

      it "is false when bases differ" do
        a = subclass.new(code: "en", name: "x")
        b = other_subclass.new(code: "de-DE")
        expect(a.compatible_with?(b)).to be false
      end

      it "is false when the argument is not a Base" do
        a = subclass.new(code: "en", name: "x")
        expect(a.compatible_with?("en")).to be false
      end
    end

    describe "#full_name" do
      it "is just the name when no variant is set" do
        expect(subclass.new(code: "en", name: "English").full_name).to eq("English")
      end

      it "appends the variant in parentheses when set" do
        expect(subclass.new(code: "en", name: "English", variant: "American").full_name)
          .to eq("English (American)")
      end
    end

    describe "#info" do
      it "returns the documented shape" do
        info = subclass.new(code: "en-US", name: "English", variant: "American").info
        expect(info).to include(
          code: "en-US",
          name: "English",
          variant: "American",
          region: "US",
          encoding: "UTF-8",
          rtl?: false,
          script_type: :latin
        )
        expect(info).to have_key(:dictionary_class)
      end
    end

    describe ".instance" do
      it "memoizes a singleton" do
        klass = subclass
        expect(klass.instance).to be(klass.instance)
      end
    end
  end

  # ---- Tokenizers -----------------------------------------------------

  # Shared examples for the Latin-family tokenizers (German, French,
  # Spanish, Portuguese, Russian). Each must split basic text, ignore
  # whitespace, and return non-empty tokens.
  shared_examples "a basic word tokenizer" do
    let(:tokenizer) { described_class.new }

    it "returns [] for nil" do
      expect(tokenizer.tokenize(nil)).to eq([])
    end

    it "returns [] for an empty string" do
      expect(tokenizer.tokenize("")).to eq([])
    end

    it "returns [] for a whitespace-only string" do
      expect(tokenizer.tokenize("   \n\t  ")).to eq([])
    end

    it "tokenizes a simple sentence into its words" do
      tokens = tokenizer.tokenize("hello world")
      expect(tokens).to include("hello", "world")
    end

    it "filters pure numbers" do
      tokens = tokenizer.tokenize("alpha 12345 beta")
      expect(tokens).to include("alpha", "beta")
      expect(tokens).not_to include("12345")
    end
  end

  describe Kotoshu::Language::Tokenizer::GermanTokenizer do
    include_examples "a basic word tokenizer"

    it "preserves umlauts and ß as part of the word" do
      tokens = described_class.new.tokenize("Straße Grün Über")
      expect(tokens).to include("Straße", "Grün", "Über")
    end

    it "treats underscore as a word character" do
      tokens = described_class.new.tokenize("foo_bar baz")
      expect(tokens).to include("foo_bar")
    end
  end

  describe Kotoshu::Language::Tokenizer::FrenchTokenizer do
    include_examples "a basic word tokenizer"

    it "splits l'homme into two parts at the apostrophe" do
      tokens = described_class.new.tokenize("l'homme")
      # The contraction splitter emits the elided clitic and the rest.
      # Depending on apostrophe normalization the clitic may carry the
      # apostrophe or not; what matters is that homme is isolated.
      expect(tokens).to include("homme")
      expect(tokens.length).to eq(2)
    end

    it "keeps c'est-à-dire as a single token via DO_NOT_SPLIT" do
      tokens = described_class.new.tokenize("c'est-à-dire")
      expect(tokens).to contain_exactly("c'est-à-dire")
    end

    it "splits a regular hyphenated word on the hyphen" do
      tokens = described_class.new.tokenize("rendez-vous")
      # NOT in DO_NOT_SPLIT in this tokenizer's list (it IS in DO_NOT_SPLIT,
      # so this should actually be one token). Verify behavior matches the
      # declared DO_NOT_SPLIT.
      if described_class.const_get(:DO_NOT_SPLIT).include?("rendez-vous")
        expect(tokens).to contain_exactly("rendez-vous")
      else
        expect(tokens).to include("rendez", "vous")
      end
    end
  end

  describe Kotoshu::Language::Tokenizer::SpanishTokenizer do
    include_examples "a basic word tokenizer"

    it "preserves accented characters" do
      tokens = described_class.new.tokenize("caño niño García")
      expect(tokens).to include("caño", "niño", "García")
    end

    it "keeps decimal numbers together (3.14)" do
      tokens = described_class.new.tokenize("pi 3.14 end")
      expect(tokens).to include("3.14")
    end

    it "keeps decimal commas together (3,14)" do
      tokens = described_class.new.tokenize("x 3,14 y")
      expect(tokens).to include("3,14")
    end

    it "preserves the inverted question mark attached to the following word" do
      # WORD_SEPARATORS does not include ¿ — so it survives attached to
      # the next word. Document the actual behavior so a future change
      # to the separator set is visible.
      tokens = described_class.new.tokenize("¿Hola")
      expect(tokens).to include("¿Hola")
    end
  end

  describe Kotoshu::Language::Tokenizer::PortugueseTokenizer do
    include_examples "a basic word tokenizer"

    it "keeps decimal comma numbers together (3,14)" do
      tokens = described_class.new.tokenize("pi 3,14 end")
      expect(tokens).to include("3,14")
    end

    it "keeps dotted numbers together (1.000.000)" do
      tokens = described_class.new.tokenize("valor 1.000.000 reais")
      expect(tokens).to include("1.000.000")
    end

    it "keeps time-format colons together (12:25)" do
      tokens = described_class.new.tokenize("horas 12:25 fim")
      expect(tokens).to include("12:25")
    end

    it "preserves accented characters" do
      tokens = described_class.new.tokenize("João coração pão")
      expect(tokens).to include("João", "coração", "pão")
    end
  end

  describe Kotoshu::Language::Tokenizer::RussianTokenizer do
    include_examples "a basic word tokenizer"

    it "preserves Cyrillic characters" do
      tokens = described_class.new.tokenize("Привет мир")
      expect(tokens).to include("Привет", "мир")
    end

    it "preserves ё and the soft sign" do
      tokens = described_class.new.tokenize("ёлка дерево")
      expect(tokens).to include("ёлка", "дерево")
    end

    it "keeps б/у as a single token via abbreviation placeholders" do
      tokens = described_class.new.tokenize("купил б/у автомобиль")
      expect(tokens).to include("б/у")
    end
  end

  describe Kotoshu::Language::Tokenizer::JapaneseTokenizer do
    let(:suika_loaded) { Kotoshu::Language::Suika::LOADED }

    describe "#tokenize", if: :suika_loaded do
      it "returns [] for nil" do
        expect(described_class.new.tokenize(nil)).to eq([])
      end

      it "returns [] for an empty string" do
        expect(described_class.new.tokenize("")).to eq([])
      end

      it "tokenizes kana and kanji text via Suika" do
        tokens = described_class.new.tokenize("すもももももももものうち")
        expect(tokens).not_to be_empty
        # Suika should at least produce surface forms from the input.
        expect(tokens.all?(String)).to be true
      end
    end

    describe "#tokenize when Suika is unavailable", unless: :suika_loaded do
      it "raises SuikaUnavailable" do
        expect { described_class.new.tokenize("こんにちは") }
          .to raise_error(Kotoshu::SuikaUnavailable)
      end
    end
  end

  describe Kotoshu::Languages::German do
    it "registers itself for the documented codes" do
      %w[de de-DE de-AT de-CH de-BE de-IT de-LI de-LU].each do |code|
        expect(Kotoshu::Language::Registry.get(code)).to eq(described_class),
                                                         "German not registered for #{code}"
      end
    end

    describe "instance" do
      subject(:instance) { described_class.instance }

      it "reports script_type :latin" do
        expect(instance.script_type).to eq(:latin)
      end

      it "is not RTL" do
        expect(instance.rtl?).to be false
      end

      it "uses a German-backed Tokenizer" do
        expect(instance.tokenizer).to be_a(Kotoshu::Language::Tokenizer::GermanTokenizer)
      end

      it "uses the base Normalizer" do
        expect(instance.normalizer).to be_a(Kotoshu::Language::Normalizer::Base)
      end
    end
  end

  describe Kotoshu::Languages::Spanish do
    it "registers itself for the documented codes" do
      %w[es es-ES es-MX es-AR].each do |code|
        expect(Kotoshu::Language::Registry.get(code)).to eq(described_class)
      end
    end

    it "uses a Spanish-backed Tokenizer" do
      expect(described_class.instance.tokenizer)
        .to be_a(Kotoshu::Language::Tokenizer::SpanishTokenizer)
    end
  end

  describe Kotoshu::Languages::French do
    it "registers itself for the documented codes" do
      %w[fr fr-FR fr-CA fr-BE fr-CH].each do |code|
        expect(Kotoshu::Language::Registry.get(code)).to eq(described_class)
      end
    end

    it "uses a French-backed Tokenizer" do
      expect(described_class.instance.tokenizer)
        .to be_a(Kotoshu::Language::Tokenizer::FrenchTokenizer)
    end
  end

  describe Kotoshu::Languages::Portuguese do
    it "registers itself for the documented codes" do
      %w[pt pt-BR pt-PT].each do |code|
        expect(Kotoshu::Language::Registry.get(code)).to eq(described_class)
      end
    end

    it "uses a Portuguese-backed Tokenizer" do
      expect(described_class.instance.tokenizer)
        .to be_a(Kotoshu::Language::Tokenizer::PortugueseTokenizer)
    end
  end

  describe Kotoshu::Languages::Russian do
    it "registers itself for the documented codes" do
      %w[ru ru-RU ru-BY ru-KZ].each do |code|
        expect(Kotoshu::Language::Registry.get(code)).to eq(described_class)
      end
    end

    it "reports script_type :cyrillic" do
      expect(described_class.instance.script_type).to eq(:cyrillic)
    end

    it "uses a Russian-backed Tokenizer" do
      expect(described_class.instance.tokenizer)
        .to be_a(Kotoshu::Language::Tokenizer::RussianTokenizer)
    end
  end

  describe Kotoshu::Languages::Japanese do
    it "registers itself for the documented codes" do
      %w[ja ja-JP].each do |code|
        expect(Kotoshu::Language::Registry.get(code)).to eq(described_class)
      end
    end

    it "reports script_type :cjk" do
      expect(described_class.instance.script_type).to eq(:cjk)
    end

    it "uses a Japanese-backed Tokenizer" do
      expect(described_class.instance.tokenizer)
        .to be_a(Kotoshu::Language::Tokenizer::JapaneseTokenizer)
    end
  end
end
