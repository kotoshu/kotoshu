# frozen_string_literal: true

require "tmpdir"
require "fileutils"
require "json"
require "kotoshu"

# Direct specs for Models::OnnxModel construction paths. `from_file` only
# reads the vocab/metadata siblings and stores the .onnx path — the runtime
# session is lazy — so these specs run without onnxruntime (no :onnx tag).
RSpec.describe Kotoshu::Models::OnnxModel do
  describe ".from_file" do
    it "loads a wrapped word_to_idx vocab.json (models-repo shape)" do
      Dir.mktmpdir do |dir|
        onnx_path = File.join(dir, "fasttext.en.onnx")
        File.write(onnx_path, "stub-onnx-bytes")
        File.write(
          onnx_path.sub(".onnx", ".vocab.json"),
          JSON.generate(
            "vocab_size" => 3,
            "word_to_idx" => { "hello" => 0, "world" => 1, "test" => 2 }
          )
        )

        model = described_class.from_file(onnx_path)

        expect(model.language_code).to eq("en")
        expect(model.vocabulary).to contain_exactly("hello", "world", "test")
      end
    end

    it "loads a flat word-to-index vocab.json" do
      Dir.mktmpdir do |dir|
        onnx_path = File.join(dir, "fasttext.en.onnx")
        File.write(onnx_path, "stub-onnx-bytes")
        File.write(
          onnx_path.sub(".onnx", ".vocab.json"),
          JSON.generate("hello" => 0, "world" => 1)
        )

        model = described_class.from_file(onnx_path)

        expect(model.vocabulary).to contain_exactly("hello", "world")
      end
    end

    it "raises ArgumentError when the vocab sibling is missing" do
      Dir.mktmpdir do |dir|
        onnx_path = File.join(dir, "fasttext.en.onnx")
        File.write(onnx_path, "stub-onnx-bytes")

        expect do
          described_class.from_file(onnx_path)
        end.to raise_error(ArgumentError, /Vocabulary file not found/)
      end
    end
  end
end
