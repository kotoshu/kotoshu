# frozen_string_literal: true

require "forwardable"

module Kotoshu
  module Documents
    # Immutable value object: a span in the original source. The
    # +start+ position is inclusive; the +end+ position is exclusive
    # (matches Ruby's range convention and editor selection APIs).
    #
    # SourceRange is the canonical "where" that an error report
    # carries. The checker resolves it from the {Document} before
    # constructing an error so callers (plugins, editors, the CLI)
    # never have to know about flattened vs source offsets.
    class SourceRange
      include Comparable
      extend Forwardable

      attr_reader :start, :end

      def_delegators :@start, :offset, :line, :column

      # @param start_pos [SourcePosition] inclusive start
      # @param end_pos [SourcePosition] exclusive end
      def initialize(start_pos:, end_pos:)
        raise TypeError, "start must be a SourcePosition" unless start_pos.is_a?(SourcePosition)
        raise TypeError, "end must be a SourcePosition" unless end_pos.is_a?(SourcePosition)
        raise ArgumentError, "end must be >= start" if end_pos < start_pos

        @start = start_pos
        @end = end_pos
        freeze
      end

      # Order by start position; ties broken by end position.
      def <=>(other)
        return nil unless other.is_a?(SourceRange)

        cmp = @start <=> other.start
        cmp.zero? ? (@end <=> other.end) : cmp
      end

      # True if +pos+ falls inside this range. End is exclusive.
      def contains?(pos)
        pos.is_a?(SourcePosition) && pos >= @start && pos < @end
      end

      # Length in characters of the source span. Uses the offset
      # difference, which is the editor-friendly interpretation: a
      # range from offset 7 to offset 15 covers 8 characters.
      def length
        @end.offset - @start.offset
      end

      # True when this range covers zero characters (start == end).
      def empty?
        @start == @end
      end

      # Combine +other+ with self into a range that spans both.
      # @param other [SourceRange]
      # @return [SourceRange]
      def union(other)
        raise TypeError, "other must be a SourceRange" unless other.is_a?(SourceRange)

        min_start = [@start, other.start].min
        max_end = [@end, other.end].max
        self.class.new(start_pos: min_start, end_pos: max_end)
      end

      def to_s
        "#{@start}..#{@end}"
      end
    end
  end
end
