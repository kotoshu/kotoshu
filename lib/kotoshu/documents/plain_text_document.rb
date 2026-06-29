# frozen_string_literal: true

module Kotoshu
  module Documents
    # Built-in {Document} parser for plain text (no markup).
    #
    # The only parser kotoshu ships. Format-specific parsers (Markdown,
    # AsciiDoc, etc.) live in plugins — see {Documents.register}.
    #
    # PlainTextDocument is intentionally simple: one {TextNode}
    # covering the entire source. The flattened text equals the source,
    # so source-to-flattened mapping is the identity.
    class PlainTextDocument < Document
      # Build a document from a string.
      #
      # @param text [String]
      # @param language_code [String, nil]
      # @return [PlainTextDocument]
      def self.from_string(text, language_code: nil)
        text ||= ""
        range = source_range_for_string(text, 0)
        new(
          text_nodes: [TextNode.new(text: text, source_range: range,
                                    flattened_offset: 0, format: :plain, metadata: {})],
          source: text,
          format: :plain,
          language_code: language_code
        )
      end

      # Build a document from a file.
      #
      # @param path [String]
      # @param language_code [String, nil]
      # @return [PlainTextDocument]
      def self.from_file(path, language_code: nil)
        from_string(File.read(path), language_code: language_code)
      end

      class << self
        private

        # Compute the SourceRange for +text+ starting at +base_offset+
        # in the source. Walks the string once to find the final line
        # and column.
        def source_range_for_string(text, base_offset)
          start_pos = SourcePosition.new(offset: base_offset, line: 1, column: 1)

          line = 1
          column = 1
          text.each_char do |char|
            if char == "\n"
              line += 1
              column = 1
            else
              column += 1
            end
          end

          end_pos = SourcePosition.new(
            offset: base_offset + text.length,
            line: line,
            column: column
          )
          SourceRange.new(start_pos: start_pos, end_pos: end_pos)
        end
      end
    end
  end
end
