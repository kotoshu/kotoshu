# frozen_string_literal: true

module Kotoshu
  module Documents
    # Immutable value object: a point in the original (markup-bearing)
    # source.
    #
    # Carries both a 0-based character offset (useful for tools that
    # want to slice the source by range) and a 1-based line/column pair
    # (useful for editor highlighting and human-readable messages).
    SourcePosition = Struct.new(:offset, :line, :column, keyword_init: true) do
      include Comparable

      def initialize(offset:, line:, column:)
        raise ArgumentError, "offset must be >= 0" if offset.negative?
        raise ArgumentError, "line must be >= 1" if line < 1
        raise ArgumentError, "column must be >= 1" if column < 1

        super
        freeze
      end

      # Lexicographic order by (offset, line, column). Matches the
      # natural order of positions when scanning the source left to
      # right, top to bottom.
      def <=>(other)
        return nil unless other.is_a?(SourcePosition)

        [offset, line, column] <=> [other.offset, other.line, other.column]
      end

      def to_s
        "line #{line}, column #{column} (offset #{offset})"
      end
    end
  end
end
