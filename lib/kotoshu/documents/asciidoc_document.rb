# frozen_string_literal: true

require_relative 'document'
require_relative 'location'

module Kotoshu
  module Documents
    # AsciiDoc document implementation.
    #
    # Handles AsciiDoc files with AST parsing for structured navigation.
    #
    # @example Creating an asciidoc document
    #   doc = AsciidocDocument.new("= Title\n\nParagraph text")
    #   doc.text_nodes.each { |node| puts node.text }
    class AsciidocDocument < Document
      require 'asciidoctor' if ENV['KOTOSHU_REQUIRE_ASCIIDOC']

      # Create a new asciidoc document.
      #
      # @param content [String] The document content
      # @param format [Symbol] Document format (must be :asciidoc)
      # @param language_code [String] Language code
      def initialize(content, format: :asciidoc, language_code: 'en')
        raise ArgumentError, "Format must be :asciidoc" unless format == :asciidoc

        super(content, format: format, language_code: language_code)
        @parsed = false
        @ast = nil
      end

      # Parse the asciidoc document into an AST.
      #
      # @return [Array<Asciidoctor::AbstractBlock>] The parsed AST
      def parse
        return @ast if @parsed

        begin
          require 'asciidoctor'
        rescue LoadError
          raise "Asciidoctor gem not available. Add 'asciidoctor' to Gemfile"
        end

        # Parse with Asciidoctor
        doc = Asciidoctor.load(content, parse: false, header_footer: false)
        @ast = doc.blocks
        @parsed = true

        @ast
      end

      # Get all text nodes for spell checking.
      #
      # Extracts text from the AST, skipping code blocks and source listings.
      #
      # @return [Array<TextNode>] Text nodes in the document
      def text_nodes
        extract_text_nodes
      end

      # Get node at a specific path in the AST.
      #
      # @param path [Array] Node path (e.g., [:section, 0, :paragraph, 2])
      # @return [Object, nil] The node or nil
      def get_node(path)
        parse unless @parsed

        navigate_ast(@ast, path)
      end

      # Get context around a location.
      #
      # For asciidoc, navigates the AST to find surrounding context.
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
        current_idx = siblings.find_index { |s| node_type(s) == current_type }

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
      # then regenerates asciidoc.
      #
      # @param location [Location] The location to replace
      # @param new_text [String] The new text
      # @return [AsciidocDocument] New document with replacement
      def replace_node(location, new_text)
        parse unless @parsed

        # Navigate to the node and replace its text
        modified_ast = replace_in_ast(@ast, location.node_path, new_text)

        # Regenerate asciidoc from modified AST
        begin
          require 'asciidoctor'
          new_content = convert_ast_to_asciidoc(modified_ast)
        rescue LoadError
          raise "Asciidoctor gem not available. Add 'asciidoctor' to Gemfile"
        end

        AsciidocDocument.new(new_content, @format, @language_code)
      end

      # Apply corrections and return new document.
      #
      # @param corrections [Array<Models::SemanticError>] Errors to fix
      # @return [AsciidocDocument] New document with corrections
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
        "asciidoc"
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
      # @param blocks [Array<Asciidoctor::AbstractBlock>] Blocks or nodes
      # @param path [Array] Current path
      # @return [Array<TextNode>] Text nodes
      def extract_from_ast(blocks, path: [])
        nodes = []

        return nodes unless blocks&.is_a?(Array)

        blocks.each_with_index do |block, idx|
          current_path = path + [node_type_sym(block), idx]

          case block
          when Asciidoctor::Block
            # Skip code blocks and source listings
            next if block.context == :listing || block.context == :literal

            # Extract text from paragraph
            if block.context == :paragraph
              text = block.source&.strip
              if text && !text.empty?
                nodes << TextNode.new(
                  text,
                  location: Location.for_text_node(current_path, start_offset: 0, length: text.length),
                  node_path: current_path
                )
              end
            end

            # Extract inline text from other blocks
            if block.content
              inline_text = extract_inline_content(block.content)
              if inline_text && !inline_text.empty?
                nodes << TextNode.new(
                  inline_text,
                  location: Location.for_text_node(current_path, start_offset: 0, length: inline_text.length),
                  node_path: current_path
                )
              end
            end

            # Recurse into nested blocks
            nodes.concat(extract_from_ast(block.blocks, path: current_path)) if block.blocks&.any?

          when Asciidoctor::Section
            # Extract title from section
            if block.title
              nodes << TextNode.new(
                block.title,
                location: Location.for_text_node(current_path + [:title], start_offset: 0, length: block.title.length),
                node_path: current_path + [:title]
              )
            end

            # Recurse into section blocks
            nodes.concat(extract_from_ast(block.blocks, path: current_path))
          end
        end

        nodes
      end

      # Extract inline content from a block.
      #
      # @param content [String] Block content
      # @return [String] Extracted text
      def extract_inline_content(content)
        return "" unless content

        # For now, just return the content as-is
        # In full implementation, would parse inline formatting (bold, italic, links, etc.)
        content.to_s.strip
      end

      # Navigate AST to find node at path.
      #
      # @param ast [Array] The AST
      # @param path [Array] Node path
      # @return [Object, nil] The node or nil
      def navigate_ast(ast, path)
        return nil unless path&.is_a?(Array) || path&.empty?

        current = ast
        path.each do |element|
          case element
          when Integer
            # Array index
            return nil unless current.is_a?(Array)
            return nil if element >= current.size
            current = current[element]
          when Symbol, String
            # Property access
            if element == :title && current.respond_to?(:title)
              current = current.title
            else
              # Navigate by context type
              current = current.find { |node| node_type_sym(node) == element.to_sym } if current.is_a?(Array)
            end
          else
            return nil
          end
        end

        current
      end

      # Extract sibling nodes from a parent node.
      #
      # @param parent [Object] Parent node
      # @return [Array] Sibling nodes
      def extract_siblings(parent)
        case parent
        when Asciidoctor::Section
          parent.blocks || []
        when Array
          parent
        else
          []
        end
      end

      # Extract text content from a node.
      #
      # @param node [Object] AST node
      # @return [String] Text content
      def text_from_node(node)
        case node
        when Asciidoctor::Block
          node.source || ""
        when Asciidoctor::Section
          node.title || ""
        when String
          node
        else
          ""
        end
      end

      # Get the node type symbol.
      #
      # @param node [Object] AST node
      # @return [Symbol] Node type
      def node_type_sym(node)
        return :section if node.is_a?(Asciidoctor::Section)
        return :paragraph if node.is_a?(Asciidoctor::Block) && node.context == :paragraph
        return :listing if node.is_a?(Asciidoctor::Block) && node.context == :listing
        :block
      end

      # Get the node type.
      #
      # @param node [Object] AST node
      # @return [Symbol] Node type
      def node_type(node)
        node_type_sym(node)
      end

      # Replace text in AST at a specific path.
      #
      # @param ast [Array] The AST
      # @param path [Array] Node path to the text node
      # @param new_text [String] The replacement text
      # @return [Array] Modified AST
      def replace_in_ast(ast, path, new_text)
        return ast if path.empty?

        # Clone the AST (shallow copy for now)
        modified_ast = ast.dup

        # Navigate to the target node
        if path.length == 1
          # Direct child replacement
          idx = path.first
          return modified_ast unless idx.is_a?(Integer)

          if modified_ast[idx].is_a?(Asciidoctor::Block)
            # Replace block source (this creates a new block)
            old_block = modified_ast[idx]
            new_block = Asciidoctor::Block.new(
              old_block.parent,
              old_block.context,
              source: new_text,
              attributes: old_block.attributes
            )
            modified_ast[idx] = new_block
          end
        else
          # Navigate deeper
          first_elem = path.first
          rest_path = path[1..-1]

          if first_elem.is_a?(Integer) && modified_ast[first_elem]
            if modified_ast[first_elem].is_a?(Asciidoctor::Section)
              # Recurse into section blocks
              new_blocks = replace_in_ast(modified_ast[first_elem].blocks, rest_path, new_text)
              modified_ast[first_elem].instance_variable_set(:@blocks, new_blocks)
            elsif modified_ast[first_elem].is_a?(Asciidoctor::Block)
              # Recurse into nested blocks
              new_blocks = replace_in_ast(modified_ast[first_elem].blocks, rest_path, new_text)
              modified_ast[first_elem].instance_variable_set(:@blocks, new_blocks)
            end
          end
        end

        modified_ast
      end

      # Convert AST back to AsciiDoc format.
      #
      # @param ast [Array] The AST
      # @return [String] AsciiDoc source
      def convert_ast_to_asciidoc(ast)
        lines = []

        ast.each do |node|
          case node
          when Asciidoctor::Section
            # Section title
            level = "=" * (node.level + 1)
            lines << "#{level} #{node.title}"
            lines << ""

            # Section content
            lines << convert_ast_to_asciidoc(node.blocks)

          when Asciidoctor::Block
            case node.context
            when :paragraph
              lines << node.source
              lines << ""
            when :listing
              lines << "----"
              lines << node.source
              lines << "----"
              lines << ""
            else
              lines << node.source.to_s
              lines << ""
            end
          end
        end

        lines.join("\n")
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
