# frozen_string_literal: true

require "kotoshu/conformance_runner"
require "tmpdir"

# Kotoshu::ConformanceRunner — the dual-backend conformance suite (plan 66 /
# TODO.impl 05 P4b).
#
# The specs run real engines over a real vectors file written to a tmpdir
# (built from the committed fixture dictionary, not by re-running the full
# export, so the suite stays fast). No doubles anywhere.
RSpec.describe Kotoshu::ConformanceRunner do
  # A small real vectors file: the canonical base-dictionary rows plus one
  # correct row, in the committed vector shape. Takes a block (the file
  # lives only inside it, under a tmpdir).
  def with_vectors_file
    Dir.mktmpdir("kotoshu-conformance-runner") do |dir|
      path = File.join(dir, "vectors.jsonl")
      rows = [
        { kind: "correct", language: "en", dictionary: "spec/integrational/fixtures/base",
          input: "hello", expected: true },
        { kind: "correct", language: "en", dictionary: "spec/integrational/fixtures/base",
          input: "hlelo", expected: false },
        { kind: "suggest", language: "en", dictionary: "spec/integrational/fixtures/base",
          input: "hlelo", limit: 5,
          expected: [{ "word" => "hello", "distance" => 1, "confidence" => 1.0,
                       "source" => "edit_distance" }] }
      ]
      File.write(path, rows.map { |row| JSON.generate(row) }.join("\n") << "\n")
      yield path
    end
  end

  describe "#run" do
    it "replays every vector through the ruby backend with zero failures" do
      with_vectors_file do |path|
        result = described_class.new(path: path).run(backend: :ruby)

        expect(result.row_count).to eq(3)
        expect(result.failures).to be_empty
        expect(result).to be_ok
      end
    end

    it "records a failure for every row that diverges from its expectation" do
      Dir.mktmpdir("kotoshu-conformance-runner") do |dir|
        path = File.join(dir, "vectors.jsonl")
        rows = [
          { kind: "correct", language: "en", dictionary: "spec/integrational/fixtures/base",
            input: "hello", expected: false },
          { kind: "suggest", language: "en", dictionary: "spec/integrational/fixtures/base",
            input: "hlelo", limit: 5, expected: [] }
        ]
        File.write(path, rows.map { |row| JSON.generate(row) }.join("\n") << "\n")

        result = described_class.new(path: path).run(backend: :ruby)

        expect(result.failures.map(&:index)).to eq([0, 1])
        expect(result.failures.first.expected).to be(false)
        expect(result.failures.first.actual).to be(true)
        expect(result).not_to be_ok
      end
    end

    it "fails loudly when native is requested without the extension" do
      skip "native extension is built; the unavailable path cannot be exercised" if Kotoshu::Native.available?

      with_vectors_file do |path|
        expect { described_class.new(path: path).run(backend: :native) }
          .to raise_error(Kotoshu::Native::Unavailable)
      end
    end

    it "replays every vector through the native backend with zero failures", :native_ext do
      skip "native extension not built (rake compile)" unless Kotoshu::Native.available?

      with_vectors_file do |path|
        result = described_class.new(path: path).run(backend: :native)

        expect(result.row_count).to eq(3)
        expect(result.failures).to be_empty
      end
    end
  end

  describe "#compare", :native_ext do
    before do
      skip "native extension not built (rake compile)" unless Kotoshu::Native.available?
    end

    it "reports zero divergences when both backends agree" do
      with_vectors_file do |path|
        result = described_class.new(path: path).compare

        expect(result.ruby.failures).to be_empty
        expect(result.native.failures).to be_empty
        expect(result.divergences).to be_empty
        expect(result).to be_ok
      end
    end
  end

  describe "default path" do
    it "points at the committed vectors file" do
      expect(described_class.default_path)
        .to eq(File.join(Kotoshu::ConformanceExporter.gem_root, "conformance", "vectors.jsonl"))
      expect(File).to exist(described_class.default_path)
    end
  end
end
