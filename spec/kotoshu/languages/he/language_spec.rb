# frozen_string_literal: true

require "spec_helper"

# Hebrew (plan 100, batch 3): full-feature promotion of the RTL
# module — downloadable dictionary plus the Hebrew SI-1452 keyboard
# grid with the five final-letter forms as real keys.
# Tokenizer/normalizer behavior is covered in rtl_languages_spec.rb;
# this spec covers the promotion.
RSpec.describe Kotoshu::Languages::Hebrew do
  it "is in the downloadable spelling list" do
    expect(Kotoshu::Cache::LanguageCache::AVAILABLE_LANGUAGES).to include("he")
  end

  it "extracts whole words on the spell-check path (plan 91 pattern)" do
    tokenizer = described_class.instance.tokenizer
    letters = %w[ש ל ם]
    expect(letters).to all(match(tokenizer.spellcheck_word_regex))
    expect("a").not_to match(tokenizer.spellcheck_word_regex)
  end

  it "resolves to the Hebrew SI-1452 layout" do
    layout = Kotoshu::Keyboard.layout_for("he")
    expect(layout.name).to eq("Hebrew-SI-1452")
    expect(layout.supports_language?("he")).to be true
    expect(layout.key_positions).to include("ש" => [2, 0], "ם" => [1, 8], "ץ" => [3, 8])
    expect(layout.distance("ש", "ד")).to eq(1)
  end
end
