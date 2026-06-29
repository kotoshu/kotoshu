# frozen_string_literal: true

module Kotoshu
  # Document model for structure-aware spell and grammar checking.
  #
  # The Document abstraction pairs the *flattened* text a checker scans
  # with the *source* positions of each text run, so that errors can be
  # reported against the original markup-bearing source rather than the
  # stripped text. The canonical example is an AsciiDoc or Markdown
  # sentence like `I'm an **friend** of Tom`: the checker sees the
  # flattened `I'm an friend of Tom` and flags "an friend", but the
  # error report needs to point at the original `an **friend**` range
  # so an editor can highlight what the user actually wrote.
  #
  # Kotoshu ships only the value-object layer and a trivial
  # {PlainTextDocument}. Format-specific parsers (Markdown, AsciiDoc,
  # reStructuredText, etc.) live in plugins — kotoshu never owns
  # document parsing (see the `kotoshu-document-plugin-boundary` design
  # memory). Plugins register a parser class via {Documents.register}
  # and produce {Document} instances whose {TextNode}s carry proper
  # {SourceRange}s.
  module Documents
    autoload :SourcePosition, "kotoshu/documents/source_position"
    autoload :SourceRange, "kotoshu/documents/source_range"
    autoload :TextNode, "kotoshu/documents/text_node"
    autoload :Document, "kotoshu/documents/document"
    autoload :PlainTextDocument, "kotoshu/documents/plain_text_document"

    @parsers = {}

    class << self
      # Register a document parser for a format symbol.
      #
      # The parser class must respond to `.from_string(text,
      # language_code:)` and return a {Document}. Optionally also
      # `.from_file(path, language_code:)` for file-source parsing.
      #
      # @param format [Symbol] e.g. :plain, :markdown, :asciidoc
      # @param parser_class [Class] responds to .from_string
      # @return [void]
      def register(format, parser_class)
        @parsers[format.to_sym] = parser_class
      end

      # Look up the registered parser for a format.
      #
      # @param format [Symbol]
      # @return [Class, nil]
      def parser_for(format)
        @parsers[format.to_sym]
      end

      # List every registered format symbol.
      #
      # @return [Array<Symbol>]
      def registered_formats
        @parsers.keys
      end

      # Parse a source string with the registered parser for +format+,
      # falling back to {PlainTextDocument} when no parser is
      # registered. Never raises — the fallback is intentional so
      # callers can pass arbitrary format hints without first checking
      # the registry.
      #
      # @param source [String]
      # @param format [Symbol]
      # @param language_code [String, nil]
      # @return [Document]
      def parse(source, format:, language_code: nil)
        parser = parser_for(format) || PlainTextDocument
        parser.from_string(source, language_code: language_code)
      end

      # Clear every registration. Test-only — production code should
      # register once at load time.
      #
      # @return [void]
      def reset!
        @parsers.clear
      end
    end
  end
end
