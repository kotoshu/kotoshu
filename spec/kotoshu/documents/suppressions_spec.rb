# frozen_string_literal: true

require "spec_helper"

# Inline ignore directives (TODO.impl/82 Track A): the shared scanner,
# the Suppression value object, and their attachment to Documents.
RSpec.describe Kotoshu::Documents::Suppressions do
  describe ".scan" do
    it "returns a frozen empty list for empty and nil sources" do
      expect(described_class.scan("", format: :markdown)).to eq([])
      expect(described_class.scan(nil)).to eq([])
    end

    context "with plain text" do
      it "recognizes a bare disable-line" do
        source = "first line\nkotoshu:disable-line\nthird line\n"
        suppressions = described_class.scan(source, format: :plain)

        expect(suppressions.length).to eq(1)
        expect(suppressions.first.kind).to eq(:line)
        expect(suppressions.first.covers_line?(2)).to be(true)
        expect(suppressions.first.covers_line?(1)).to be(false)
        expect(suppressions.first.covers_line?(3)).to be(false)
      end

      it "does not treat trailing directive text as a directive" do
        source = "some prose kotoshu:disable-line here\n"
        expect(described_class.scan(source, format: :plain)).to eq([])
      end

      it "recognizes a bare disable-next-line with a word list" do
        source = "kotoshu:disable-next-line foo bar\nwrld helo\n"
        suppressions = described_class.scan(source, format: :plain)

        expect(suppressions.length).to eq(1)
        expect(suppressions.first.kind).to eq(:next_line)
        expect(suppressions.first.words).to eq(%w[foo bar])
        expect(suppressions.first.covers_line?(2)).to be(true)
      end

      it "ignores prose that merely mentions a directive" do
        source = "you could write kotoshu:disable-line but please do not\n"
        expect(described_class.scan(source, format: :plain)).to eq([])
      end
    end

    context "with markdown" do
      it "recognizes a whole-line HTML comment directive" do
        source = "<!-- kotoshu:disable-next-line -->\nwrld hello\n"
        suppressions = described_class.scan(source, format: :markdown)

        expect(suppressions.length).to eq(1)
        expect(suppressions.first.kind).to eq(:next_line)
        expect(suppressions.first.applies_to?(2, word: "wrld")).to be(true)
      end

      it "recognizes a trailing HTML comment directive" do
        source = "wrld hello <!-- kotoshu:disable-line -->\n"
        suppressions = described_class.scan(source, format: :markdown)

        expect(suppressions.length).to eq(1)
        expect(suppressions.first.kind).to eq(:line)
        expect(suppressions.first.directive_line).to eq(1)
      end

      it "keeps the directive comment itself out of scope as prose" do
        source = "<!-- kotoshu:disable-next-line -->\nwrld\n"
        suppression = described_class.scan(source, format: :markdown).first

        # The directive line is suppressed for any word - the directive
        # text is an instruction, not prose to check.
        expect(suppression.applies_to?(1, word: "anything")).to be(true)
      end
    end

    context "with asciidoc" do
      it "recognizes a whole-line // directive" do
        source = "// kotoshu:disable-line\nwrld hello\n"
        suppressions = described_class.scan(source, format: :asciidoc)

        expect(suppressions.length).to eq(1)
        expect(suppressions.first.kind).to eq(:line)
        expect(suppressions.first.covers_line?(1)).to be(true)
      end

      it "recognizes a trailing // directive" do
        source = "wrld hello // kotoshu:disable-line\n"
        suppressions = described_class.scan(source, format: :asciidoc)

        expect(suppressions.length).to eq(1)
        expect(suppressions.first.directive_line).to eq(1)
      end

      it "does not treat URLs as line comments" do
        source = "see https://example.com/wrld for details\n"
        expect(described_class.scan(source, format: :asciidoc)).to eq([])
      end
    end

    context "with the :auto profile" do
      it "recognizes bare, HTML-comment, and // directives at once" do
        bare = "kotoshu:disable-line\n"
        html = "<!-- kotoshu:disable-line -->\n"
        adoc = "// kotoshu:disable-line\n"

        [bare, html, adoc].each do |line|
          expect(described_class.scan(line, format: :auto).length).to eq(1)
        end
      end
    end

    context "with file blocks" do
      it "suppresses from disable-file to the matching enable-file" do
        source = +"one\n"
        source << "kotoshu:disable-file\n"
        source << "three\n"
        source << "kotoshu:enable-file\n"
        source << "five\n"
        suppressions = described_class.scan(source, format: :plain)

        expect(suppressions.length).to eq(1)
        block = suppressions.first
        expect(block).to be_file_block
        expect(block.covers_line?(2)).to be(true)
        expect(block.covers_line?(3)).to be(true)
        # the enable-file line itself belongs to the block
        expect(block.covers_line?(4)).to be(true)
        expect(block.covers_line?(5)).to be(false)
      end

      it "runs to EOF when never re-enabled" do
        source = "one\nkotoshu:disable-file\nthree\nfour\n"
        block = described_class.scan(source, format: :plain).first

        expect(block).to be_file_block
        expect(block.covers_line?(4)).to be(true)
      end

      it "supports nested blocks: inner enable only closes the inner block" do
        source = +"one\n"
        source << "kotoshu:disable-file\n"       # line 2 - outer
        source << "three\n"
        source << "kotoshu:disable-file\n"       # line 4 - inner
        source << "five\n"
        source << "kotoshu:enable-file\n"        # line 6 - closes inner
        source << "seven\n"
        source << "kotoshu:enable-file\n"        # line 8 - closes outer
        source << "nine\n"
        blocks = described_class.scan(source, format: :plain).sort_by(&:start_line)

        expect(blocks.length).to eq(2)
        expect(blocks.map(&:start_line)).to eq([2, 4])
        expect(blocks[1].end_line).to eq(6)   # inner: lines 4-6
        expect(blocks[0].end_line).to eq(8)   # outer: lines 2-8
        expect(blocks[0].covers_line?(8)).to be(true)
        expect(blocks[0].covers_line?(9)).to be(false)
      end

      it "ignores a stray enable-file" do
        source = "one\nkotoshu:enable-file\nthree\n"
        expect(described_class.scan(source, format: :plain)).to eq([])
      end
    end

    it "ignores unknown and malformed directives" do
      [
        "kotoshu:disable-everything\n",
        "kotoshudisable-line\n",
        "kotoshu: disable-line\n"
      ].each do |line|
        expect(described_class.scan(line, format: :plain)).to eq([])
      end
    end
  end

  describe Kotoshu::Documents::Suppressions::Suppression do
    it "rejects unknown kinds and invalid line ranges" do
      expect do
        described_class.new(kind: :bogus, directive_line: 1, start_line: 1, end_line: 1)
      end.to raise_error(ArgumentError, /unknown kind/)

      expect do
        described_class.new(kind: :line, directive_line: 1, start_line: 3, end_line: 2)
      end.to raise_error(ArgumentError, /end_line must cover/)
    end

    it "downcases and freezes its word list" do
      suppression = described_class.new(
        kind: :next_line, directive_line: 1, start_line: 2, end_line: 2,
        words: %w[Foo BAR]
      )

      expect(suppression.words).to eq(%w[foo bar])
      expect(suppression.words).to be_frozen
      expect(suppression).to be_word_scoped
    end

    it "matches words case-insensitively" do
      suppression = described_class.new(
        kind: :next_line, directive_line: 1, start_line: 2, end_line: 2,
        words: %w[wrld]
      )

      expect(suppression.applies_to?(2, word: "WRLD")).to be(true)
      expect(suppression.applies_to?(2, word: "helo")).to be(false)
      expect(suppression.applies_to?(3, word: "wrld")).to be(false)
    end
  end

  describe "attachment to documents" do
    it "PlainTextDocument scans bare directives for :plain" do
      document = Kotoshu::Documents::PlainTextDocument.from_string(
        "one\nkotoshu:disable-line\nthree\n"
      )

      expect(document.suppressions.length).to eq(1)
      expect(document.suppressions.first.kind).to eq(:line)
      expect(document.suppressed?(2, word: "wrld")).to be(true)
      expect(document.suppressed?(3, word: "wrld")).to be(false)
    end

    it "lets the caller supply suppressions explicitly" do
      suppression = Kotoshu::Documents::Suppressions::Suppression.new(
        kind: :file, directive_line: 1, start_line: 1, end_line: 10
      )
      document = Kotoshu::Documents::PlainTextDocument.from_string(
        "clean text\n", suppressions: [suppression]
      )

      expect(document.suppressions).to eq([suppression])
      expect(document.suppressed?(5, word: "wrld")).to be(true)
    end

    it "scans an explicit :markdown document with comment syntax" do
      document = Kotoshu::Documents::Document.new(
        text_nodes: [Kotoshu::Documents::TextNode.new(
          text: "wrld\n", source_range: Kotoshu::Documents::SourceRange.new(
            start_pos: Kotoshu::Documents::SourcePosition.new(offset: 0, line: 1, column: 1),
            end_pos: Kotoshu::Documents::SourcePosition.new(offset: 5, line: 2, column: 1)
          ),
          flattened_offset: 0
        )],
        source: "<!-- kotoshu:disable-next-line -->\nwrld\n",
        format: :markdown
      )

      expect(document.suppressed?(2, word: "wrld")).to be(true)
      # the directive comment line is never spellchecked
      expect(document.suppressed?(1, word: "anything")).to be(true)
    end
  end

  describe Kotoshu::Documents::SourcePosition, ".line_for_offset" do
    it "maps flat offsets to 1-based lines" do
      text = "one\ntwo\nthree\n"

      expect(described_class.line_for_offset(text, 0)).to eq(1)
      expect(described_class.line_for_offset(text, 4)).to eq(2)
      expect(described_class.line_for_offset(text, 8)).to eq(3)
    end

    it "clamps nil and out-of-range offsets" do
      text = "one\ntwo\n"

      expect(described_class.line_for_offset(text, nil)).to eq(1)
      expect(described_class.line_for_offset(text, 999)).to eq(2)
    end
  end
end
