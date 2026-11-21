# frozen_string_literal: true

require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe "per-model serving calibration (issue #292)" do
  let(:dir) { Dir.mktmpdir }

  after { FileUtils.rm_rf(dir) }

  it "loads serving.json when the artifact carries calibration" do
    File.write(File.join(dir, "serving.json"), '{"min_confidence": 0.7}')
    expect(Kotoshu::Grammar::Tagger.load_serving_config(dir))
      .to eq("min_confidence" => 0.7)
  end

  it "answers an empty config when the artifact carries none" do
    expect(Kotoshu::Grammar::Tagger.load_serving_config(dir)).to eq({})
  end

  it "defers decoder min_confidence to the artifact calibration" do
    tagger = Struct.new(:labels, :serving_config).new({}, { "min_confidence" => 0.7 })
    decoder = Kotoshu::Grammar::GectorDecoder.new(tagger: tagger)
    expect(decoder.threshold_for("$APPEND_the")).to eq(0.7)
  end

  it "keeps an explicit min_confidence over the artifact calibration" do
    tagger = Struct.new(:labels, :serving_config).new({}, { "min_confidence" => 0.7 })
    decoder = Kotoshu::Grammar::GectorDecoder.new(tagger: tagger, min_confidence: 0.2)
    expect(decoder.threshold_for("$APPEND_the")).to eq(0.2)
  end
end
