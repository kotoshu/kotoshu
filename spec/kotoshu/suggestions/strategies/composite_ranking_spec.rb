# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Suggestions::Strategies::CompositeStrategy, :symspell_ranking do
  # Real strategies with a real provider over an in-memory cache — no
  # doubles. The provider carries the frequency full_list so the
  # SymSpell lane is frequency-ranked (the precondition for leading
  # the composite, plan C6).
  RankedCache = Struct.new(:payload, keyword_init: true) do
    def cached_data?(_code) = true
    def load_cached(_code) = payload
  end

  let(:words) { %w[ihr ihre irrt] }
  let(:ranks) { { "ihr" => 1, "ihre" => 2, "irrt" => 3 } }

  let(:sym_strategy) do
    provider = Kotoshu::Suggestions::FrequencyProvider.new(
      frequency_cache: RankedCache.new(
        payload: {
          tiers: {
            top_50: Set.new(%w[ihr]),
            top_200: Set.new(words),
            top_1000: Set.new(words)
          },
          full_list: words,
          ranks: ranks
        }
      )
    )
    Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(
      language_code: "de", frequency_provider: provider
    )
  end

  let(:ed_strategy) do
    Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new(language_code: "de")
  end

  let(:ctx) do
    Kotoshu::Suggestions::Context.new(word: "ihrt", dictionary: words, max_results: 5)
  end

  it "prefixes the merge with SymSpell's own slate when frequency-ranked" do
    expect(sym_strategy.frequency_ranked?).to be(true)

    composite = described_class.new(name: :test, strategies: [ed_strategy, sym_strategy])

    sym_own = sym_strategy.generate(ctx).to_words
    expect(sym_own).not_to be_empty

    composite_own = composite.generate(ctx).to_words
    expect(composite_own.first(sym_own.size)).to eq(sym_own)
  end

  it "falls back to the legacy merge when SymSpell carries no ranks" do
    plain_sym = Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(
      dictionary: words, language_code: "de"
    )
    expect(plain_sym.frequency_ranked?).to be(false)

    composite = described_class.new(name: :test, strategies: [ed_strategy, plain_sym])
    set = composite.generate(ctx)
    expect(set).to be_a(Kotoshu::Suggestions::SuggestionSet)
    expect(set.to_words).not_to be_empty
  end
end
