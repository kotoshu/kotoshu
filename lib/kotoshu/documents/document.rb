# frozen_string_literal: true

require_relative 'location'
require_relative '../models/context'

module Kotoshu
  module Documents
    # Text node abstraction for structured documents.
    #
    # Represents a span of text in a document with location information.
    # Used for spell checking individual text elements in structured formats.
    #
    # @example Creating a text node
    #   node = TextNode.new("Hello world", location: Location.new(line: 5, column: 0))
    #   node.text  # => "Hello world"
    class TextNode
      attr_reader :text, :location, :node_path

      # Create a new text node.
      #
      # @param text [String] The text content
      # @param location [Location] Location of the text
      # @param node_path [Array, nil] Path in document AST
      def initialize(text, location:, node_path: nil)
        @text = text
        @location = location
        @node_path = node_path
        freeze
      end

      # Get words from this text node.
      #
      # @return [Array<String>] Words in the text
      def words
        @text.split
      end

      # Check if this equals another text node.
      #
      # @param other [Object] Another object
      # @return [Boolean] True if text and location match
      def ==(other)
        return false unless other.is_a?(TextNode)

        @text == other.text && @location == other.location
      end
      alias_method :eql?, :==

      # Hash code for hash table usage.
      #
      # @return [Integer] Hash code
      def hash
        [@text, @location].hash
      end

      # String representation.
      #
      # @return [String] Human-readable representation
      def to_s
        if @location.line_column?
          "#{@location}: #{@text}"
        else
          @text
        end
      end
      alias_method :inspect, :to_s
    end

    # Abstract base class for documents.
    #
    # Provides a unified interface for different document formats:
    # - Plain text
    # - Markdown
    # AsciiDoc
    # Code files (with syntax awareness)
    #
    # Subclasses implement format-specific parsing and context retrieval.
    #
    # @example Plain text document
    #   doc = PlainTextDocument.new("Hello world\n")
    #   doc.text_nodes.each { |node| puts node.text }
    #
    # @example Markdown document
    #   doc = MarkdownDocument.new("# Title\nParagraph text")
    #   doc.text_nodes.each { |node| puts node.text }
    class Document
      attr_reader :content, :format, :language_code

      # Supported document formats
      FORMATS = {
        text: 'Plain Text',
        markdown: 'Markdown',
        asciidoc: 'AsciiDoc',
        code: 'Code'
      }.freeze

      # Create a new document.
      #
      # @param content [String] The document content
      # @param format [Symbol] Document format (:text, :markdown, :asciidoc, :code)
      # @param language_code [String] ISO 639-1 language code (default: 'en')
      def initialize(content, format: :text, language_code: 'en')
        raise ArgumentError, "Invalid format: #{format}" unless FORMATS.key?(format)

        @content = content
        @format = format
        @language_code = language_code
      end

      # Get all text nodes for spell checking.
      #
      # Subclasses implement format-specific text extraction.
      #
      # @return [Array<TextNode>] Text nodes in the document
      def text_nodes
        raise NotImplementedError, "#{self.class} must implement #text_nodes"
      end

      # Get node at a specific path (for structured formats).
      #
      # @param path [Array] Node path (e.g., [:paragraph, 3, :text])
      # @return [Object, nil] The node object or nil
      def get_node(path)
        raise NotImplementedError, "#{self.class} must implement #get_node"
      end

      # Replace text at a specific location.
      #
      # @param location [Location] The location to replace
      # @param new_text [String] The new text
      # @return [Document] New document with replacement applied
      def replace_node(location, new_text)
        raise NotImplementedError, "#{self.class} must implement #replace_node"
      end

      # Get context around a specific location.
      #
      # @param location [Location] The error location
      # @param window [Integer] Number of lines before/after (default: 5)
      # @return [Models::Context] Context object
      def context_for(location, window: 5)
        raise NotImplementedError, "#{self.class} must implement #context_for"
      end

      # Apply corrections and return new document.
      #
      # @param corrections [Array<Models::SemanticError>] Errors to fix
      # @return [Document] New document with corrections applied
      def apply(corrections)
        raise NotImplementedError, "#{self.class} must implement #apply"
      end

      # Get word count.
      #
      # @return [Integer] Total word count
      def word_count
        @content.split(/\s+/).size
      end

      # Get line count.
      #
      # @return [Integer] Total line count
      def line_count
        @content.lines.size
      end

      # Get document name (for display).
      #
      # @return [String] Document name or identifier
      def name
        "document"
      end

      # Detect format from content.
      #
      # @param content [String] The document content
      # @return [Symbol] Detected format
      def self.detect_format(content)
        return :markdown if content.start_with?('#')
        return :code if content.end_with?('.')
        :text
      end

      # Create document from file.
      #
      # @param path [String] Path to the file
      # @return [Document] Document instance
      def self.from_file(path)
        content = File.read(path, encoding: 'UTF-8')
        format = detect_format(content)
        language_code = detect_language_from_path(path)

        case format
        when :markdown
          MarkdownDocument.new(content, language_code: language_code)
        when :asciidoc
          AsciidocDocument.new(content, language_code: language_code)
        else
          PlainTextDocument.new(content, language_code: language_code)
        end
      end

      # Create document from string with format detection.
      #
      # @param content [String] The document content
      # @param language_code [String] Language code (optional)
      # @return [Document] Document instance
      def self.from_string(content, language_code: 'en')
        format = detect_format(content)
        new(content, format: format, language_code: language_code)
      end

      private

      # Detect language code from file path.
      #
      # @param path [String] File path
      # @return [String] Language code
      def self.detect_language_from_path(path)
        # Extract from path like "README.en.md" or "document.de.txt"
        if path =~ /\.([a-z]{2})\./i
          Regexp.last_match(1)
        else
          'en'
        end
      end
    end
  end
end
