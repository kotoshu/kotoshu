# frozen_string_literal: true

require_relative 'document'
require_relative '../models/context'

module Kotoshu
  module Documents
    # Plain text document implementation.
    #
    # Handles plain text files with line-based navigation and correction.
    #
    # @example Creating a plain text document
    #   doc = PlainTextDocument.new("Hello world\nHow are you?")
    #   doc.text_nodes.each { |node| puts node.text }
    class PlainTextDocument < Document
      # Create a new plain text document.
      #
      # @param content [String] The document content
      # @param format [Symbol] Document format (must be :text)
      # @param language_code [String] Language code
      def initialize(content, format: :text, language_code: 'en')
        raise ArgumentError, "Format must be :text" unless format == :text

        super(content, format: format, language_code: language_code)
        @lines = content.lines
      end

      # Get all text nodes for spell checking.
      #
      # Each line becomes a text node.
      #
      # @return [Array<TextNode>] Text nodes (one per line)
      def text_nodes
        @lines.each_with_index.map do |line, idx|
          # Strip leading/trailing whitespace but preserve structure
          stripped_line = line.rstrip
          next TextNode.new(
            stripped_line,
            location: Location.for_line_column(idx + 1, 0),
            node_path: [:line, idx]
          ) if stripped_line && !stripped_line.empty?
        end.compact
      end

      # Get context around a location.
      #
      # Returns lines before and after the error location.
      #
      # @param location [Location] The error location (must be line/column)
      # @param window [Integer] Number of lines before/after (default: 5)
      # @return [Models::Context] Context object
      def context_for(location, window: 5)
        raise ArgumentError, "Location must be line/column" unless location.line_column?

        start_line = [0, location.line - window - 1].max
        end_line = [@lines.size - 1, location.line + window - 1].min

        before = @lines[start_line...(location.line - 1)].join("\n")
        current = @lines[location.line - 1]
        after = @lines[(location.line + 1)..end_line].join("\n")

        Models::Context.new(
          before: before,
          current: current,
          after: after,
          location: location,
          window: window
        )
      end

      # Get node at path (for plain text, just returns line).
      #
      # @param path [Array] Node path (e.g., [:line, 5])
      # @return [String, nil] The line content
      def get_node(path)
        return nil unless path.is_a?(Array) && path.first == :line

        line_idx = path[1]
        return nil if line_idx < 0 || line_idx >= @lines.size

        @lines[line_idx]
      end

      # Replace text at a specific location.
      #
      # For plain text, modifies a specific line.
      #
      # @param location [Location] The location to replace
      # @param new_text [String] The new text
      # @return [PlainTextDocument] New document with replacement
      def replace_node(location, new_text)
        raise ArgumentError, "Location must be line/column" unless location.line_column?

        new_lines = @lines.dup
        line = new_lines[location.line - 1]

        # Replace the word at the specified column
        if location.column > 0 && location.column < line.length
          before = line[0...location.column]
          after = line[(location.column + @original.length)..-1] || ''
          line = "#{before}#{new_text}#{after}"
        else
          line = new_text
        end

        new_lines[location.line - 1] = line

        PlainTextDocument.new(new_lines.join("\n"), @format, @language_code)
      end

      # Apply corrections and return new document.
      #
      # Corrections are applied in reverse order to preserve offsets.
      #
      # @param corrections [Array<Models::SemanticError>] Errors to fix
      # @return [PlainTextDocument] New document with corrections
      def apply(corrections)
        return self if corrections.empty?

        # Sort by location (reverse order for offset preservation)
        sorted_corrections = corrections.sort_by { |c| c.location.line }.reverse

        new_doc = self
        corrections.each do |error|
          suggestion = error.recommended_suggestion
          new_doc = new_doc.replace_node(error.location, suggestion.word)
        end

        new_doc
      end

      # Document name for display.
      #
      # @return [String] Document name
      def name
        "plain_text"
      end

      # Get lines as array.
      #
      # @return [Array<String>] Lines
      def lines
        @lines
      end
    end
  end
end
