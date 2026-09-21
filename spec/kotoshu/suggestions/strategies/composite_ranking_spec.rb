# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Suggestions::Strategies::CompositeStrategy, "SymSpell-first ranking (plan C6)" do
  # Real SymSpellStrategy over a tiny frequency-style list so the
  # composite behavior is observable without any doubles.
  let(:sym_strategy) do
    Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(
      dictionary: %w[ihr ihre irrt],
      language_code: "de"
    )
  end

  let(:ed_strategy) do
    ed = Kotoshu::Suggestions::Strategies::EditDistanceStrategy.new(language_code: "de")
    allow(ed).to receive(:dictionary_words).and_return(%w[ihr ihre irrt])
    ed
  end

  it "leads with SymSpell's order rather than re-sorting by combined_score" do
    composite = described_class.new(name: :test)
    composite.add(ed_strategy)
    composite.add(sym_strategy)

    ctx = Kotoshu::Suggestions::Context.new(
      word: "ihrt", dictionary: %w[ihr ihre irrt], max_results: 5
    )
    set = composite.generate(ctx)
    expect(set.to_words.first).to eq("ihr")
  end
end
