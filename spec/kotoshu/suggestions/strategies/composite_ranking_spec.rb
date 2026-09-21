# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Suggestions::Strategies::CompositeStrategy, :symspell_ranking do
  # Real strategies over a small explicit dictionary — no doubles, no
  # stubs. The dictionary carries no ranks, so tie order inside the
  # SymSpell slate is the strategy's own; the composite must adopt it
  # verbatim (ranked:true), never re-sort it.
  let(:words) { %w[ihr ihre irrt] }

  let(:sym_strategy) do
    Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(dictionary: words, language_code: "de")
  end

  let(:ed_strategy) do
    Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new(language_code: "de")
  end

  let(:ctx) do
    Kotoshu::Suggestions::Context.new(word: "ihrt", dictionary: words, max_results: 5)
  end

  it "prefixes the merge with SymSpell's own slate" do
    composite = described_class.new(name: :test, strategies: [ed_strategy, sym_strategy])

    sym_own = sym_strategy.generate(ctx).to_words
    expect(sym_own).not_to be_empty

    composite_own = composite.generate(ctx).to_words
    expect(composite_own.first(sym_own.size)).to eq(sym_own)
  end
end
