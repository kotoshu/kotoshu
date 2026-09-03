# frozen_string_literal: true

require "kotoshu/conformance_exporter"
require "tmpdir"

# Conformance vector export (plan 67 M3).
#
# These specs pin the two properties the kotoshu-rs sync depends on:
# determinism (exporting twice yields byte-identical output) and corpus size
# (> 500 vectors). Everything runs against the real engine -- real
# Spellchecker instances over real fixture dictionaries; no doubles anywhere.
RSpec.describe Kotoshu::ConformanceExporter do
  # A deterministic subset (every third corpus) keeps the double-export
  # determinism check fast while still exercising many dictionaries. The
  # full-corpus properties (row count, shape) are covered separately below.
  def subset_corpora
    described_class.default_corpora.select.with_index { |_, index| (index % 3).zero? }
  end

  def parse_lines(path)
    File.readlines(path, chomp: true)
  end

  describe ".export" do
    it "produces byte-identical output when run twice" do
      Dir.mktmpdir("kotoshu-conformance") do |dir|
        first = File.join(dir, "first.jsonl")
        second = File.join(dir, "second.jsonl")

        described_class.export(path: first, corpora: subset_corpora)
        described_class.export(path: second, corpora: subset_corpora)

        expect(File.binread(second)).to eq(File.binread(first))
      end
    end

    it "exports more than 500 vectors over the full default corpora" do
      Dir.mktmpdir("kotoshu-conformance") do |dir|
        path = File.join(dir, "vectors.jsonl")
        result = described_class.export(path: path)

        expect(result.row_count).to be > 500
        expect(parse_lines(path).length).to eq(result.row_count)
      end
    end

    it "writes every line in the declared vector shape" do
      Dir.mktmpdir("kotoshu-conformance") do |dir|
        path = File.join(dir, "vectors.jsonl")
        described_class.export(path: path, corpora: subset_corpora)

        kinds = parse_lines(path).map do |line|
          row = JSON.parse(line)
          expect(row).to include("kind", "language", "dictionary", "input", "expected")
          expect(row["language"]).to eq("en")
          expect(row["dictionary"]).to start_with("spec/")
          expect(row["input"]).to be_a(String)

          case row["kind"]
          when "correct"
            expect([true, false]).to include(row["expected"])
            expect(row).not_to include("limit")
          when "suggest"
            expect(row["limit"]).to eq(described_class::SUGGEST_LIMIT)
            expect(row["expected"]).to be_an(Array)
            expect(row["expected"].length).to be <= described_class::SUGGEST_LIMIT
            row["expected"].each do |suggestion|
              expect(suggestion).to include("word", "distance", "confidence", "source")
              expect(suggestion["word"]).to be_a(String)
            end
          else
            raise "unexpected kind: #{row['kind'].inspect}"
          end

          row["kind"]
        end

        expect(kinds).to include("correct", "suggest")
      end
    end

    it "exercises both correct and incorrect words" do
      Dir.mktmpdir("kotoshu-conformance") do |dir|
        path = File.join(dir, "vectors.jsonl")
        described_class.export(path: path, corpora: subset_corpora)

        expectations = parse_lines(path)
          .map { |line| JSON.parse(line) }
          .select { |row| row["kind"] == "correct" }
          .map { |row| row["expected"] }
        expect(expectations).to include(true, false)
      end
    end
  end

  describe "corpus handling" do
    it "skips a corpus whose dictionary fails to load instead of aborting" do
      Dir.mktmpdir("kotoshu-conformance") do |dir|
        broken = described_class::Corpus.new(
          id: "tmp/broken", aff_path: File.join(dir, "missing.aff"),
          dic_path: File.join(dir, "missing.dic"), words: ["word"]
        )
        path = File.join(dir, "vectors.jsonl")
        result = described_class.export(path: path, corpora: [broken])

        expect(result.row_count).to eq(0)
        expect(result.skipped_corpora).to include("tmp/broken")
        expect(File).to exist(path)
      end
    end

    it "excludes the pathological timelimit fixture from the default corpora" do
      ids = described_class.default_corpora.map(&:id)
      expect(ids).not_to include("spec/integrational/fixtures/timelimit")
      expect(ids).to all(start_with("spec/"))
    end
  end

  describe ".spec_fixture_corpus" do
    it "builds words from the test dictionary entries and the word list" do
      corpus = described_class.spec_fixture_corpus
      expect(corpus.id).to eq("spec/fixtures/dictionaries/hunspell/test")
      expect(corpus.words).to include("hello", "helo", "kotoshu")
      expect(File).to exist(corpus.aff_path)
      expect(File).to exist(corpus.dic_path)
    end
  end
end
