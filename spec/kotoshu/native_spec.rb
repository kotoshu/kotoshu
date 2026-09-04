# frozen_string_literal: true

require "kotoshu/native"

# Kotoshu::Native — the Rust extension loader + adapter (plan 66 / P4b).
#
# Everything here runs against the real extension when it is built, and
# skips the extension-dependent examples (without failing) when it is not —
# `require "kotoshu"` must never fail on a machine without the extension,
# and neither may its spec. No doubles anywhere.
RSpec.describe Kotoshu::Native do
  describe ".available?" do
    it "answers without raising, on every install shape" do
      expect([true, false]).to include(described_class.available?)
    end
  end

  describe "requiring the gem without the extension" do
    it "defines the module and its Ruby-side error class" do
      expect(described_class).to be_a(Module)
      expect(described_class::Unavailable).to be < Kotoshu::Error
    end
  end

  describe ".suggestion" do
    it "materializes a Suggestions::Suggestion from a native row" do
      row = { "word" => "hello", "distance" => 1, "confidence" => 1.0, "source" => "edit_distance" }

      suggestion = described_class.suggestion(row)

      expect(suggestion).to be_a(Kotoshu::Suggestions::Suggestion)
      expect(suggestion.word).to eq("hello")
      expect(suggestion.distance).to eq(1)
      expect(suggestion.confidence).to eq(1.0)
      expect(suggestion.source).to eq("edit_distance")
    end

    it "keeps exactly the four public conformance keys" do
      row = { "word" => "w", "distance" => 2, "confidence" => 0.5, "source" => "ngram" }

      expect(described_class.suggestion(row).to_hash.keys).to contain_exactly(
        "word", "distance", "confidence", "source"
      )
    end
  end

  # The extension surface. These examples mirror the kotoshu-rs smoke test
  # (tests/ruby_ffi_smoke.rb) and only run when the extension is built.
  describe "extension surface", :native_ext do
    before do
      skip "native extension not built (rake compile)" unless described_class.available?
    end

    it "exposes the kotoshu-rs version" do
      expect(described_class::VERSION).to match(/\A\d+\.\d+\.\d+\z/)
    end

    it "answers available? true" do
      expect(described_class.available?).to be(true)
    end

    it "defines Error as a RuntimeError subclass" do
      expect(described_class::Error.ancestors).to include(RuntimeError)
    end

    it "loads a real fixture dictionary and checks words" do
      base = File.expand_path("../fixtures/dictionaries/hunspell/test", __dir__)
      dictionary = described_class::Dictionary.load("#{base}.aff", "#{base}.dic")

      expect(dictionary).to be_a(described_class::Dictionary)
      expect(dictionary.correct?("hello")).to be(true)
      expect(dictionary.correct?("ruby")).to be(false)
    end

    it "returns suggestion rows in the conformance shape" do
      base = File.expand_path("../integrational/fixtures/base", __dir__)
      dictionary = described_class::Dictionary.load("#{base}.aff", "#{base}.dic")

      rows = dictionary.suggest("hlelo", 5)

      expect(rows).to eq([{ "word" => "hello", "distance" => 1, "confidence" => 1.0,
                            "source" => "edit_distance" }])
      rows.each do |row|
        expect(row.keys.sort).to eq(%w[confidence distance source word])
        expect(row["distance"]).to be_an(Integer)
        expect(row["confidence"]).to be_a(Float).and(be_between(0.0, 1.0))
      end
    end

    it "raises Native::Error naming the path when loading a missing dictionary" do
      expect { described_class::Dictionary.load("/nonexistent.aff", "/nonexistent.dic") }
        .to raise_error(described_class::Error, %r{/nonexistent\.aff})
    end
  end
end
