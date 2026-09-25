# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Suggestions::Strategies::SymSpellStrategy, :diacritic_fold do
  # Self-contained: a real provider over an in-memory cache carrying
  # diacritic words — no published-list dependence.
  FoldCache = Struct.new(:payload, keyword_init: true) do
    def cached_data?(_code) = true
    def load_cached(_code) = payload
  end

  let(:words) { %w[gelöscht fällig fähig gekocht] }
  let(:ranks) { { "gelöscht" => 1, "fällig" => 2, "fähig" => 3, "gekocht" => 4 } }

  let(:strategy) do
    provider = Kotoshu::Suggestions::FrequencyProvider.new(
      frequency_cache: FoldCache.new(payload: {
                                       tiers: {
                                         top_50: Set.new(%w[gelöscht]),
                                         top_200: Set.new(words),
                                         top_1000: Set.new(words)
                                       },
                                       full_list: words,
                                       ranks: ranks
                                     })
    )
    described_class.new(language_code: "de", frequency_provider: provider)
  end

  def suggestions_for(word)
    ctx = Kotoshu::Suggestions::Context.new(word: word, dictionary: [], max_results: 5)
    strategy.generate(ctx).to_words
  end

  it "resolves diacritic-omission typos to the accented original (plan C9)" do
    expect(suggestions_for("gejoscht")).to include("gelöscht")
    expect(suggestions_for("falig")).to include("fällig")
  end

  it "ranks the fold match ahead of same-distance non-fold candidates" do
    expect(suggestions_for("gejoscht").first).to eq("gelöscht")
  end

  it "does not fold-equal ranking outside the sanctioned set (the pl ogonek verdict)" do
    # The wave-2 pl bench: the fold promoted the a-form over the
    # ą-form for a ą-typo (bliższa ahead of bliższą) — 26pp top-1
    # against the field lane. Raw (downcased) scoring restores the
    # true form to distance 1.
    provider = Kotoshu::Suggestions::FrequencyProvider.new(
      frequency_cache: FoldCache.new(payload: {
                                       tiers: {
                                         top_50: Set.new(%w[bliższą]),
                                         top_200: Set.new(%w[bliższą bliższa]),
                                         top_1000: Set.new(%w[bliższą bliższa])
                                       },
                                       full_list: %w[bliższą bliższa],
                                       ranks: { "bliższą" => 1, "bliższa" => 2 }
                                     })
    )
    pl = described_class.new(language_code: "pl", frequency_provider: provider)
    ctx = Kotoshu::Suggestions::Context.new(word: "bliżsxą", dictionary: [], max_results: 5)
    expect(pl.generate(ctx).to_words.first).to eq("bliższą")
  end

  it "keeps folded ranking for the sanctioned languages' base codes only" do
    expect(described_class.new(language_code: "de").send(:fold_scoring?)).to be(true)
    expect(described_class.new(language_code: "sv").send(:fold_scoring?)).to be(true)
    expect(described_class.new(language_code: "vi").send(:fold_scoring?)).to be(true)
    expect(described_class.new(language_code: "de-CH").send(:fold_scoring?)).to be(false)
    expect(described_class.new(language_code: "pl").send(:fold_scoring?)).to be(false)
    expect(described_class.new(language_code: "fr").send(:fold_scoring?)).to be(false)
  end

  it "keeps fold-free English behavior unchanged" do
    provider = Kotoshu::Suggestions::FrequencyProvider.new(
      frequency_cache: FoldCache.new(payload: {
                                       tiers: {
                                         top_50: Set.new(%w[hello]),
                                         top_200: Set.new(%w[hello help]),
                                         top_1000: Set.new(%w[hello help held])
                                       },
                                       full_list: %w[hello help held],
                                       ranks: { "hello" => 1, "help" => 2, "held" => 3 }
                                     })
    )
    en = described_class.new(language_code: "en", frequency_provider: provider)
    ctx = Kotoshu::Suggestions::Context.new(word: "helo", dictionary: [], max_results: 5)
    expect(en.generate(ctx).to_words.first).to eq("hello")
  end
end
