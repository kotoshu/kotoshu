# frozen_string_literal: true

require "spec_helper"

RSpec.describe Kotoshu::Grammar::PosTagset::Ur do
  it "carries the full 32-tag CLE set" do
    expect(described_class.size).to eq(32)
    expect(described_class.major_count).to eq(12)
  end

  it "attests the tags observed in the human-verified sample" do
    sample_observed = %w[NN PSP VBF PU JJ NNP PRP CC AUXA AUXT SC VBI CD
                         PDM RB PRT SCK NEG Q PRR SCP APNA AUXP AUXM
                         VALA PRS SYM PRD OD PRF INJ]
    expect(sample_observed.all? { |t| described_class.tag?(t) }).to be(true)
  end

  it "flags the paper-derived tag that the sample does not attest" do
    expect(described_class::SPEC_DERIVED).to eq(%w[VB])
  end

  it "exposes gloss and major category per tag" do
    expect(described_class.gloss("PSP")).to include("postposition")
    expect(described_class.major("PSP")).to eq(:postposition)
    expect(described_class.major("AUXT")).to eq(:auxiliary)
  end

  it "answers tag? false for foreign tagsets" do
    expect(described_class.tag?("DT")).to be(false)
    expect(described_class.tag?("NNS")).to be(false)
  end
end
