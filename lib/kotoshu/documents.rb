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
    @discovered_formats = []
    @discovered_plugins_loaded = false

    class << self
      # Register a document parser for a format symbol.
      #
      # The parser class must respond to:
      #
      #   .from_string(text, language_code:) -> Documents::Document
      #
      # Optionally also:
      #
      #   .from_file(path, language_code:) -> Documents::Document
      #
      # ==== Parser contract ====
      #
      # The returned {Document}'s +text_nodes+ must each carry a
      # {Documents::SourceRange} that points at the original
      # markup-bearing source for that node. This is the structure-aware
      # contract — the analyzer reads the document's flattened text
      # to run spelling/grammar checks, but every error is reported
      # against the original source so an editor or plugin can
      # highlight the user's actual markup, not the stripped text.
      #
      # Example: for the source
      #
      #   "I'm an **friend** of Tom"
      #
      # the parser produces TextNodes whose SourceRanges cover the
      # original range, not the flattened "I'm an friend of Tom".
      # A grammar error "an friend" → "a friend" then carries a
      # SourceRange pointing at "an **friend**" (the bold span plus the
      # preceding "an ").
      #
      # ==== Format symbol ====
      #
      # +format+ is the canonical symbol callers pass to {.parse}. The
      # gem ships +:plain+ (via {PlainTextDocument}). Plugins
      # commonly add +:markdown+, +:asciidoc+, +:rst+, +:latex+, etc.
      # Format symbols are global — two plugins registering the same
      # symbol is a name clash; the last one wins.
      #
      # ==== Discovery ====
      #
      # Plugins ship a file under +kotoshu_plugin/document/*.rb+ in
      # their gem. The first lookup of {.parser_for} / {.parse} walks
      # +Gem.find_files+ for those files and requires each one. Each
      # file's body is expected to call {.register} for the formats
      # it provides. See {.discovered_plugin_files} and
      # {.discovered_formats}.
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
        ensure_plugins_discovered!
        @parsers[format.to_sym]
      end

      # List every registered format symbol.
      #
      # @return [Array<Symbol>]
      def registered_formats
        ensure_plugins_discovered!
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
        ensure_plugins_discovered!
        parser = parser_for(format) || PlainTextDocument
        parser.from_string(source, language_code: language_code)
      end

      # List every plugin file found on the load path via
      # +Gem.find_files("kotoshu_plugin/document/*.rb")+. Each such
      # file, when required, is expected to call {register} for the
      # formats it provides. The list is the raw file paths; not
      # loaded into the registry yet.
      #
      # @return [Array<String>]
      def discovered_plugin_files
        Gem.find_files("kotoshu_plugin/document/*.rb").sort
      end

      # List every format symbol that came from an auto-discovered
      # plugin (vs. one registered explicitly at runtime). Useful for
      # diagnostics and "which plugin registered this format?" UX.
      #
      # @return [Array<Symbol>]
      def discovered_formats
        ensure_plugins_discovered!
        @discovered_formats.dup.freeze
      end

      # Clear every registration. Test-only — production code should
      # register once at load time. Also resets the discovery flag so
      # the next lookup re-runs Gem.find_files.
      #
      # @return [void]
      def reset!
        @parsers.clear
        @discovered_formats.clear
        @discovered_plugins_loaded = false
      end

      private

      # Walk Gem.find_files for plugin files at most once per
      # process. Each file is +require+d; the file's body is expected
      # to call {register}. Idempotent — re-entry is a no-op once the
      # flag is set.
      #
      # The set of formats registered by each plugin file is captured
      # by snapshotting the registry before and after the require.
      def ensure_plugins_discovered!
        return if @discovered_plugins_loaded

        @discovered_plugins_loaded = true
        before = @parsers.keys
        discovered_plugin_files.each do |path|
          require path
        rescue StandardError, LoadError => e
          warn "kotoshu: failed to load document plugin #{path}: #{e.message}"
        end
        after = @parsers.keys
        @discovered_formats.concat(after - before)
      end
    end
  end
end
