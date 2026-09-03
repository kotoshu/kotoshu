# frozen_string_literal: true

require "tmpdir"
require "kotoshu"

# Phase C of TODO.impl/38-onnx-semantic-gating.md (runtime layer): when a
# cached model file cannot be deserialized by onnxruntime, the error must be
# actionable and point the user at the cache subcommand instead of leaking a
# raw OnnxRuntime::Error ("Protobuf parsing failed").
#
# Needs the onnxruntime gem (to attempt session creation) but NOT a cached
# language model — the skip guard mirrors spec/kotoshu/semantic_e2e_spec.rb.
RSpec.describe Kotoshu::Embeddings::OnnxRuntimeModel do
  describe "#load! with an undeserializable model file" do
    it "raises an actionable error pointing at the cache subcommand" do
      skip "onnxruntime not loaded" unless Kotoshu::Models::OnnxModel::ONNX_LOADED

      Dir.mktmpdir do |dir|
        garbage = File.join(dir, "fasttext.en.onnx")
        File.binwrite(garbage, "definitely-not-a-protobuf-onnx-model")

        model = described_class.new(language_code: "en", onnx_path: garbage)

        expect { model.load! }
          .to raise_error(Kotoshu::Error, /kotoshu cache download :en --model/)
      end
    end
  end
end
