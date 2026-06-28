# frozen_string_literal: true

require "spec_helper"
require "kotoshu/cli/progress_reporter"

RSpec.describe Kotoshu::Cli::ProgressReporter do
  describe "TTY mode" do
    let(:output) { StringIO.new }

    it "renders a determinate bar with percentage and byte counts" do
      allow(output).to receive(:tty?).and_return(true)
      reporter = described_class.new(output: output, label: "en model")

      reporter.start(100)
      reporter.update(50)

      line = output.string.lines.last(2).join
      expect(line).to include("en model")
      expect(line).to include("50%")
      expect(line).to include('50 B/100 B')
    end

    it "renders an indeterminate bar when Content-Length is missing" do
      allow(output).to receive(:tty?).and_return(true)
      reporter = described_class.new(output: output, label: "en model")

      reporter.start(nil)
      reporter.update(1024)

      expect(output.string).to include("size unknown")
    end

    it "clears the bar and prints a final summary on finish" do
      allow(output).to receive(:tty?).and_return(true)
      reporter = described_class.new(output: output, label: "en model")

      reporter.start(100)
      reporter.update(100)
      reporter.finish

      expect(output.string).to include("done")
      expect(output.string).to include("100 B")
    end
  end

  describe "non-TTY mode" do
    let(:output) { StringIO.new }

    it "prints a periodic line after REPORT_INTERVAL_BYTES" do
      allow(output).to receive(:tty?).and_return(false)
      reporter = described_class.new(output: output, label: "en model")

      reporter.start(50 * 1024 * 1024)
      reporter.update(15 * 1024 * 1024)
      reporter.maybe_report_periodic

      expect(output.string).to include("downloaded")
      expect(output.string).to include("of")
    end

    it "does not print when below the threshold" do
      allow(output).to receive(:tty?).and_return(false)
      reporter = described_class.new(output: output, label: "en model")

      reporter.start(100 * 1024 * 1024)
      reporter.update(5 * 1024 * 1024) # 5 MB
      reporter.maybe_report_periodic

      expect(output.string).to eq("")
    end

    it "does not print periodic when total is unknown" do
      allow(output).to receive(:tty?).and_return(false)
      reporter = described_class.new(output: output, label: "en model")

      reporter.start(nil)
      reporter.update(50 * 1024 * 1024)
      reporter.maybe_report_periodic

      expect(output.string).to eq("")
    end
  end

  describe "Null reporter" do
    it "implements the full protocol without producing output" do
      null = described_class::Null.new
      expect { null.start(100) }.not_to raise_error
      expect { null.update(50) }.not_to raise_error
      expect { null.maybe_report_periodic }.not_to raise_error
      expect { null.finish }.not_to raise_error
    end
  end

  describe "TTY override" do
    it "honors an explicit tty: false even when output is a TTY" do
      output = StringIO.new
      allow(output).to receive(:tty?).and_return(true)
      reporter = described_class.new(output: output, label: "x", tty: false)

      reporter.start(100)
      reporter.update(50)
      reporter.maybe_report_periodic

      # TTY mode would have written a bar; with tty:false it stays silent
      # below the periodic threshold.
      expect(output.string).to eq("")
    end
  end
end
