# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Suggestions::ConfusionSet, :cjk_confusion do
  it "loads the embedded pinyin tables for zh variants" do
    cs = described_class.for("zh-Hans-CN")
    expect(cs.available?).to be(true)
    expect(cs.homophones("的")).to include("地", "得")
  end

  it "is unavailable (null, no errors) for non-CJK languages" do
    cs = described_class.for("en")
    expect(cs.available?).to be(false)
    expect(cs.confusion_hit?("helo", "hello")).to be(false)
  end

  it "flags pinyin-homophone substitutions as confusion hits" do
    cs = described_class.for("zh-Hant-TW")
    expect(cs.confusion_hit?("我们", "我扪")).to be(true)
    expect(cs.confusion_hit?("我们", "你们")).to be(false)
  end

  it "ranks the confusion-hit first in the SymSpell slate" do
    provider = Kotoshu::Suggestions::FrequencyProvider.new
    sym = Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(
      language_code: "zh-Hans-CN", frequency_provider: provider
    )
    ctx = Kotoshu::Suggestions::Context.new(word: "我扪", dictionary: [], max_results: 5)
    expect(sym.generate(ctx).to_words.first).to eq("我们")
  end
end
