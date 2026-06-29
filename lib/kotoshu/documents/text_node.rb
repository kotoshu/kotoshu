# frozen_string_literal: true

module Kotoshu
  module Documents
    # A contiguous run of flattened text plus its source position.
    #
    # The checker scans the concatenation of every text node's +text+
    # (the document's flattened form). Each node carries the {SourceRange}
    # it occupies in the original markup-bearing source, plus its
    # +flattened_offset+ (where the node starts in the concatenated
    # flattened text) so the document can map errors back to source.
    #
    # +format+ and +metadata+ are escape hatches for plugins that want
    # to attach structural context (e.g. `format: :heading,
    # metadata: { level: 2 }` for an h2). Kotoshu's core checker
    # ignores them; consumers (editors, reporters) can use them to
    # surface context-aware UI.
    TextNode = Struct.new(:text, :source_range, :flattened_offset, :format, :metadata,
                          keyword_init: true) do
      def initialize(text:, source_range:, flattened_offset:, format: :plain, metadata: {})
        raise TypeError, "source_range must be a SourceRange" unless source_range.is_a?(SourceRange)
        raise ArgumentError, "flattened_offset must be >= 0" if flattened_offset.negative?

        super
        freeze
      end

      # Length of the flattened text in this node.
      def length
        text.length
      end

      # Flattened-text range covered by this node: [flattened_offset,
      # flattened_offset + text.length).
      def flattened_range
        flattened_offset...(flattened_offset + text.length)
      end

      # True when +offset+ falls within this node's flattened range.
      def contains_flattened?(offset)
        flattened_range.include?(offset)
      end

      def to_s
        "#{format}(#{text.inspect} @ #{source_range})"
      end
    end
  end
end
