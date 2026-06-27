# frozen_string_literal: true

module Kotoshu
  module Cli
    # Renders download progress to an output IO.
    #
    # Two rendering strategies, picked at construction time:
    #   - TTY: a single-line bar that rewrites itself ('[====>     ] 45% 51MB/114MB')
    #   - Non-TTY: a periodic line every REPORT_INTERVAL_BYTES ('downloaded 51 MB of 114 MB')
    #
    # Both share #update and #finish so callers don't care which mode
    # they're in. Pass a NullReporter (or anything quack-like) to silence.
    #
    # The reporter knows nothing about HTTP, files, or chunks — callers
    # feed it cumulative byte counts. This keeps it pure and testable.
    class ProgressReporter
      REPORT_INTERVAL_BYTES = 10 * 1024 * 1024 # 10 MB between non-TTY line prints

      # @param output [IO] Where to render. Usually $stderr.
      # @param label [String] Short prefix shown in TTY mode (e.g. "en model").
      # @param tty [Boolean] Override the auto-detected TTY check.
      def initialize(output:, label: "download", tty: nil)
        @output = output
        @label = label
        @tty = tty.nil? ? output.tty? : tty
        @total = nil
        @received = 0
        @last_reported_at = 0
      end

      # @param total_bytes [Integer, nil] Total size from Content-Length, or nil if unknown.
      def start(total_bytes)
        @total = total_bytes
        @received = 0
        @last_reported_at = 0
        return unless @tty

        @output.puts "#{@label}: " + indeterminate_bar(0)
      end

      # @param received_bytes [Integer] Cumulative bytes received so far.
      def update(received_bytes)
        @received = received_bytes
        return unless @tty

        render_tty
      end

      # Print a line in non-TTY mode if enough bytes have flowed since
      # the last print. Called by update() in non-TTY mode.
      def maybe_report_periodic
        return if @tty
        return if @total.nil?
        return unless @received >= @last_reported_at + REPORT_INTERVAL_BYTES

        @output.puts "  downloaded #{format_bytes(@received)} of #{format_bytes(@total)}"
        @last_reported_at = @received
      end

      def finish
        return unless @tty

        # Clear the bar line and print final newline.
        @output.print "\r#{' ' * 80}\r"
        @output.puts "#{@label}: done (#{format_bytes(@received)})"
      end

      # Null-object variant. Use when callers want to silence progress
      # (e.g., quiet mode or programmatic API).
      class Null
        def start(_total_bytes); end
        def update(_received_bytes); end
        def maybe_report_periodic; end
        def finish; end
      end

      private

      def render_tty
        bar = if @total.nil? || @total.zero?
                indeterminate_bar(@received)
              else
                determinate_bar(@received, @total)
              end
        @output.print "\r#{@label}: #{bar}"
      end

      def determinate_bar(received, total)
        pct = (received.to_f / total * 100).clamp(0, 100)
        filled = (pct / 5).round
        bar_str = ("=" * filled).ljust(20, " ")
        "[#{bar_str}] #{pct.round(0)}% #{format_bytes(received)}/#{format_bytes(total)}"
      end

      def indeterminate_bar(received)
        "[##########] #{format_bytes(received)} (size unknown)"
      end

      def format_bytes(bytes)
        return "0 B" if bytes.nil? || bytes.zero?

        units = %w[B KB MB GB TB]
        size = bytes.to_f
        i = 0
        while size >= 1024 && i < units.length - 1
          size /= 1024
          i += 1
        end
        template = i.zero? ? "%.0f" : "%.1f"
        "#{template % size} #{units[i]}"
      end
    end
  end
end
