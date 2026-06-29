# frozen_string_literal: true

module Kotoshu
  module Documents
    # Document abstraction for structure-aware spell and grammar
    # checking. Pairs the flattened text a checker scans with the
    # source positions of each {TextNode}, so errors can be reported
    # against the original markup-bearing source.
    #
    # Subclasses (or plugins) populate +text_nodes+ with one entry per
    # contiguous text run, each carrying the {SourceRange} it occupies
    # in the source. The base class provides the bidirectional
    # offset-mapping logic — it walks the nodes to recover a source
    # range from a flattened offset.
    #
    # Kotoshu ships only {PlainTextDocument}; format-specific parsers
    # (Markdown, AsciiDoc, etc.) live in plugins.
    class Document
      attr_reader :text_nodes, :source, :format, :language_code

      # @param text_nodes [Array<TextNode>] one entry per contiguous
      #   text run, in source order
      # @param source [String, nil] the original markup-bearing source
      #   (kept around so consumers can slice it for context display)
      # @param format [Symbol] e.g. :plain, :markdown, :asciidoc
      # @param language_code [String, nil] ISO 639-1 code when known
      def initialize(text_nodes:, source: nil, format: :plain, language_code: nil)
        raise ArgumentError, "text_nodes cannot be empty" if text_nodes.nil? || text_nodes.empty?

        @text_nodes = text_nodes.freeze
        @source = source
        @format = format
        @language_code = language_code
        freeze
      end

      # The flattened text — concatenation of every node's +text+.
      # This is what the checker actually scans.
      #
      # @return [String]
      def flattened_text
        @text_nodes.map(&:text).join
      end

      # Total character length of the flattened text.
      def flattened_length
        @text_nodes.sum(&:length)
      end

      # True when +offset+ falls within the flattened text.
      def flattened_offset?(offset)
        offset >= 0 && offset < flattened_length
      end

      # Recover the {SourceRange} of the {TextNode} that contains the
      # given flattened offset. Returns nil for out-of-range offsets.
      #
      # Note: this returns the *node's* source range, not a one-char
      # slice. For a tighter range, use {#source_range_for} with a
      # flattened sub-range.
      #
      # @param flattened_offset [Integer] 0-based offset in flattened text
      # @return [SourceRange, nil]
      def source_range_at(flattened_offset)
        return nil unless flattened_offset?(flattened_offset)

        node = node_at(flattened_offset)
        node&.source_range
      end

      # Recover the {SourceRange} spanning a flattened sub-range.
      # The start of the result is the start of the node containing
      # +flattened_start+; the end is the end of the node containing
      # +flattened_end - 1+. Useful for errors that span multiple
      # text nodes (e.g. a grammar error like "an **friend**" that
      # crosses a markup boundary).
      #
      # @param flattened_start [Integer] inclusive
      # @param flattened_end [Integer] exclusive; pass nil for "to end"
      # @return [SourceRange, nil]
      def source_range_for(flattened_start, flattened_end = nil)
        return nil unless flattened_offset?(flattened_start)

        end_offset = flattened_end ? flattened_end - 1 : flattened_length - 1
        end_offset = [end_offset, flattened_length - 1].min
        return nil unless flattened_offset?(end_offset)

        start_node = node_at(flattened_start)
        end_node = node_at(end_offset)
        return nil unless start_node && end_node

        start_node.source_range.union(end_node.source_range)
      end

      # Iterate text nodes. Returns an Enumerator when no block given.
      def each_node(&block)
        return enum_for(:each_node) unless block

        @text_nodes.each(&block)
      end

      private

      # Find the TextNode whose flattened range contains +offset+.
      def node_at(offset)
        @text_nodes.find { |node| node.contains_flattened?(offset) }
      end
    end
  end
end
