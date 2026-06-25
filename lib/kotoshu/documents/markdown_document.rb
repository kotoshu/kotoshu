# frozen_string_literal: true

require_relative 'document'
require_relative 'location'

module Kotoshu
  module Documents
    # Markdown document implementation.
    #
    # Handles Markdown files with AST parsing for structured navigation.
    #
    # @example Creating a markdown document
    #   doc = MarkdownDocument.new("# Title\n\nParagraph text")
    #   doc.text_nodes.each { |node| puts node.text }
    class MarkdownDocument < Document
      require 'kramdown' if ENV['KOTOSHU_REQUIRE_MARKDOWN']

      # Create a new markdown document.
      #
      # @param content [String] The document content
      # @param format [Symbol] Document format (must be :markdown)
      # @param language_code [String] Language code
      def initialize(content, format: :markdown, language_code: 'en')
        raise ArgumentError, "Format must be :markdown" unless format == :markdown

        super(content, format: format, language_code: language_code)
        @parsed = false
        @ast = nil
      end

      # Parse the markdown document into an AST.
      #
      # @return [Hash] The parsed AST
      def parse
        return @ast if @parsed

        begin
          require 'kramdown'
        rescue LoadError
          raise "Kramdown gem not available. Add 'kramdown' to Gemfile"
        end

        kd = Kramdown::Document.new(content)
        @ast = kd.to_hash
        @parsed = true

        @ast
      end

      # Get all text nodes for spell checking.
      #
      # Extracts text from the AST, skipping code blocks.
      #
      # @return [Array<TextNode>] Text nodes in the document
      def text_nodes
        extract_text_nodes
      end

      # Get node at a specific path in the AST.
      #
      # @param path [Array] Node path (e.g., [:document, :p, 1])
      # @return [Object, nil] The node or nil
      def get_node(path)
        parse unless @parsed

        navigate_ast(@ast, path)
      end

      # Get context around a location.
      #
      # For markdown, navigates the AST to find surrounding context.
      #
      # @param location [Location] The error location
      # @param window [Integer] Number of sibling elements before/after
      # @return [Models::Context] Context object
      def context_for(location, window: 2)
        return plain_text_context(location, window: 5) if location.line_column?

        parse unless @parsed

        # For node-based locations, find parent and siblings
        parent_path = location.node_path[0..-2]
        current_type = location.node_path.last

        parent = navigate_ast(@ast, parent_path)
        return Models::Context.new(before: "", current: "", after: "", location: location, window: window) unless parent

        # Find siblings around current element
        siblings = extract_siblings(parent)
        current_idx = siblings.find_index { |s| s[:type] == current_type }

        return Models::Context.new(before: "", current: "", after: "", location: location, window: window) unless current_idx

        before_sibs = siblings[[0, current_idx - window].max..current_idx - 1]
        after_sibs = siblings[(current_idx + 1)..(current_idx + window)]

        before = before_sibs.map { |s| text_from_node(s) }.join("\n")
        current = text_from_node(parent)
        after = after_sibs.map { |s| text_from_node(s) }.join("\n")

        Models::Context.new(
          before: before,
          current: current,
          after: after,
          location: location,
          window: window
        )
      end

      # Replace text at a specific location.
      #
      # Navigates the AST to find the text node and replaces it,
      # then regenerates markdown.
      #
      # @param location [Location] The location to replace
      # @param new_text [String] The new text
      #return [MarkdownDocument] New document with replacement
      def replace_node(location, new_text)
        parse unless @parsed

        # Navigate to the node and replace its text
        modified_ast = replace_in_ast(@ast, location.node_path, new_text)

        # Regenerate markdown from modified AST
        begin
          require 'kramdown'
          new_content = Kramdown::Converter.new(modified_ast).to_kramdown
        rescue LoadError
          raise "Kramdown gem not available. Add 'kramdown' to Gemfile"
        end

        MarkdownDocument.new(new_content, @format, @language_code)
      end

      # Apply corrections and return new document.
      #
      # @param corrections [Array<Models::SemanticError>] Errors to fix
      # @return [MarkdownDocument] New document with corrections
      def apply(corrections)
        return self if corrections.empty?

        # Apply corrections one by one
        result = self
        corrections.each do |error|
          suggestion = error.recommended_suggestion
          result = result.replace_node(error.location, suggestion.word)
        end

        result
      end

      # Document name for display.
      #
      # @return [String] Document name
      def name
        "markdown"
      end

      private

      # Extract text nodes from AST.
      #
      # @return [Array<TextNode>] Text nodes
      def extract_text_nodes
        parse unless @parsed
        extract_from_ast(@ast)
      end

      # Extract text nodes recursively from AST.
      #
      # @param ast [Hash] The AST or node
      # @param path [Array] Current path
      # @return [Array<TextNode>] Text nodes
      def extract_from_ast(ast, path: [])
        nodes = []

        case ast[:type]
        when :text
          nodes << TextNode.new(
            ast[:value].strip,
            location: Location.for_text_node(path, start_offset: 0, length: ast[:value].length),
            node_path: path
          )
        when :p, :h1, :h2, :h3, :h4, :h5, :h6
          # Check paragraph/header content
          if ast[:value]
            ast[:value].each_with_index do |child, idx|
              nodes.concat(extract_from_ast(child, path + [:content, ast[:type], idx]))
            end
          end
        when :blockquote
          nodes.concat(extract_from_ast(ast[:value], path + [:blockquote]))
        when :code_block
          # Skip code blocks (don't check code)
        when :link
          # Check link text but not URL
          link_text = ast[:value][:value]
          if link_text && !link_text.empty?
            nodes << TextNode.new(
              link_text,
              location: Location.for_text_node(path + [:link_text], start_offset: 0, length: link_text.length),
              node_path: path + [:link_text]
            )
          end
        when :strong, :em
          # Check emphasis content
          if ast[:value]
            nodes.concat(extract_from_ast(ast[:value], path + [:emphasis]))
          end
        when :document
          if ast[:children]
            ast[:children].each_with_index do |child, idx|
              nodes.concat(extract_from_ast(child, path + [:child, idx]))
            end
          end
        when :list
          # Check list items
          if ast[:value]
            ast[:value].each_with_index do |item, idx|
              nodes.concat(extract_from_ast(item, path + [:item, idx]))
            end
          end
        end

        nodes
      end

      # Navigate AST to find node at path.
      #
      # @param ast [Hash] The AST
      # @param path [Array] Node path
      # @return [Object, nil] The node or nil
      def navigate_ast(ast, path)
        return nil unless path.is_a?(Array) || path.empty?

        current = ast
        path.each do |element|
          case element
          when Integer
            # Array index
            return nil unless current.is_a?(Array)
            return nil if element >= current.size
            current = current[element]
          when Symbol, String
            # Hash key
            return nil unless current.is_a?(Hash)
            current = current[element.to_sym]
          else
            return nil
          end
        end

        current
      end

      # Extract sibling nodes from a parent node.
      #
      # @param parent [Hash] Parent node
      # @return [Array<Hash>] Sibling nodes
      def extract_siblings(parent)
        case parent[:type]
        when :document
          parent[:children] || []
        when :blockquote
          [parent[:value]].compact
        when :p, :h1, :h2, :h3, :h4, :h5, :h6
          parent[:value] || []
        when :list
          parent[:value] || []
        else
          []
        end
      end

      # Extract text content from a node.
      #
      # @param node [Hash] AST node
      # @return [String] Text content
      def text_from_node(node)
        case node[:type]
        when :text
          node[:value]
        when :p, :h1, :h2, :h3, :h4, :h5, :h6
          # Extract text from inline elements
          extract_inline_text(node[:value])
        when :code_block
          # Don't check code
          nil
        else
          ""
        end
      end

      # Extract text from inline markup.
      #
      # @param content [Array, String] Content with inline markup
      # @return [String] Extracted text
      def extract_inline_text(content)
        return "" unless content

        case content
        when String
          content
        when Array
          content.map { |elem| extract_inline_text(elem) }.join
        when Hash
          text = content[:value]
          text ? extract_inline_text(text) : ""
        else
          ""
        end
      end

      # Replace text in AST at a specific path.
      #
      # @param ast [Hash] The AST
      # @param path [Array] Node path to the text node
      # @param new_text [String] The replacement text
      # @return [Hash] Modified AST (frozen)
      def replace_in_ast(ast, path, new_text)
        return ast if path.empty?

        # Clone the AST (deep copy)
        modified_ast = deep_clone_ast(ast)

        # Navigate to the parent of the text node
        current_path = path[0..-2]  # All but last element (the text node)
        text_type = path.last  # Usually :text

        current = navigate_ast(modified_ast, current_path)
        return modified_ast unless current

        if current.is_a?(Hash) && current[:type] == :text
          # Replace the text value
          current[:value] = new_text
        elsif current.is_a?(Array)
          # Array of elements - find text node and replace
          current.each_with_index do |elem, idx|
            if elem.is_a?(Hash) && elem[:type] == :text
              current[idx][:value] = new_text
              break
            end
          end
        end

        modified_ast
      end

      # Deep clone an AST.
      #
      # @param ast [Hash] The AST to clone
      # @return [Hash] Cloned AST
      def deep_clone_ast(ast)
        case ast
        when Hash
          ast.transform_values { |v| deep_clone_ast(v) }
        when Array
          ast.map { |v| deep_clone_ast(v) }
        else
          ast
        end
      end

      # Get plain text context for line/column locations.
      #
      # Fallback for line/column locations in structured documents.
      #
      # @param location [Location] The line/column location
      # @param window [Integer] Number of lines before/after
      # @return [Models::Context] Context object
      def plain_text_context(location, window: 5)
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
    end
  end
end
