# frozen_string_literal: true

require "spec_helper"
require "kotoshu/components/hunspell_synthesizer"
require "tmpdir"

RSpec.describe Kotoshu::Components::HunspellSynthesizer do
  # A minimal real dictionary exercising every condition kind:
  #   SFX G "."        → any stem:            +s
  #   SFX G "e"        → stem must end e:     strip e, +d
  #   SFX G "[^e]"     → stem must NOT end e: +ing
  #   SFX G "ck"       → literal suffix:      strip k, +ks
  #   PFX U "[^a]"     → prefix on stems not starting a: +un (prefix path)
  let(:dir) do
    d = Dir.mktmpdir
    File.write(File.join(d, "t.aff"), <<~AFF)
      SET UTF-8
      SFX G Y 5
      SFX G   0     s     .
      SFX G   e     ed    e
      SFX G   0     ing   [^e]
      SFX G   k     ks    ck
      PFX U Y 1
      PFX U   0     un    [^a]
    AFF
    File.write(File.join(d, "t.dic"), <<~DIC)
      3
      run/G
      love/G
      happy/GU
    DIC
    d
  end

  after { FileUtils.remove_entry(dir) if dir }

  subject(:synth) do
    described_class.new(aff_path: File.join(dir, "t.aff"), dic_path: File.join(dir, "t.dic"))
  end

  it "expands a regular stem through every matching rule" do
    expect(synth.synthesize("run")).to contain_exactly("run", "runs", "runing")
  end

  it "applies strip conditions only when the stem qualifies" do
    expect(synth.synthesize("love")).to contain_exactly("love", "loves", "loved")
  end

  it "applies prefix rules alongside suffix rules" do
    expect(synth.synthesize("happy")).to include("happy", "happys", "unhappy")
  end

  it "degrades to the lemma itself when the word is not a dictionary stem" do
    expect(synth.synthesize("gallop")).to eq(["gallop"])
  end
end
