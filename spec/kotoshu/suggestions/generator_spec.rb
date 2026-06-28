# frozen_string_literal: true

require "kotoshu"

# Direct spec for the Suggestions::Generator facade.
#
# Generator orchestrates the composite strategy pipeline and exposes
# the user-facing generate / suggest / correct? / incorrect? surface.
# The spec covers construction (default + custom algorithms + config
# forwarding), the suggest/generate alias, the correctness predicates,
# and the type-driven dictionary dispatch that replaced the prior
# respond_to?-based lookup chain.
RSpec.describe Kotoshu::Suggestions::Generator do
  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello help hell held help shell yellow below],
      language_code: "en"
    )
  end

  describe "#initialize" do
    it "exposes the dictionary reader" do
      generator = described_class.new(dictionary)
      expect(generator.dictionary).to be(dictionary)
    end

    it "builds a CompositeStrategy by default" do
      generator = described_class.new(dictionary)
      expect(generator.strategy).to be_a(Kotoshu::Suggestions::Strategies::CompositeStrategy)
    end

    it "composes the four default algorithm classes by default" do
      generator = described_class.new(dictionary)
      # The composite holds strategy instances; pin the algorithm count
      # so a default change is a conscious decision.
      expect(generator.strategy.strategies.size).to eq(4)
    end

    it "raises ArgumentError when an algorithm is neither a Class nor a BaseStrategy" do
      expect do
        described_class.new(dictionary, algorithms: ["not_an_algorithm"])
      end.to raise_error(ArgumentError, /Invalid algorithm/)
    end

    it "accepts a pre-built strategy instance in the algorithms array" do
      custom = Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new
      generator = described_class.new(dictionary, algorithms: [custom])
      expect(generator.strategy.strategies).to include(custom)
    end

    it "accepts a strategy class and instantiates it with the config hash" do
      generator = described_class.new(
        dictionary,
        algorithms: [Kotoshu::Suggestions::Strategies::EditDistanceStrategy],
        max_distance: 3
      )
      expect(generator.strategy.strategies.first).to be_a(
        Kotoshu::Suggestions::Strategies::EditDistanceStrategy
      )
    end

    it "forwards max_suggestions through to the strategy via Context" do
      generator = described_class.new(dictionary, max_suggestions: 7)
      # Pin that the generator stores the value and threads it into
      # Context.max_results at generate time.
      result = generator.generate("helo")
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result.max_size).to eq(7)
    end
  end

  describe ".default_algorithms" do
    it "returns a duplicate of DEFAULT_ALGORITHMS" do
      defaults = described_class.default_algorithms
      expect(defaults).to eq(Kotoshu::Suggestions::Generator::DEFAULT_ALGORITHMS)
      expect(defaults).not_to be(Kotoshu::Suggestions::Generator::DEFAULT_ALGORITHMS)
    end

    it "freezes the source constant so external mutation is impossible" do
      expect(Kotoshu::Suggestions::Generator::DEFAULT_ALGORITHMS).to be_frozen
    end
  end

  describe ".default_algorithms=" do
    after do
      # Restore the original defaults so this spec doesn't leak into others.
      Kotoshu::Suggestions::Generator.default_algorithms = nil
    end

    it "is writable but does not affect the DEFAULT_ALGORITHMS constant" do
      # The class-level writer is currently a no-op stub — the constant
      # is the source of truth at construction time. Pin that contract.
      original = described_class.default_algorithms
      described_class.default_algorithms = [Kotoshu::Suggestions::Strategies::PhoneticStrategy]
      expect(described_class::DEFAULT_ALGORITHMS).to eq(original)
    end
  end

  describe "#generate / #suggest" do
    let(:generator) { described_class.new(dictionary) }

    it "returns an empty SuggestionSet for a nil word" do
      result = generator.generate(nil)
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result).to be_empty
    end

    it "returns an empty SuggestionSet for an empty word" do
      result = generator.generate("")
      expect(result).to be_empty
    end

    it "returns a non-empty SuggestionSet for a misspelled word" do
      result = generator.generate("helo")
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result.size).to be_positive
    end

    it "returns Suggestion objects, not Strings, from each entry" do
      result = generator.generate("helo")
      expect(result.to_a).to all(be_a(Kotoshu::Suggestions::Suggestion))
    end

    it "honours a per-call max_suggestions override" do
      result = generator.generate("helo", max_suggestions: 2)
      expect(result.size).to be <= 2
    end

    it "is aliased as #suggest" do
      expect(generator.method(:suggest)).to eq(generator.method(:generate))
    end
  end

  describe "#correct? / #incorrect?" do
    let(:generator) { described_class.new(dictionary) }

    it "returns true for a word in the dictionary" do
      expect(generator.correct?("hello")).to be true
    end

    it "returns false for a word not in the dictionary" do
      expect(generator.correct?("xyzzy")).to be false
    end

    it "returns false for nil" do
      expect(generator.correct?(nil)).to be false
    end

    it "returns false for an empty string" do
      expect(generator.correct?("")).to be false
    end

    it "is the negation of #incorrect?" do
      expect(generator.incorrect?("hello")).to be false
      expect(generator.incorrect?("xyzzy")).to be true
    end

    it "is aliased as #misspelled?" do
      expect(generator.method(:misspelled?)).to eq(generator.method(:incorrect?))
    end
  end

  describe "dictionary dispatch" do
    # Type-driven dispatch via case/when (replaces the old respond_to?
    # chain). Hash and Array are ad-hoc dictionaries; anything else
    # must implement the documented `lookup(word)` interface.

    context "with a Hash dictionary" do
      let(:hash_dict) { { "hello" => true, "world" => true } }
      let(:generator) { described_class.new(hash_dict) }

      it "looks up via Hash#key?" do
        expect(generator.correct?("hello")).to be true
        expect(generator.correct?("missing")).to be false
      end
    end

    context "with an Array dictionary" do
      let(:array_dict) { %w[hello world] }
      let(:generator) { described_class.new(array_dict) }

      it "looks up via Array#include?" do
        expect(generator.correct?("hello")).to be true
        expect(generator.correct?("missing")).to be false
      end
    end

    context "with a non-dictionary object" do
      let(:not_a_dictionary) { Struct.new(:name).new("bogus") }
      let(:generator) { described_class.new(not_a_dictionary) }

      it "surfaces a NoMethodError on lookup rather than silently returning false" do
        # Old behaviour: respond_to? returned false for every method,
        # dispatch fell through to `false`, callers got a wrong answer
        # with no signal. New behaviour: the contract is enforced.
        expect do
          generator.correct?("hello")
        end.to raise_error(NoMethodError, /lookup/)
      end
    end
  end
end
