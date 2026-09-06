# 50 — Structure-aware document checking API

## Goal

Define the value-object + parser-contract layer that lets document
plugins (coradoc-plugin-kotoshu, markdown-plugin-kotoshu, etc.) perform
**structure-aware** spell/grammar checks: the checker scans the
flattened text, but every error carries a position that maps back to
the original (markup-bearing) source.

## Motivation

Concrete example from the user:

> Source: `I'm an **friend** of Tom`
> Flattened: `I'm an friend of Tom`
> Error: "an friend" should be "a friend"

The grammar checker sees the flattened sentence and flags "an friend".
But the error report must reference the original source — specifically
the range `an **friend**` — so an editor can highlight the actual
markdown/AsciiDoc the user wrote, not the stripped text.

This is the **plugin's** job (kotoshu never owns document parsing —
see `kotoshu-document-plugin-boundary.md` memory). Kotoshu's job is to
provide:

1. Value objects for source position + range.
2. A TextNode model that pairs flattened text with its source range.
3. A Document interface with bidirectional offset mapping.
4. An error model that carries source positions.
5. A registry where plugins register format-specific parsers.

## Design

### Value objects

    Kotoshu::Documents::SourcePosition
      offset : Integer  # 0-based char offset in the original source
      line   : Integer  # 1-based line number
      column : Integer  # 1-based column (chars from line start)

    Kotoshu::Documents::SourceRange
      start : SourcePosition  # inclusive
      end   : SourcePosition  # exclusive

Both are `Struct.new(..., keyword_init: true)` with `freeze` on
construct. Comparable via `include Comparable` so ranges can be sorted
and tested for containment.

### Text node

    Kotoshu::Documents::TextNode
      text             : String          # flattened text (no markup)
      source_range     : SourceRange     # where this node lives in source
      flattened_offset : Integer         # 0-based offset in concatenated flattened text
      format           : Symbol          # :plain, :bold, :italic, :code, :heading, ...
      metadata         : Hash            # format-specific ({level: 2} for h2, etc.)

A document is a list of text nodes. Concatenating `node.text` for
every node yields the flattened text the checker scans.

### Document interface

    class Kotoshu::Documents::Document
      attr_reader :text_nodes, :source, :format

      def flattened_text
        text_nodes.map(&:text).join
      end

      def flattened_length
        text_nodes.sum { |n| n.text.length }
      end

      # Map a flattened-text offset to the source range containing it.
      def source_range_at(flattened_offset)
        # Walk nodes; find the one whose flattened window contains the
        # offset. Return that node's source_range.
      end

      # Map a flattened-text range to the source range spanning it.
      def source_range_for(flattened_start, flattened_end)
        # Combine source_range_at(start).start with
        # source_range_at(end - 1).end.
      end
    end

### Built-in: PlainTextDocument

    class Kotoshu::Documents::PlainTextDocument < Document
      def self.from_string(text, language_code: nil)
        nodes = [TextNode.new(text: text, source_range: full_range(text),
                              flattened_offset: 0, format: :plain, metadata: {})]
        new(text_nodes: nodes, source: text, format: :plain)
      end

      def self.from_file(path, language_code: nil)
        from_string(File.read(path), language_code: language_code)
      end
    end

PlainTextDocument is the only parser kotoshu ships. Markdown, AsciiDoc,
reStructuredText, etc. are plugin territory.

### Plugin parser registry

    module Kotoshu::Documents
      def self.register(format, parser_class)
        # parser_class responds to .from_string(text, language_code:) and
        # optionally .from_file(path, language_code:).
      end

      def self.parser_for(format)
        # Returns the registered parser class or nil.
      end

      def self.parse(source, format:, language_code: nil)
        parser = parser_for(format) || PlainTextDocument
        parser.from_string(source, language_code: language_code)
      end
    end

A plugin (`coradoc-plugin-kotoshu`) does:

    Kotoshu::Documents.register(:asciidoc, CoradocPluginKotoshu::AsciidocParser)

on load. The parser produces a `Kotoshu::Documents::Document` whose
text_nodes carry proper source_ranges (coradoc knows the offsets).

### Error model

Errors carry the source range directly. The checker resolves it from
the document before constructing the error:

    class Kotoshu::Models::SemanticError
      attr_reader :source_range, :original, :suggestions, ...
      def initialize(source_range:, original:, suggestions:, ...)
    end

For checkers that work on plain strings (no Document), `source_range`
is nil and the flattened position is the only positional info.

### Check pipeline

    analyzer.analyze(document) do |error|
      # error.source_range is already resolved
      plugin_or_editor.highlight(error.source_range)
    end

Existing analyzer code stays the same — it iterates text_nodes and
emits errors. The change is that errors now carry source_range from
the text_node they originated in.

## Phases

### Phase 1 — Core abstractions (this PR)
- SourcePosition, SourceRange, TextNode, Document, PlainTextDocument.
- Documents::Document.register / parser_for / parse registry.
- Specs for each.

### Phase 2 — Pipeline integration (this PR)
- SemanticAnalyzer accepts a Document, emits errors with source_range.
- WordResult / DocumentResult carry source_range.
- CheckCommand (currently dead code referencing non-existent
  `Documents::Document`) is either removed or rewritten to use the new
  API.

### Phase 3 — Plugin contract docs (this PR)
- README section "Writing a document plugin".
- YARD on `Kotoshu::Documents.register` documenting the parser class
  contract.

### Phase 4 — coradoc-plugin-kotoshu (separate repo)
- coradoc-plugin-kotoshu implements the parser for AsciiDoc.
- Out of scope for kotoshu proper.

## Acceptance criteria

- [ ] SourcePosition, SourceRange, TextNode, Document, PlainTextDocument
      all have direct specs (real instances, no doubles).
- [ ] `Document#source_range_for(flattened_start, flattened_end)` returns
      the correct SourceRange for the example "I'm an **friend** of Tom".
- [ ] SemanticAnalyzer emits errors carrying `source_range`.
- [ ] A plugin can register via `Kotoshu::Documents.register(:fmt, klass)`.
- [ ] No `respond_to?`, `send`-to-private, `instance_variable_*`,
      `require_relative` in the new code.
- [ ] Full suite stays green (2901+ examples, 0 failures).

## Dependencies

- **Blocked by:** none.
- **Blocks:** coradoc-plugin-kotoshu's structure-aware checking (that
  plugin consumes this API).
