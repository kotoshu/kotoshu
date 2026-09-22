# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Suggestions::Strategies::SymSpellStrategy, :diacritic_fold do
  # Real provider over the published de list (diacritics included).
  let(:strategy) do
    Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(language_code: "de")
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

  it "keeps fold-free English behavior unchanged" do
    en = Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(language_code: "en")
    ctx = Kotoshu::Suggestions::Context.new(word: "helo", dictionary: [], max_results: 5)
    expect(en.generate(ctx).to_words.first).to eq("hello")
  end
end
