# frozen_string_literal: true

module Kotoshu
  module Documents
    # Inline ignore directives (plan 82, Track A).
    #
    # A user can mark intentionally-"wrong" words (product names, code
    # identifiers in prose, dialect) as ignored directly in the
    # document, instead of polluting the personal dictionary:
    #
    #   kotoshu:disable-line                 suppress everything on this line
    #   kotoshu:disable-next-line            suppress the following line
    #   kotoshu:disable-next-line foo bar    suppress only these words
    #   kotoshu:disable-file / enable-file   block suppression
    #
    # Each document format recognizes the directive inside its own
    # comment syntax: HTML comments in Markdown
    # (`<!-- kotoshu:disable-next-line -->`), `//` line comments in
    # AsciiDoc, and bare lines in plain text. Trailing directives are
    # supported in Markdown and AsciiDoc.
    #
    # ONE shared scanner implements the semantics; only comment
    # detection is per-format (see {Scanner}). Documents attach the
    # resulting {Suppression} records during parse, and the
    # Spellchecker facade filters suppressed words out of its results
    # (they surface via `DocumentResult#suppressed_errors`).
    module Suppressions
      autoload :Suppression, "kotoshu/documents/suppressions/suppression"
      autoload :Scanner, "kotoshu/documents/suppressions/scanner"

      # Scan +source+ for ignore directives using the comment syntax
      # of +format+ (:plain, :markdown, :asciidoc, or :auto for all
      # three — the facade default, since it sees raw text without a
      # parser).
      #
      # @param source [String, nil]
      # @param format [Symbol]
      # @return [Array<Suppression>] frozen, possibly empty
      def self.scan(source, format: :auto)
        Scanner.scan(source, format: format)
      end
    end
  end
end
