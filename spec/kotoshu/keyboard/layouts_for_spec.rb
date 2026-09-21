# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Keyboard::Registry, "layouts_for (plan C7 dual-layout)" do
  it "returns native + QWERTY for German (QWERTZ users may also type on QWERTY)" do
    names = described_class.layouts_for("de").map(&:name)
    expect(names).to eq(%w[QWERTZ QWERTY])
  end

  it "returns only QWERTY for English" do
    expect(described_class.layouts_for("en").map(&:name)).to eq(%w[QWERTY])
  end

  it "returns Dubeolsik + QWERTY for Korean" do
    names = described_class.layouts_for("ko").map(&:name)
    expect(names).to include("Dubeolsik", "QWERTY")
  end

  it "returns Arabic + QWERTY for Arabic" do
    names = described_class.layouts_for("ar").map(&:name)
    expect(names.first).to match(/Arabic/i)
    expect(names).to include("QWERTY")
  end

  it "returns Pinyin + QWERTY for zh-Hans-CN" do
    names = described_class.layouts_for("zh-Hans-CN").map(&:name)
    expect(names).to eq(%w[Pinyin QWERTY])
  end

  it "returns Cangjie + QWERTY for zh-Hant-TW" do
    names = described_class.layouts_for("zh-Hant-TW").map(&:name)
    expect(names).to eq(%w[Cangjie QWERTY])
  end

  it "returns Jyutping + QWERTY for zh-Hant-HK" do
    names = described_class.layouts_for("zh-Hant-HK").map(&:name)
    expect(names).to eq(%w[Jyutping QWERTY])
  end
end
