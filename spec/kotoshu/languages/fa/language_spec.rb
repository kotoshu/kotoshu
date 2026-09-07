# frozen_string_literal: true

require "spec_helper"

# Persian (plan 100, batch 3): full-feature promotion of the RTL
# module — downloadable dictionary plus the Persian standard (ISIRI
# 9147) keyboard grid. Tokenizer/normalizer behavior lives in the
# Persian part of the RTL specs; this spec covers the promotion.
RSpec.describe Kotoshu::Languages::Persian do
  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("fa")
  end

  it "extracts whole words on the spell-check path (plan 91 pattern)" do
    tokenizer = described_class.instance.tokenizer
    letters = %w[ک ی گ]
    expect(letters).to all(match(tokenizer.spellcheck_word_regex))
    expect("a").not_to match(tokenizer.spellcheck_word_regex)
  end

  it "resolves to the Persian standard layout" do
    layout = Kotoshu::Keyboard.layout_for("fa")
    expect(layout.name).to eq("Persian-Standard")
    expect(layout.supports_language?("fa")).to be true
    expect(layout.key_positions).to include("پ" => [3, 6], "چ" => [1, 11], "گ" => [2, 10])
    expect(layout.distance("ش", "س")).to eq(1)
  end
end
