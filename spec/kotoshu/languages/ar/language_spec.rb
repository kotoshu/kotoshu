# frozen_string_literal: true

require "spec_helper"

# Arabic (plan 100, batch 3): full-feature promotion of the RTL
# module — downloadable dictionary plus the Arabic 101 keyboard grid.
# The tokenizer/normalizer behavior is covered in
# rtl_languages_spec.rb; this spec covers the promotion.
RSpec.describe Kotoshu::Languages::Arabic do
  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("ar")
  end

  it "extracts whole words on the spell-check path (plan 91 pattern)" do
    tokenizer = described_class.instance.tokenizer
    letters = %w[ك ب ة]
    expect(letters).to all(match(tokenizer.spellcheck_word_regex))
    expect("a").not_to match(tokenizer.spellcheck_word_regex)
  end

  it "resolves to the Arabic 101 layout" do
    layout = Kotoshu::Keyboard.layout_for("ar")
    expect(layout.name).to eq("Arabic-101")
    expect(layout.supports_language?("ar")).to be true
    expect(layout.key_positions).to include("ض" => [1, 0], "ش" => [2, 0], "ة" => [3, 6])
    expect(layout.distance("ش", "س")).to eq(1)
  end
end
