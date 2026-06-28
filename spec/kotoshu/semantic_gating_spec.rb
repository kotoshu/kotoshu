# frozen_string_literal: true

require "kotoshu"

# Phase B of TODO.impl/38-onnx-semantic-gating.md
#
# These specs pin the runtime gating contract: the semantic path
# (ONNX FastText embeddings) is opt-in and must never bleed into the
# traditional spell-checking path. They run in the always-run suite
# (no :onnx tag) because they verify the *absence* of coupling, not
# the presence of ONNX.
RSpec.describe "Semantic path runtime gating" do
  describe Kotoshu::Models::OnnxModel::OnnxUnavailable do
    it "is a Kotoshu::Error subclass" do
      expect(described_class.ancestors).to include(Kotoshu::Error)
    end

    it "mentions the install command in the default message" do
      error = described_class.new
      expect(error.message).to include("gem install onnxruntime")
    end

    it "mentions KOTOSHU_NO_ONNX as the opt-out" do
      error = described_class.new
      expect(error.message).to include("KOTOSHU_NO_ONNX=1")
    end

    it "appends the optional detail when given" do
      error = described_class.new("model file truncated")
      expect(error.message).to include("model file truncated")
      expect(error.message).to include("gem install onnxruntime")
    end
  end

  describe Kotoshu::Models::OnnxModel::ONNX_LOADED do
    it "is a boolean" do
      expect([true, false]).to include(Kotoshu::Models::OnnxModel::ONNX_LOADED)
    end
  end

  describe "Suggestions::Generator default algorithms" do
    it "does not include SemanticStrategy" do
      expect(Kotoshu::Suggestions::Generator::DEFAULT_ALGORITHMS)
        .not_to include(Kotoshu::Suggestions::Strategies::SemanticStrategy)
    end

    it "includes the four traditional algorithms" do
      expect(Kotoshu::Suggestions::Generator::DEFAULT_ALGORITHMS).to contain_exactly(
        Kotoshu::Suggestions::Strategies::EditDistanceStrategy,
        Kotoshu::Suggestions::Strategies::PhoneticStrategy,
        Kotoshu::Suggestions::Strategies::KeyboardProximityStrategy,
        Kotoshu::Suggestions::Strategies::NgramStrategy
      )
    end
  end

  describe "traditional Spellchecker entry points" do
    let(:dictionary) do
      Kotoshu::Dictionary::PlainText.from_words(
        %w[hello world test ruby], language_code: "en"
      )
    end

    let(:spellchecker) { Kotoshu::Spellchecker.new(dictionary: dictionary) }

    it "#correct? never raises OnnxUnavailable" do
      expect { spellchecker.correct?("hello") }.not_to raise_error
      expect { spellchecker.correct?("helo") }.not_to raise_error
    end

    it "#suggest never raises OnnxUnavailable and returns a SuggestionSet" do
      result = nil
      expect { result = spellchecker.suggest("helo") }.not_to raise_error
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
    end

    it "#check never raises OnnxUnavailable and returns a DocumentResult" do
      result = nil
      expect { result = spellchecker.check("hello wrld") }.not_to raise_error
      expect(result).to be_a(Kotoshu::Models::Result::DocumentResult)
    end

    it "#check_word never raises OnnxUnavailable" do
      expect { spellchecker.check_word("hello") }.not_to raise_error
      expect { spellchecker.check_word("helo") }.not_to raise_error
    end
  end

  describe "SemanticStrategy fallback when ONNX is unavailable" do
    let(:dictionary) do
      Kotoshu::Dictionary::PlainText.from_words(
        %w[hello world], language_code: "en"
      )
    end

    let(:context) do
      Kotoshu::Suggestions::Context.new(word: "helo", dictionary: dictionary)
    end

    it "returns an empty SuggestionSet without raising" do
      strategy = Kotoshu::Suggestions::Strategies::SemanticStrategy.new(language_code: "xx")
      result = nil
      expect { result = strategy.generate(context) }.not_to raise_error
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result).to be_empty
    end
  end
end
