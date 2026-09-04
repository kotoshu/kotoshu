# frozen_string_literal: true

# Kotoshu::NativeBackend — selection + delegation onto the native engine
# (plan 66 / P4b).
#
# Selection and boundary rules are exercised with real dictionaries (the
# spec fixture Hunspell dictionary and a real Custom dictionary); the
# engine-dependent examples skip — without failing — when the extension is
# not built. No doubles anywhere.
RSpec.describe Kotoshu::NativeBackend do
  let(:fixture_base) { File.expand_path("../fixtures/dictionaries/hunspell/test", __dir__) }

  let(:hunspell_dictionary) do
    Kotoshu::Dictionary::Hunspell.new(
      dic_path: "#{fixture_base}.dic", aff_path: "#{fixture_base}.aff",
      language_code: "en"
    )
  end

  # A real dictionary of a type the native engine does not load.
  let(:custom_dictionary) do
    Kotoshu::Dictionary::Custom.new(words: %w[hello world], language_code: "en")
  end

  describe ".resolve" do
    it "never selects the native engine for backend ruby" do
      expect(described_class.resolve(dictionary: hunspell_dictionary, backend: "ruby")).to be_nil
    end

    it "rejects an unknown backend value" do
      expect { described_class.resolve(dictionary: hunspell_dictionary, backend: "rust") }
        .to raise_error(Kotoshu::ConfigurationError, /unknown backend/)
    end

    context "with a non-Hunspell dictionary" do
      it "stays pure Ruby under auto" do
        expect(described_class.resolve(dictionary: custom_dictionary, backend: "auto")).to be_nil
      end

      it "fails loudly under native" do
        # Without the built extension the availability guard fires first,
        # which is equally loud; with it built, the dictionary check does.
        if Kotoshu::Native.available?
          expect { described_class.resolve(dictionary: custom_dictionary, backend: "native") }
            .to raise_error(Kotoshu::Native::Unavailable, /only loads Hunspell dictionaries/)
        else
          expect { described_class.resolve(dictionary: custom_dictionary, backend: "native") }
            .to raise_error(Kotoshu::Native::Unavailable, /extension is not available/)
        end
      end
    end

    context "when the extension is built", :native_ext do
      before do
        skip "native extension not built (rake compile)" unless Kotoshu::Native.available?
      end

      it "selects the native engine under auto" do
        expect(described_class.resolve(dictionary: hunspell_dictionary, backend: "auto"))
          .to be_a(described_class)
      end

      it "selects the native engine under native" do
        expect(described_class.resolve(dictionary: hunspell_dictionary, backend: "native"))
          .to be_a(described_class)
      end
    end

    context "when the extension is not built" do
      before do
        skip "native extension is built; the unavailable path cannot be exercised" if Kotoshu::Native.available?
      end

      it "stays pure Ruby under auto" do
        expect(described_class.resolve(dictionary: hunspell_dictionary, backend: "auto")).to be_nil
      end

      it "fails loudly under native" do
        expect { described_class.resolve(dictionary: hunspell_dictionary, backend: "native") }
          .to raise_error(Kotoshu::Native::Unavailable, /extension is not available/)
      end
    end
  end

  describe ".hunspell_paths" do
    it "answers the aff and dic paths of a Hunspell dictionary" do
      expect(described_class.hunspell_paths(hunspell_dictionary))
        .to eq(["#{fixture_base}.aff", "#{fixture_base}.dic"])
    end

    it "answers nil for other dictionary types" do
      expect(described_class.hunspell_paths(custom_dictionary)).to be_nil
    end
  end

  # The engine contract: identical correct?/suggest results to the Ruby
  # engine on the conformance examples frozen in conformance/vectors.jsonl.
  describe "engine delegation", :native_ext do
    before do
      skip "native extension not built (rake compile)" unless Kotoshu::Native.available?
    end

    let(:base_fixture) { File.expand_path("../integrational/fixtures/base", __dir__) }

    let(:backend) do
      described_class.new(
        aff_path: "#{base_fixture}.aff", dic_path: "#{base_fixture}.dic",
        max_suggestions: 5
      )
    end

    let(:ruby_spellchecker) do
      dictionary = Kotoshu::Dictionary::Hunspell.new(
        dic_path: "#{base_fixture}.dic", aff_path: "#{base_fixture}.aff",
        language_code: "en"
      )
      Kotoshu::Spellchecker.new(dictionary: dictionary, config: Kotoshu::Configuration.new(backend: "ruby"))
    end

    it "checks words against the native dictionary" do
      expect(backend.correct?("hello")).to be(true)
      expect(backend.correct?("hlelo")).to be(false)
    end

    it "reproduces the canonical hlelo conformance vector" do
      expect(backend.suggest("hlelo", max_suggestions: 5).map(&:to_hash))
        .to include(include("word" => "hello", "distance" => 1, "confidence" => 1.0,
                            "source" => "edit_distance"))
    end

    it "agrees with the Ruby engine on correct? over fixture words" do
      %w[hello hlelo created konklux].each do |word|
        expect(backend.correct?(word)).to eq(ruby_spellchecker.correct?(word)), word
      end
    end

    it "returns a SuggestionSet of real Suggestion objects" do
      suggestions = backend.suggest("helo", max_suggestions: 5)

      expect(suggestions).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(suggestions.to_a).to all(be_a(Kotoshu::Suggestions::Suggestion))
    end
  end

  # The Spellchecker seam: backend selection routes the hot path.
  describe "Spellchecker integration", :native_ext do
    before do
      skip "native extension not built (rake compile)" unless Kotoshu::Native.available?
    end

    def spellchecker_for(backend)
      Kotoshu::Spellchecker.new(
        dictionary: Kotoshu::Dictionary::Hunspell.new(
          dic_path: "#{fixture_base}.dic", aff_path: "#{fixture_base}.aff",
          language_code: "en"
        ),
        config: Kotoshu::Configuration.new(backend: backend)
      )
    end

    it "holds no native engine under ruby" do
      expect(spellchecker_for("ruby").native_backend).to be_nil
    end

    it "holds a native engine under native and delegates correct?" do
      checker = spellchecker_for("native")

      expect(checker.native_backend).to be_a(described_class)
      expect(checker.correct?("hello")).to be(true)
    end

    it "holds a native engine under auto" do
      expect(spellchecker_for("auto").native_backend).to be_a(described_class)
    end
  end
end
