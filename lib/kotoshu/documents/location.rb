# frozen_string_literal: true

module Kotoshu
  module Documents
    # Unified location reference for errors in documents.
    #
    # Supports both line/column locations (plain text) and node paths
    # (structured formats like Markdown, AsciiDoc).
    #
    # @example Plain text location
    #   Location.new(line: 5, column: 12)
    #
    # @example Node path location
    #   Location.new(node_path: [:paragraph, 3, :text, 2])
    #
    # @example Mixed location
    #   Location.new(line: 5, column: 12, node_path: [:paragraph, 3])
    class Location
      attr_reader :line, :column, :node_path, :offset

      # Create a new location.
      #
      # @param line [Integer, nil] Line number (1-indexed)
      # @param column [Integer, nil] Column number (0-indexed)
      # @param node_path [Array<Symbol, Integer>, nil] Path to node in AST
      # @param offset [Integer, nil] Byte offset in content
      def initialize(line: nil, column: nil, node_path: nil, offset: nil)
        @line = line
        @column = column
        @node_path = node_path&.freeze
        @offset = offset
        freeze
      end

      # Check if this is a line/column location.
      #
      # @return [Boolean] True if has line and column
      def line_column?
        !@line.nil? && !@column.nil?
      end

      # Check if this is a node path location.
      #
      # @return [Boolean] True if has node path
      def node_location?
        !@node_path.nil? && !@node_path.empty?
      end

      # Comparison for sorting (by line, then column).
      #
      # @param other [Location] Another location
      # @return [Integer] Comparison result (-1, 0, 1)
      def <=>(other)
        return 0 unless other.is_a?(Location)

        if line_column? && other.line_column?
          # Both line/column - sort by line then column
          [@line, @column] <=> [other.line, other.column]
        elsif line_column?
          # We're line/column, other is node path - we come first
          -1
        elsif other.line_column?
          # Other is line/column, we're node path - other comes first
          1
        else
          # Both node paths - compare lexicographically
          @node_path <=> other.node_path
        end
      end

      # Check if this equals another location.
      #
      # @param other [Object] Another object
      # @return [Boolean] True if locations match
      def ==(other)
        return false unless other.is_a?(Location)

        @line == other.line &&
          @column == other.column &&
          @node_path == other.node_path &&
          @offset == other.offset
      end
      alias_method :eql?, :==

      # Hash code for hash table usage.
      #
      # @return [Integer] Hash code
      def hash
        [@line, @column, @node_path, @offset].hash
      end

      # String representation.
      #
      # @return [String] Human-readable representation
      def to_s
        if line_column?
          "Line #{@line}:#{@column}"
        elsif node_location?
          "Path: #{@node_path.join('.')}"
        elsif @offset
          "Offset #{@offset}"
        else
          "Unknown"
        end
      end
      alias_method :inspect, :to_s

      # Create a location for a text node.
      #
      # @param node_path [Array] Path to the text node
      # @param start_offset [Integer] Starting character offset
      # @param length [Integer] Length of the text
      # @return [Location] New location
      def self.for_text_node(node_path, start_offset:, length:)
        new(
          node_path: node_path,
          offset: start_offset
        )
      end

      # Create a line/column location.
      #
      # @param line [Integer] Line number
      # @param column [Integer] Column number
      # @return [Location] New location
      def self.for_line_column(line, column)
        new(line: line, column: column)
      end

      # Create a line-only location.
      #
      # @param line [Integer] Line number
      # @return [Location] New location
      def self.for_line(line)
        new(line: line, column: 0)
      end
    end
  end
end
