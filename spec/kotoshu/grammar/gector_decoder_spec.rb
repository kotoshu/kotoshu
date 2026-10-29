# frozen_string_literal: true

require "spec_helper"
require "kotoshu/grammar"

RSpec.describe Kotoshu::Grammar::GectorDecoder do
  subject(:decoder) do
    described_class.new(tagger: Struct.new(:labels).new({}), label_thresholds: label_thresholds)
  end

  let(:label_thresholds) { { "$REPLACE_into" => 0.5 } }

  # Scripted tagger subclass: feeds fixed per-round findings so the
  # application semantics of #correct are tested in isolation from ONNX.
  let(:scripted_decoder) do
    Class.new(described_class) do
      attr_accessor :script

      def detect_with_confidence(_words)
        step = @script.shift || []
        step.map { |f| f.key?(:confidence) ? f : f.merge(confidence: 1.0) }
      end
    end
  end

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

  def decoder_for(rounds_script)
    d = scripted_decoder.new(tagger: Struct.new(:labels).new({}), rounds: rounds_script.length)
    d.script = rounds_script
    d
  end

  describe "#correct application semantics" do
    it "lands two appends from one round at their original positions" do
      d = decoder_for([[{ index: 0, label: "$APPEND_b" }, { index: 1, label: "$APPEND_d" }]])
      expect(d.correct(%w[a c])[:corrected]).to eq(%w[a b c d])
    end

    it "keeps a later REPLACE valid when an earlier DELETE shifts tokens" do
      d = decoder_for([[{ index: 0, label: "$DELETE" }, { index: 2, label: "$REPLACE_x" }]])
      expect(d.correct(%w[p q r])[:corrected]).to eq(%w[q x])
    end

    it "applies multiple DELETEs from one round without index drift" do
      d = decoder_for([[{ index: 0, label: "$DELETE" }, { index: 2, label: "$DELETE" }]])
      expect(d.correct(%w[a b c d])[:corrected]).to eq(%w[b d])
    end

    it "handles MERGE and REPLACE in the same round right-to-left" do
      d = decoder_for([[{ index: 1, label: "$MERGE_xy" }, { index: 3, label: "$REPLACE_z" }]])
      expect(d.correct(%w[a b c d])[:corrected]).to eq(%w[a xy z])
    end

    it "does not re-apply the same finding within a round" do
      d = decoder_for([[{ index: 0, label: "$APPEND_b" }]])
      expect(d.correct(%w[a])[:corrected]).to eq(%w[a b])
    end

    it "skips findings below the label threshold" do
      d = scripted_decoder.new(tagger: Struct.new(:labels).new({}), rounds: 1,
                               label_thresholds: { "$REPLACE_z" => 0.9 })
      d.script = [[{ index: 0, label: "$REPLACE_z", confidence: 0.5 }]]
      expect(d.correct(%w[a])[:corrected]).to eq(%w[a])
    end
  end
end
