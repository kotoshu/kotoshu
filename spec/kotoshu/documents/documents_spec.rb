# frozen_string_literal: true

require "kotoshu"
require "tmpdir"
require "fileutils"

# Direct spec for the structure-aware document API (TODO.impl/50).
#
# The Document abstraction pairs the flattened text a checker scans
# with the source positions of each TextNode, so errors can be
# reported against the original markup-bearing source. Kotoshu ships
# only the value-object layer plus PlainTextDocument; format-specific
# parsers (Markdown, AsciiDoc, etc.) are plugin territory.
RSpec.describe Kotoshu::Documents do
  # ---- SourcePosition -------------------------------------------------

  describe Kotoshu::Documents::SourcePosition do
    it "is a frozen Struct with offset, line, column" do
      p = described_class.new(offset: 7, line: 1, column: 8)
      expect(p.offset).to eq(7)
      expect(p.line).to eq(1)
      expect(p.column).to eq(8)
      expect(p).to be_frozen
    end

    it "rejects negative offset" do
      expect { described_class.new(offset: -1, line: 1, column: 1) }
        .to raise_error(ArgumentError, /offset must be >= 0/)
    end

    it "rejects line < 1" do
      expect { described_class.new(offset: 0, line: 0, column: 1) }
        .to raise_error(ArgumentError, /line must be >= 1/)
    end

    it "rejects column < 1" do
      expect { described_class.new(offset: 0, line: 1, column: 0) }
        .to raise_error(ArgumentError, /column must be >= 1/)
    end

    it "is Comparable — lexicographic by (offset, line, column)" do
      a = described_class.new(offset: 0, line: 1, column: 1)
      b = described_class.new(offset: 5, line: 1, column: 6)
      c = described_class.new(offset: 5, line: 2, column: 1)
      expect(a < b).to be true
      expect(b < c).to be true
      expect(c > a).to be true
    end

    it "returns nil <=> for non-SourcePosition" do
      p = described_class.new(offset: 0, line: 1, column: 1)
      expect(p <=> "not a position").to be_nil
    end
  end

  # ---- SourceRange ----------------------------------------------------

  describe Kotoshu::Documents::SourceRange do
    let(:start_pos) { Kotoshu::Documents::SourcePosition.new(offset: 0, line: 1, column: 1) }
    let(:end_pos) { Kotoshu::Documents::SourcePosition.new(offset: 5, line: 1, column: 6) }
    let(:range) { described_class.new(start_pos: start_pos, end_pos: end_pos) }

    it "exposes start, end, and length" do
      expect(range.start).to eq(start_pos)
      expect(range.end).to eq(end_pos)
      expect(range.length).to eq(5)
    end

    it "is frozen" do
      expect(range).to be_frozen
    end

    it "rejects end < start" do
      later = Kotoshu::Documents::SourcePosition.new(offset: 10, line: 1, column: 11)
      expect { described_class.new(start_pos: later, end_pos: start_pos) }
        .to raise_error(ArgumentError, /end must be >= start/)
    end

    it "rejects non-SourcePosition args" do
      expect { described_class.new(start_pos: "x", end_pos: end_pos) }
        .to raise_error(TypeError)
    end

    describe "#contains?" do
      it "is true for a position between start (inclusive) and end (exclusive)" do
        inside = Kotoshu::Documents::SourcePosition.new(offset: 3, line: 1, column: 4)
        before = Kotoshu::Documents::SourcePosition.new(offset: 0, line: 1, column: 1)
        at_end = Kotoshu::Documents::SourcePosition.new(offset: 5, line: 1, column: 6)
        expect(range.contains?(inside)).to be true
        expect(range.contains?(before)).to be true   # start inclusive
        expect(range.contains?(at_end)).to be false   # end exclusive
      end
    end

    describe "#union" do
      it "spans both ranges" do
        other_start = Kotoshu::Documents::SourcePosition.new(offset: 7, line: 1, column: 8)
        other_end = Kotoshu::Documents::SourcePosition.new(offset: 12, line: 1, column: 13)
        other = described_class.new(start_pos: other_start, end_pos: other_end)

        merged = range.union(other)
        expect(merged.start).to eq(start_pos)
        expect(merged.end).to eq(other_end)
      end

      it "is reflexive — union(self) returns an equivalent range" do
        merged = range.union(range)
        expect(merged.start).to eq(range.start)
        expect(merged.end).to eq(range.end)
      end
    end

    describe "#empty?" do
      it "is true when start == end" do
        empty = described_class.new(start_pos: start_pos, end_pos: start_pos)
        expect(empty).to be_empty
      end

      it "is false otherwise" do
        expect(range).not_to be_empty
      end
    end
  end

  # ---- TextNode -------------------------------------------------------

  describe Kotoshu::Documents::TextNode do
    let(:range) do
      Kotoshu::Documents::SourceRange.new(
        start_pos: Kotoshu::Documents::SourcePosition.new(offset: 0, line: 1, column: 1),
        end_pos: Kotoshu::Documents::SourcePosition.new(offset: 5, line: 1, column: 6)
      )
    end

    it "is a frozen Struct with text, source_range, flattened_offset, format, metadata" do
      node = described_class.new(
        text: "hello", source_range: range, flattened_offset: 0,
        format: :plain, metadata: { foo: 1 }
      )
      expect(node.text).to eq("hello")
      expect(node.source_range).to eq(range)
      expect(node.flattened_offset).to eq(0)
      expect(node.format).to eq(:plain)
      expect(node.metadata).to eq(foo: 1)
      expect(node).to be_frozen
    end

    it "defaults format to :plain and metadata to {}" do
      node = described_class.new(text: "x", source_range: range, flattened_offset: 0)
      expect(node.format).to eq(:plain)
      expect(node.metadata).to eq({})
    end

    it "rejects negative flattened_offset" do
      expect { described_class.new(text: "x", source_range: range, flattened_offset: -1) }
        .to raise_error(ArgumentError, /flattened_offset must be >= 0/)
    end

    it "rejects non-SourceRange source_range" do
      expect { described_class.new(text: "x", source_range: :nope, flattened_offset: 0) }
        .to raise_error(TypeError)
    end

    describe "#flattened_range" do
      it "returns flattened_offset...(flattened_offset + text.length)" do
        node = described_class.new(text: "hello", source_range: range, flattened_offset: 10)
        expect(node.flattened_range).to eq(10...15)
      end
    end

    describe "#contains_flattened?" do
      it "is true for offsets inside flattened_range" do
        node = described_class.new(text: "hello", source_range: range, flattened_offset: 10)
        expect(node.contains_flattened?(10)).to be true
        expect(node.contains_flattened?(14)).to be true
        expect(node.contains_flattened?(15)).to be false
        expect(node.contains_flattened?(9)).to be false
      end
    end
  end

  # ---- Document -------------------------------------------------------

  describe Kotoshu::Documents::Document do
    let(:node_a) do
      Kotoshu::Documents::TextNode.new(
        text: "I'm an ",
        source_range: Kotoshu::Documents::SourceRange.new(
          start_pos: Kotoshu::Documents::SourcePosition.new(offset: 0, line: 1, column: 1),
          end_pos: Kotoshu::Documents::SourcePosition.new(offset: 7, line: 1, column: 8)
        ),
        flattened_offset: 0,
        format: :plain
      )
    end

    # Source: "**friend**" — the markup takes 10 chars (offsets 7..17),
    # but the flattened text "friend" is only 6 chars.
    let(:node_b) do
      Kotoshu::Documents::TextNode.new(
        text: "friend",
        source_range: Kotoshu::Documents::SourceRange.new(
          start_pos: Kotoshu::Documents::SourcePosition.new(offset: 7, line: 1, column: 8),
          end_pos: Kotoshu::Documents::SourcePosition.new(offset: 17, line: 1, column: 18)
        ),
        flattened_offset: 7,
        format: :bold
      )
    end

    let(:node_c) do
      Kotoshu::Documents::TextNode.new(
        text: " of Tom",
        source_range: Kotoshu::Documents::SourceRange.new(
          start_pos: Kotoshu::Documents::SourcePosition.new(offset: 17, line: 1, column: 18),
          end_pos: Kotoshu::Documents::SourcePosition.new(offset: 24, line: 1, column: 25)
        ),
        flattened_offset: 13,
        format: :plain
      )
    end

    let(:document) do
      described_class.new(
        text_nodes: [node_a, node_b, node_c],
        source: "I'm an **friend** of Tom",
        format: :markdown
      )
    end

    describe "#flattened_text" do
      it "is the concatenation of every text node" do
        expect(document.flattened_text).to eq("I'm an friend of Tom")
      end
    end

    describe "#flattened_length" do
      it "is the total character count of the flattened text" do
        expect(document.flattened_length).to eq(20)
      end
    end

    describe "#source_range_at" do
      it "returns node A's source range for a flattened offset in node A" do
        expect(document.source_range_at(3)).to eq(node_a.source_range)
      end

      it "returns node B's source range for a flattened offset in node B (the bolded word)" do
        # Flattened offset 10 is inside "friend" (offsets 7..12 in flattened)
        expect(document.source_range_at(10)).to eq(node_b.source_range)
      end

      it "returns nil for out-of-range offsets" do
        expect(document.source_range_at(-1)).to be_nil
        expect(document.source_range_at(100)).to be_nil
      end
    end

    describe "#source_range_for" do
      it "spans multiple nodes when the flattened range crosses a markup boundary" do
        # Flattened offsets 4..13: "an friend" — starts in node A,
        # ends in node B (covers "an **friend**").
        range = document.source_range_for(4, 13)
        expect(range.start).to eq(node_a.source_range.start)
        expect(range.end).to eq(node_b.source_range.end)
        # Length in source = end offset - start offset = 17 - 0 = 17.
        expect(range.length).to eq(17)
      end

      it "returns a single-node range when both offsets are inside the same node" do
        range = document.source_range_for(1, 5)
        expect(range.start).to eq(node_a.source_range.start)
        expect(range.end).to eq(node_a.source_range.end)
      end

      it "defaults the end to flattened_length when nil" do
        range = document.source_range_for(7)
        expect(range.start).to eq(node_b.source_range.start)
        expect(range.end).to eq(node_c.source_range.end)
      end
    end

    describe "#each_node" do
      it "yields every text node in source order" do
        collected = []
        document.each_node { |n| collected << n }
        expect(collected).to eq([node_a, node_b, node_c])
      end

      it "returns an Enumerator when no block given" do
        expect(document.each_node).to be_an(Enumerator)
        expect(document.each_node.to_a).to eq([node_a, node_b, node_c])
      end
    end

    it "rejects empty text_nodes" do
      expect { described_class.new(text_nodes: []) }.to raise_error(ArgumentError, /cannot be empty/)
    end
  end

  # ---- PlainTextDocument ---------------------------------------------

  describe Kotoshu::Documents::PlainTextDocument do
    describe ".from_string" do
      it "wraps the entire string in one text node" do
        doc = described_class.from_string("hello world")
        expect(doc.text_nodes.length).to eq(1)
        expect(doc.flattened_text).to eq("hello world")
      end

      it "computes the source range covering the whole string" do
        doc = described_class.from_string("hello\nworld")
        range = doc.text_nodes.first.source_range
        expect(range.start.offset).to eq(0)
        expect(range.start.line).to eq(1)
        expect(range.end.offset).to eq(11)
        expect(range.end.line).to eq(2) # \n moved us to line 2
      end

      it "carries the language_code through" do
        doc = described_class.from_string("hello", language_code: "en")
        expect(doc.language_code).to eq("en")
      end
    end

    describe ".from_file" do
      let(:tmpdir) { Dir.mktmpdir("kotoshu-doc-spec") }
      after { FileUtils.rm_rf(tmpdir) if File.exist?(tmpdir) }

      it "reads the file and wraps it" do
        path = File.join(tmpdir, "input.txt")
        File.write(path, "file contents")
        doc = described_class.from_file(path)
        expect(doc.flattened_text).to eq("file contents")
      end
    end

    it "is a Document" do
      expect(described_class.new(text_nodes: [
        Kotoshu::Documents::TextNode.new(
          text: "x",
          source_range: Kotoshu::Documents::SourceRange.new(
            start_pos: Kotoshu::Documents::SourcePosition.new(offset: 0, line: 1, column: 1),
            end_pos: Kotoshu::Documents::SourcePosition.new(offset: 1, line: 1, column: 2)
          ),
          flattened_offset: 0
        )
      ])).to be_a(Kotoshu::Documents::Document)
    end
  end

  # ---- Plugin parser registry ----------------------------------------

  describe Kotoshu::Documents do
    let(:stub_parser_class) do
      # A real parser class — no doubles. Returns a PlainTextDocument
      # for simplicity; the registry doesn't validate the return type.
      Class.new do
        def self.from_string(text, language_code: nil)
          Kotoshu::Documents::PlainTextDocument.from_string(text, language_code: language_code)
        end
      end
    end

    after { described_class.reset! }

    describe ".register / .parser_for / .registered_formats" do
      it "registers a parser class under a format symbol" do
        described_class.register(:stub_format, stub_parser_class)
        expect(described_class.parser_for(:stub_format)).to eq(stub_parser_class)
        expect(described_class.registered_formats).to include(:stub_format)
      end

      it "parser_for returns nil for an unregistered format" do
        expect(described_class.parser_for(:nonexistent)).to be_nil
      end

      it "register accepts string format names by coercing to symbol" do
        described_class.register("markdown", stub_parser_class)
        expect(described_class.parser_for(:markdown)).to eq(stub_parser_class)
      end
    end

    describe ".parse" do
      it "uses the registered parser for the requested format" do
        described_class.register(:stub_format, stub_parser_class)
        doc = described_class.parse("hello", format: :stub_format)
        expect(doc).to be_a(Kotoshu::Documents::PlainTextDocument)
        expect(doc.flattened_text).to eq("hello")
      end

      it "falls back to PlainTextDocument when no parser is registered" do
        doc = described_class.parse("hello", format: :nonexistent)
        expect(doc).to be_a(Kotoshu::Documents::PlainTextDocument)
        expect(doc.format).to eq(:plain)
      end

      it "forwards language_code to the parser" do
        described_class.register(:stub_format, stub_parser_class)
        doc = described_class.parse("hello", format: :stub_format, language_code: "en")
        expect(doc.language_code).to eq("en")
      end
    end

    describe ".reset!" do
      it "clears every registration" do
        described_class.register(:stub_format, stub_parser_class)
        described_class.reset!
        expect(described_class.parser_for(:stub_format)).to be_nil
        expect(described_class.registered_formats).to eq([])
      end
    end
  end
end
