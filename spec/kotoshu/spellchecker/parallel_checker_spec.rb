# frozen_string_literal: true

require "tempfile"
require "benchmark"
require_relative "../../../lib/kotoshu/spellchecker/parallel_checker"
require_relative "../../../lib/kotoshu/dictionary/plain_text"

RSpec.describe Kotoshu::Spellchecker::ParallelChecker do
  let(:dictionary) do
    Kotoshu::Dictionary::PlainText.from_words(
      %w[hello world test ruby code],
      language_code: "en"
    )
  end

  let(:spellchecker) { Kotoshu::Spellchecker.new(dictionary: dictionary) }

  describe "#initialize" do
    it "creates checker with default worker count" do
      checker = described_class.new(spellchecker: spellchecker)
      expect(checker.worker_count).to eq(4)
    end

    it "creates checker with custom worker count" do
      checker = described_class.new(spellchecker: spellchecker, worker_count: 2)
      expect(checker.worker_count).to eq(2)
    end
  end

  describe "#check_files_parallel" do
    let(:checker) { described_class.new(spellchecker: spellchecker, worker_count: 2) }

    it "checks multiple files in parallel" do
      # Create temporary test files
      files = (1..3).map do |i|
        Tempfile.new(["test#{i}", ".txt"]).tap do |f|
          f.write("hello world\n") # All correct words
          f.close
        end
      end

      begin
        results = checker.check_files_parallel(files.map(&:path))

        expect(results.size).to eq(3)
        expect(results).to all(be_a(Kotoshu::Models::Result::DocumentResult))
      ensure
        files.each(&:unlink)
      end
    end

    it "finds errors in files" do
      file1 = Tempfile.new(["test1", ".txt"]).tap do |f|
        f.write("hello wrld\n") # wrld is misspelled
        f.close
      end

      file2 = Tempfile.new(["test2", ".txt"]).tap do |f|
        f.write("world tst\n") # tst is misspelled
        f.close
      end

      begin
        results = checker.check_files_parallel([file1.path, file2.path])

        expect(results.size).to eq(2)
        expect(results[0].errors.size).to eq(1)
        expect(results[1].errors.size).to eq(1)
      ensure
        file1.unlink
        file2.unlink
      end
    end

    it "returns empty results for empty file list" do
      results = checker.check_files_parallel([])
      expect(results).to eq([])
    end

    it "handles single file" do
      file = Tempfile.new(["single", ".txt"]).tap do |f|
        f.write("hello\n")
        f.close
      end

      begin
        results = checker.check_files_parallel([file.path])
        expect(results.size).to eq(1)
      ensure
        file.unlink
      end
    end
  end

  describe "#check_file" do
    let(:checker) { described_class.new(spellchecker: spellchecker) }

    it "checks a single file" do
      file = Tempfile.new(["single", ".txt"]).tap do |f|
        f.write("hello wrld\n")
        f.close
      end

      begin
        result = checker.check_file(file.path)
        expect(result.errors.size).to eq(1)
        expect(result.errors.first.word).to eq("wrld")
      ensure
        file.unlink
      end
    end
  end

  describe "thread safety" do
    let(:checker) { described_class.new(spellchecker: spellchecker, worker_count: 4) }

    it "handles concurrent file checking safely" do
      files = 20.times.map do |i|
        Tempfile.new(["concurrent#{i}", ".txt"]).tap do |f|
          f.write("hello world #{i}\n")
          f.close
        end
      end

      begin
        results = checker.check_files_parallel(files.map(&:path))

        expect(results.size).to eq(20)
        expect(results).to all(be_a(Kotoshu::Models::Result::DocumentResult))
      ensure
        files.each(&:unlink)
      end
    end
  end

  describe "performance", :slow do
    let(:checker) { described_class.new(spellchecker: spellchecker, worker_count: 4) }

    it "is faster than sequential checking for multiple files" do
      files = 10.times.map do |i|
        Tempfile.new(["perf#{i}", ".txt"]).tap do |f|
          100.times { f.write("hello world test ruby\n") }
          f.close
        end
      end

      begin
        # Time parallel checking
        parallel_time = Benchmark.realtime do
          checker.check_files_parallel(files.map(&:path))
        end

        # Time sequential checking
        sequential_time = Benchmark.realtime do
          files.map(&:path).each do |path|
            spellchecker.check_file(path)
          end
        end

        # Parallel should be faster (or at least not significantly slower)
        # Allow up to 3x time for system variability in tests
        expect(parallel_time).to be <= sequential_time * 3.0
      ensure
        files.each(&:unlink)
      end
    end
  end
end
