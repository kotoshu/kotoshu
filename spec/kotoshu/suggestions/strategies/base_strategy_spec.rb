# frozen_string_literal: true

require "kotoshu"

# Direct spec for Suggestions::Strategies::BaseStrategy.
#
# BaseStrategy is the abstract parent of every concrete strategy and
# holds the shared helpers: name/config readers, the #generate contract
# (raises NotImplementedError), the #handles? predicate, the
# #create_suggestion / #create_suggestion_set factories, the
# typo-similarity calculator, and the type-driven dictionary dispatch.
#
# To exercise #generate / #handles? we define a tiny concrete subclass
# rather than a double — per the no-double rule.
class ConcreteStrategyForSpec < Kotoshu::Suggestions::Strategies::BaseStrategy
  def generate(context)
    Kotoshu::Suggestions::SuggestionSet.from_words(
      %w[alpha beta],
      source: name
    ).tap { |set| set.from_source(name) }
  end
end

RSpec.describe Kotoshu::Suggestions::Strategies::BaseStrategy do
  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello help held hell shell yellow],
      language_code: "en"
    )
  end

  let(:indexed) { Kotoshu::Core::IndexedDictionary.new(%w[hello world]) }

  describe "#initialize" do
    it "coerces name to a Symbol" do
      strategy = described_class.new(name: "edit_distance")
      expect(strategy.name).to eq(:edit_distance)
    end

    it "defaults name to :base" do
      expect(described_class.new.name).to eq(:base)
    end

    it "exposes the config hash" do
      strategy = described_class.new(name: :x, custom: 42)
      expect(strategy.config).to eq(custom: 42)
    end

    it "defaults enabled to true when not specified" do
      expect(described_class.new(name: :x)).to be_enabled
    end

    it "honours an explicit enabled: false" do
      expect(described_class.new(name: :x, enabled: false)).not_to be_enabled
    end

    it "defaults max_results to 10" do
      expect(described_class.new(name: :x).max_results).to eq(10)
    end

    it "honours an explicit max_results" do
      expect(described_class.new(name: :x, max_results: 3).max_results).to eq(3)
    end
  end

  describe "#generate (abstract)" do
    it "raises NotImplementedError on the abstract parent" do
      strategy = described_class.new(name: :abstract)
      context = Kotoshu::Suggestions::Context.new(word: "x", dictionary: dictionary)
      expect do
        strategy.generate(context)
      end.to raise_error(NotImplementedError, /must implement #generate/)
    end

    it "is fulfilled by a concrete subclass" do
      context = Kotoshu::Suggestions::Context.new(word: "x", dictionary: dictionary)
      result = ConcreteStrategyForSpec.new(name: :concrete).generate(context)
      expect(result).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(result.to_words).to contain_exactly("alpha", "beta")
    end
  end

  describe "#get_config / #has_config?" do
    let(:strategy) { described_class.new(name: :x, alpha: 1, beta: nil) }

    it "returns the stored value when present" do
      expect(strategy.get_config(:alpha)).to eq(1)
    end

    it "returns the supplied default when absent" do
      expect(strategy.get_config(:missing, :fallback)).to eq(:fallback)
    end

    it "returns nil when absent and no default is given" do
      expect(strategy.get_config(:missing)).to be_nil
    end

    it "returns the stored value even when it is nil" do
      expect(strategy.get_config(:beta)).to be_nil
    end

    it "has_config? returns true for present keys, including nil-valued" do
      expect(strategy.has_config?(:alpha)).to be true
      expect(strategy.has_config?(:beta)).to be true
      expect(strategy.has_config?(:missing)).to be false
    end
  end

  describe "#priority" do
    it "defaults to 100" do
      expect(described_class.new(name: :x).priority).to eq(100)
    end

    it "honours an explicit priority" do
      expect(described_class.new(name: :x, priority: 5).priority).to eq(5)
    end
  end

  describe "#create_suggestion" do
    let(:strategy) { described_class.new(name: :edit_distance) }

    it "builds a Suggestion tagged with the strategy name as source" do
      s = strategy.create_suggestion("hello", distance: 1, confidence: 0.7)
      expect(s).to be_a(Kotoshu::Suggestions::Suggestion)
      expect(s.word).to eq("hello")
      expect(s.distance).to eq(1)
      expect(s.confidence).to eq(0.7)
      expect(s.source).to eq("edit_distance")
    end

    it "absorbs extra kwargs into metadata via Suggestion's catch-all" do
      s = strategy.create_suggestion("hello", distance: 1, original_length: 5, ngram_score: 0.8)
      expect(s.metadata[:original_length]).to eq(5)
      expect(s.metadata[:ngram_score]).to eq(0.8)
    end
  end

  describe "#create_suggestion_set" do
    let(:strategy) { described_class.new(name: :test, max_results: 5) }

    it "builds a SuggestionSet with each word wrapped in a Suggestion" do
      set = strategy.create_suggestion_set(%w[hello help])
      expect(set).to be_a(Kotoshu::Suggestions::SuggestionSet)
      expect(set.to_a).to all(be_a(Kotoshu::Suggestions::Suggestion))
      expect(set.to_words).to contain_exactly("hello", "help")
    end

    it "honours an explicit distances map" do
      set = strategy.create_suggestion_set(%w[hello help], distances: { "hello" => 1, "help" => 2 })
      distances = set.to_a.to_h { |s| [s.word, s.distance] }
      expect(distances["hello"]).to eq(1)
      expect(distances["help"]).to eq(2)
    end

    it "falls back to the downcased distance key when the exact key is missing" do
      set = strategy.create_suggestion_set(%w[Hello], distances: { "hello" => 3 })
      expect(set.first.distance).to eq(3)
    end

    it "defaults distance to 1 when neither exact nor downcased key is present" do
      set = strategy.create_suggestion_set(%w[hello])
      expect(set.first.distance).to eq(1)
    end

    it "stamps original_length metadata when original_word is supplied" do
      set = strategy.create_suggestion_set(%w[hello], original_word: "helo")
      expect(set.first.metadata[:original_length]).to eq(4)
    end

    it "stamps a non-zero ngram_score when original_word is supplied" do
      set = strategy.create_suggestion_set(%w[hello], original_word: "hello")
      expect(set.first.metadata[:ngram_score]).to be > 0
    end

    it "stamps ngram_score 0 when no original_word is supplied" do
      set = strategy.create_suggestion_set(%w[hello])
      expect(set.first.metadata[:ngram_score]).to eq(0)
    end
  end

  describe "#calculate_ngram_similarity" do
    let(:strategy) { described_class.new(name: :x) }

    it "is 1.0 for identical (case-insensitive) words" do
      expect(strategy.calculate_ngram_similarity("Hello", "hello")).to eq(1.0)
    end

    it "is 0 for nil or empty inputs" do
      expect(strategy.calculate_ngram_similarity(nil, "x")).to eq(0)
      expect(strategy.calculate_ngram_similarity("x", "")).to eq(0)
    end

    it "is higher for words that share a prefix than for words that don't" do
      with_prefix = strategy.calculate_ngram_similarity("hello", "help")
      without_prefix = strategy.calculate_ngram_similarity("hello", "world")
      expect(with_prefix).to be > without_prefix
    end

    it "is clamped to the 0.0..1.0 range" do
      score = strategy.calculate_ngram_similarity("x", "y")
      expect(score).to be_between(0.0, 1.0)
    end
  end

  describe "#handles?" do
    let(:strategy) { described_class.new(name: :x) }

    it "is false when the strategy is disabled" do
      disabled = described_class.new(name: :x, enabled: false)
      context = Kotoshu::Suggestions::Context.new(word: "hello", dictionary: dictionary)
      expect(disabled.handles?(context)).to be false
    end

    it "is false when the word IS in the dictionary (no suggestions needed)" do
      context = Kotoshu::Suggestions::Context.new(word: "hello", dictionary: dictionary)
      expect(strategy.handles?(context)).to be false
    end

    it "is true when the word is NOT in the dictionary (suggestions needed)" do
      context = Kotoshu::Suggestions::Context.new(word: "xyzzy", dictionary: dictionary)
      expect(strategy.handles?(context)).to be true
    end

    it "dispatches through IndexedDictionary#has_word? when given an IndexedDictionary" do
      context = Kotoshu::Suggestions::Context.new(word: "hello", dictionary: indexed)
      expect(strategy.handles?(context)).to be false

      context_missing = Kotoshu::Suggestions::Context.new(word: "xyz", dictionary: indexed)
      expect(strategy.handles?(context_missing)).to be true
    end
  end

  describe "#to_s / #inspect" do
    it "includes class name, name, and enabled flag" do
      strategy = described_class.new(name: :edit_distance, enabled: true)
      s = strategy.to_s
      expect(s).to include("BaseStrategy")
      expect(s).to include("edit_distance")
      expect(s).to include("enabled: true")
    end

    it "is aliased as inspect" do
      strategy = described_class.new(name: :x)
      expect(strategy.inspect).to eq(strategy.to_s)
    end
  end

  describe "dictionary dispatch (private API exercised through #handles?)" do
    let(:strategy) { described_class.new(name: :x) }

    context "with a Hash dictionary" do
      let(:hash_dict) { { "hello" => true } }

      it "looks up via Hash#key?" do
        ctx_hit = Kotoshu::Suggestions::Context.new(word: "hello", dictionary: hash_dict)
        ctx_miss = Kotoshu::Suggestions::Context.new(word: "missing", dictionary: hash_dict)
        expect(strategy.handles?(ctx_hit)).to be false
        expect(strategy.handles?(ctx_miss)).to be true
      end
    end

    context "with an Array dictionary" do
      let(:array_dict) { %w[hello world] }

      it "looks up via Array#include?" do
        ctx_hit = Kotoshu::Suggestions::Context.new(word: "hello", dictionary: array_dict)
        ctx_miss = Kotoshu::Suggestions::Context.new(word: "missing", dictionary: array_dict)
        expect(strategy.handles?(ctx_hit)).to be false
        expect(strategy.handles?(ctx_miss)).to be true
      end
    end

    context "with a real PlainText dictionary backend" do
      it "looks up via the documented lookup(word) interface" do
        ctx_hit = Kotoshu::Suggestions::Context.new(word: "hello", dictionary: dictionary)
        ctx_miss = Kotoshu::Suggestions::Context.new(word: "xyzzy", dictionary: dictionary)
        expect(strategy.handles?(ctx_hit)).to be false
        expect(strategy.handles?(ctx_miss)).to be true
      end
    end

    context "with a non-dictionary object" do
      let(:not_a_dictionary) { Struct.new(:name).new("bogus") }

      it "surfaces a NoMethodError rather than silently returning false" do
        # Old behaviour: respond_to? returned false for every method,
        # dispatch fell through to `false`. New behaviour: contract
        # is enforced.
        ctx = Kotoshu::Suggestions::Context.new(word: "hello", dictionary: not_a_dictionary)
        expect { strategy.handles?(ctx) }.to raise_error(NoMethodError, /lookup/)
      end
    end
  end
end
