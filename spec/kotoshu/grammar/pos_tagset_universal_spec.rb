# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Grammar::PosTagset::Universal do
  it "carries the 17-tag UD universal set" do
    expect(described_class.size).to eq(17)
  end

  it "answers glosses and membership" do
    expect(described_class.gloss("ADP")).to include("adposition")
    expect(described_class.tag?("SCONJ")).to be(true)
    expect(described_class.tag?("NN")).to be(false)
  end
end
