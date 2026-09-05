# frozen_string_literal: true

require "spec_helper"
require "tmpdir"

# CI baselines (TODO.impl/82 Track B): the lutaml-model serialized
# format, count-based application semantics, stale-entry reporting,
# and generation from real check results.
RSpec.describe Kotoshu::Baseline do
  def word_error(word, position)
    Kotoshu::Models::Result::WordResult.new(
      word: word, correct: false, position: position
    )
  end

  def result_for(text, errors)
    Kotoshu::Models::Result::DocumentResult.new(
      file: nil, errors: errors, word_count: text.split.size
    )
  end

  # "wrld" appears twice (offsets 0 and 9), "helo" once (offset 5).
  let(:text) { "wrld helo\nwrld hello\n" }
  let(:errors) do
    [word_error("wrld", 0), word_error("helo", 5), word_error("wrld", 10)]
  end
  let(:check_result) { result_for(text, errors) }

  describe described_class::Entry do
    it "round-trips through the canonical JSON keys" do
      entry = described_class.new(file: "doc.md", line: 3, word: "wrld", count: 2)
      parsed = described_class.from_json(described_class.to_json(entry))

      expect(parsed.file).to eq("doc.md")
      expect(parsed.line).to eq(3)
      expect(parsed.word).to eq("wrld")
      expect(parsed.count).to eq(2)
    end
  end

  describe described_class::Store do
    it "round-trips save and load through JSON" do
      store = described_class.new(
        entries: [
          Kotoshu::Baseline::Entry.new(file: "a.md", line: 1, word: "wrld", count: 1)
        ]
      )

      Dir.mktmpdir do |dir|
        path = File.join(dir, ".kotoshu-baseline.json")
        store.save(path)
        loaded = described_class.load(path)

        expect(loaded.version).to eq(described_class::CURRENT_VERSION)
        expect(loaded.entries.length).to eq(1)
        expect(loaded.entries.first.word).to eq("wrld")
      end
    end

    describe ".from_checks" do
      it "canonicalizes to one entry per file and word with counts" do
        store = described_class.from_checks("doc.md" => [check_result, text])

        expect(store.entries.length).to eq(2)
        wrld = store.entries.find { |e| e.word == "wrld" }
        helo = store.entries.find { |e| e.word == "helo" }

        expect(wrld.count).to eq(2)
        expect(wrld.line).to eq(1)
        expect(helo.count).to eq(1)
      end

      it "sorts entries canonically by file then word" do
        store = described_class.from_checks(
          "b.md" => [result_for("wrld", [word_error("wrld", 0)]), "wrld"],
          "a.md" => [result_for("wrld", [word_error("wrld", 0)]), "wrld"]
        )

        expect(store.entries.map(&:file)).to eq(%w[a.md b.md])
      end
    end

    describe "#apply" do
      let(:store) do
        described_class.from_checks("doc.md" => [check_result, text])
      end

      it "absorbs errors up to the baseline count and passes" do
        application = store.apply(check_result, file: "doc.md")

        expect(application.result).to be_success
        expect(application.result.errors).to eq([])
        expect(application.suppressed_count).to eq(3)
        expect(application.result.suppressed_count).to eq(3)
      end

      it "marks absorbed errors as baseline suppressions" do
        application = store.apply(check_result, file: "doc.md")
        entry = application.result.suppressed_errors.first

        expect(entry).to be_suppressed
        expect(entry.suppressed_by)
          .to eq(Kotoshu::Models::Result::WordResult::SUPPRESSED_BY_BASELINE)
      end

      it "fails occurrences beyond the baseline count" do
        grown = result_for(text, errors + [word_error("wrld", 20)])
        application = store.apply(grown, file: "doc.md")

        expect(application.result).to be_failed
        expect(application.result.errors.map(&:word)).to eq(%w[wrld])
        expect(application.suppressed_count).to eq(3)
      end

      it "fails words the baseline never recorded" do
        with_new = result_for(text, errors + [word_error("xyzzy", 15)])
        application = store.apply(with_new, file: "doc.md")

        expect(application.result.errors.map(&:word)).to contain_exactly("xyzzy")
        expect(application.suppressed_count).to eq(3)
      end

      it "reports stale entries whose errors no longer exist" do
        fixed = result_for("wrld\n", [word_error("wrld", 0)])
        application = store.apply(fixed, file: "doc.md")

        expect(application.result).to be_success
        expect(application.stale_count).to eq(1) # helo vanished
        expect(application.suppressed_count).to eq(1)
      end

      it "does not count reduced-but-present words as stale" do
        reduced = result_for("wrld\nwrld\n", [word_error("wrld", 0), word_error("wrld", 5)])
        application = store.apply(reduced, file: "doc.md")

        expect(application.stale_count).to eq(1) # only helo
      end

      it "ignores entries recorded for other files" do
        application = store.apply(check_result, file: "other.md")

        expect(application.result).to be_failed
        expect(application.suppressed_count).to eq(0)
      end

      it "preserves inline-suppressed entries next to baseline ones" do
        inline = Kotoshu::Models::Result::WordResult.new(
          word: "kotoshu", correct: false, position: 99,
          suppressed: true,
          suppressed_by: Kotoshu::Models::Result::WordResult::SUPPRESSED_BY_INLINE
        )
        mixed = Kotoshu::Models::Result::DocumentResult.new(
          file: nil, errors: errors, suppressed_errors: [inline], word_count: 5
        )
        application = store.apply(mixed, file: "doc.md")

        expect(application.result.suppressed_count).to eq(4)
        expect(application.result.suppressed_errors.map(&:suppressed_by))
          .to contain_exactly("inline", "baseline", "baseline", "baseline")
      end
    end
  end
end
