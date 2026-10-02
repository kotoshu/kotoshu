# frozen_string_literal: true

require "spec_helper"
require "kotoshu/grammar"

RSpec.describe Kotoshu::Grammar::GectorDecoder do
  subject(:decoder) do
    described_class.new(tagger: Struct.new(:labels).new({}), label_thresholds: label_thresholds)
  end

  let(:label_thresholds) { { "$REPLACE_into" => 0.5 } }

  describe "#threshold_for" do
    it "uses the tuned floor for a listed label" do
      expect(decoder.threshold_for("$REPLACE_into")).to eq(0.5)
    end

    it "falls back to min_confidence for unlisted labels" do
      expect(decoder.threshold_for("$APPEND_the")).to eq(0.0)
    end

    it "honors a raised min_confidence" do
      decoder = described_class.new(
        tagger: Struct.new(:labels).new({}),
        min_confidence: 0.2, label_thresholds: { "$REPLACE_into" => 0.5 }
      )
      expect(decoder.threshold_for("$APPEND_the")).to eq(0.2)
      expect(decoder.threshold_for("$REPLACE_into")).to eq(0.5)
    end
  end
end
