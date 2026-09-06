# 53 — Document plugin architecture (T3.4)

## Goal

Formalize the boundary between kotoshu-core and format-specific
document parsers. The boundary is already decided (see
`kotoshu-document-plugin-boundary` memory): kotoshu never owns
document parsing. Plugins like `coradoc-plugin-kotoshu` provide
parsers that produce `Kotoshu::Documents::Document` instances.

This TODO formalizes the plugin contract, the registration mechanism,
and the audit that moves the existing built-in Markdown parser out of
core kotoshu (if/when a `markdown-plugin-kotoshu` exists).

## Design

### Plugin contract

A document plugin is a Ruby gem that:

1. Depends on `kotoshu`.
2. On load, calls `Kotoshu::Documents.register(format, ParserClass)`.
3. The parser class responds to:
   - `.from_string(text, language_code:)` → `Kotoshu::Documents::Document`
   - `.from_file(path, language_code:)` → `Kotoshu::Documents::Document` (optional)
4. The Document's `text_nodes` carry proper `SourceRange`s pointing
   into the original markup-bearing source.

### Discovery

Two discovery mechanisms:

1. **Explicit**: user code calls `Kotoshu::Documents.register` after
   requiring the plugin.
2. **Gem find-files**: a plugin ships a `kotoshu_plugin/document/*.rb`
   file. Kotoshu loads every such file at startup via
   `Gem.find_files("kotoshu_plugin/document/*.rb")`.

Both are supported. Explicit is the default; gem find-files is the
"just install the gem and it works" path.

### Built-in parsers

- **PlainTextDocument**: built-in, never moves. Plain text needs no
  parser.
- **MarkdownDocument**: currently lives in `lib/kotoshu/documents/`
  (was removed in TODO 50; verify and re-add as plugin if needed).
- **AsciiDocDocument**: same — was removed; should come from
  `coradoc-plugin-kotoshu`.

### Audit checklist

For each currently-shipped document parser, decide:

1. **Keep in core** (e.g. PlainTextDocument) — generic enough.
2. **Move to a plugin** (e.g. MarkdownDocument) — needs format-specific
   parsing logic that violates the boundary.

## Phases

### Phase 1 — Plugin API (DONE in TODO 50)
- `Kotoshu::Documents.register`, `parser_for`, `parse`,
  `registered_formats`, `reset!`.

### Phase 2 — Gem find-files discovery
- On kotoshu load, walk `Gem.find_files("kotoshu_plugin/document/*.rb")`.
- Each file is responsible for calling `Documents.register`.
- Add `Kotoshu::Documents.discovered_plugins` reader.

### Phase 3 — Audit existing parsers
- Confirm `lib/kotoshu/documents/` only contains core abstractions
  (Location, TextNode, Document, PlainTextDocument).
- If a Markdown or AsciiDoc parser exists in core, document it as a
  temporary exception OR migrate.

### Phase 4 — Plugin authoring docs
- README section "Writing a document plugin".
- Example plugin skeleton.
- YARD on the contract.

## Acceptance criteria

- [ ] A plugin installed as a gem is auto-discovered without user code.
- [ ] `Kotoshu::Documents.discovered_plugins` lists discovered plugins.
- [ ] No format-specific parsing code in `lib/kotoshu/documents/`
      beyond PlainTextDocument.
- [ ] README has a "Writing a document plugin" section.
- [ ] Full suite stays green.

## Dependencies

- **Blocked by:** TODO 50 (document API).
- **Blocks:** coradoc-plugin-kotoshu's structure-aware checking
  (that plugin is the canonical consumer).
