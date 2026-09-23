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

  it "ranks the confusion-hit first despite a higher-frequency non-hit" do
    # Self-contained: 找们 (rank 1, zhǎo — NOT a homophone of 扪)
    # would win on frequency alone; the confusion feature must flip
    # the order to 我们 (mén — the same-pinyin original).
    ranked_cache = Struct.new(:payload, keyword_init: true) do
      def cached_data?(_code) = true
      def load_cached(_code) = payload
    end
    provider = Kotoshu::Suggestions::FrequencyProvider.new(
      frequency_cache: ranked_cache.new(payload: {
                                          tiers: {
                                            top_50: Set.new(%w[我们]),
                                            top_200: Set.new(%w[我们 我门]),
                                            top_1000: Set.new(%w[我们 我门 找们])
                                          },
                                          full_list: %w[找们 我们 我门],
                                          ranks: { "找们" => 1, "我们" => 2, "我门" => 3 }
                                        })
    )
    sym = Kotoshu::Suggestions::Strategies::SymSpellStrategy.new(
      language_code: "zh-Hans-CN", frequency_provider: provider
    )
    ctx = Kotoshu::Suggestions::Context.new(word: "我扪", dictionary: [], max_results: 5)
    expect(sym.generate(ctx).to_words.first).to eq("我们")
  end
end
