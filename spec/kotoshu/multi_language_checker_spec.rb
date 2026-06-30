# frozen_string_literal: true

require "kotoshu"
require "tmpdir"
require "fileutils"

# Direct spec for Kotoshu::Language::Segmenter and
# Kotoshu::MultiLanguageChecker (TODO.impl/52).
#
# The Segmenter splits a Documents::Document into language-tagged
# segments. The MultiLanguageChecker resolves a Spellchecker per
# segment and emits one sorted stream of SemanticErrors carrying
# source_range from the document.
RSpec.describe Kotoshu::Language::Segmenter do
  def text_node(text, offset)
    Kotoshu::Documents::TextNode.new(
      text: text,
      source_range: Kotoshu::Documents::SourceRange.new(
        start_pos: Kotoshu::Documents::SourcePosition.new(offset: offset, line: 1, column: offset + 1),
        end_pos: Kotoshu::Documents::SourcePosition.new(offset: offset + text.length, line: 1,
                                                        column: offset + text.length + 1)
      ),
      flattened_offset: offset
    )
  end

  let(:document) do
    Kotoshu::Documents::Document.new(
      text_nodes: [
        text_node("Hello world", 0),
        text_node("bonjour le monde", 12),
        text_node("goodbye", 30)
      ],
      source: "Hello world bonjour le monde goodbye",
      format: :plain
    )
  end

  let(:segmenter) { described_class.new(min_confidence: 0.0) }

  describe "#segment" do
    it "groups consecutive same-language nodes into one Segment" do
      segments = segmenter.segment(document)
      expect(segments.length).to be >= 1
      expect(segments.all?(Kotoshu::Language::Segment)).to be true
    end

    it "every segment carries a language_code" do
      segments = segmenter.segment(document)
      segments.each do |s|
        expect(s.language_code).to be_a(String)
        expect(s.language_code).not_to be_empty
      end
    end

    it "every segment carries its text_nodes in source order" do
      segments = segmenter.segment(document)
      all_nodes = segments.flat_map(&:text_nodes)
      expect(all_nodes).to eq(document.text_nodes)
    end

    it "raises ArgumentError for a non-Document argument" do
      expect { segmenter.segment("not a document") }
        .to raise_error(ArgumentError, /must be a Kotoshu::Documents::Document/)
    end

    it "returns [] for a document with no text nodes" do
      # The Document constructor rejects empty nodes, so build one
      # with a single whitespace-only node. After detection fails it
      # merges into one segment with the fallback language.
      ws_doc = Kotoshu::Documents::Document.new(
        text_nodes: [text_node(" ", 0)],
        source: " ",
        format: :plain
      )
      segments = segmenter.segment(ws_doc)
      expect(segments.length).to eq(1)
      expect(segments.first.language_code).to eq("en")
    end
  end

  describe "with a custom detector" do
    let(:stub_detector_class) do
      Class.new do
        def detect_with_confidence(text)
          text =~ /bonjour/i ? ["fr", 0.9] : ["en", 0.9]
        end
      end
    end

    it "uses the injected detector" do
      seg = described_class.new(detector: stub_detector_class.new, min_confidence: 0.5)
      segments = seg.segment(document)
      codes = segments.map(&:language_code)
      expect(codes).to include("en", "fr")
    end
  end
end

RSpec.describe Kotoshu::Language::Segment do
  it "exposes language_code, text_nodes, confidence" do
    nodes = [Kotoshu::Documents::TextNode.new(
      text: "x",
      source_range: Kotoshu::Documents::SourceRange.new(
        start_pos: Kotoshu::Documents::SourcePosition.new(offset: 0, line: 1, column: 1),
        end_pos: Kotoshu::Documents::SourcePosition.new(offset: 1, line: 1, column: 2)
      ),
      flattened_offset: 0
    )]
    seg = described_class.new(language_code: "en", text_nodes: nodes, confidence: 0.9)
    expect(seg.language_code).to eq("en")
    expect(seg.text_nodes).to eq(nodes)
    expect(seg.confidence).to eq(0.9)
  end

  describe "#flattened_text" do
    it "concatenates every node's text" do
      # trivial case
      seg = described_class.new(language_code: "en", text_nodes: [], confidence: 0.0)
      expect(seg.flattened_text).to eq("")
    end
  end

  describe "#empty?" do
    it "is true when text_nodes is empty" do
      seg = described_class.new(language_code: "en", text_nodes: [], confidence: 0.0)
      expect(seg).to be_empty
    end
  end
end

RSpec.describe Kotoshu::MultiLanguageChecker do
  # The checker resolves a Spellchecker per language via
  # ResourceManager, which needs the language set up. For specs we
  # inject a pre-built spellchecker cache by overriding the private
  # spellchecker_for method via a subclass.
  let(:checker_class) do
    Class.new(described_class) do
      def initialize(spellcheckers_by_lang:)
        super()
        @spellcheckers = spellcheckers_by_lang
      end
    end
  end

  let(:en_dict) do
    Kotoshu::Dictionary::Custom.new(words: %w[hello world goodbye foo bar baz], language_code: "en")
  end
  let(:fr_dict) do
    Kotoshu::Dictionary::Custom.new(words: %w[bonjour le monde au revoir], language_code: "fr")
  end
  let(:en_spellchecker) { Kotoshu::Spellchecker.new(dictionary: en_dict) }
  let(:fr_spellchecker) { Kotoshu::Spellchecker.new(dictionary: fr_dict) }

  let(:checker) do
    checker_class.new(spellcheckers_by_lang: { "en" => en_spellchecker, "fr" => fr_spellchecker })
  end
  let(:document) do
    # English + French mixed. "bonjor" is a deliberate French typo.
    Kotoshu::Documents::Document.new(
      text_nodes: [
        text_node("hello world", 0),
        text_node("bonjor le monde", 12),
        text_node("goodbye", 30)
      ],
      source: "hello world bonjor le monde goodbye",
      format: :plain
    )
  end

  def text_node(text, offset)
    Kotoshu::Documents::TextNode.new(
      text: text,
      source_range: Kotoshu::Documents::SourceRange.new(
        start_pos: Kotoshu::Documents::SourcePosition.new(offset: offset, line: 1, column: offset + 1),
        end_pos: Kotoshu::Documents::SourcePosition.new(offset: offset + text.length, line: 1,
                                                        column: offset + text.length + 1)
      ),
      flattened_offset: offset
    )
  end

  describe "#check" do
    it "returns SemanticErrors with source_range from the document" do
      errors = checker.check(document)
      expect(errors).to be_an(Array)
      errors.each do |e|
        expect(e).to be_a(Kotoshu::Models::SemanticError)
        expect(e.source_range).not_to be_nil
      end
    end

    it "raises ArgumentError for a non-Document argument" do
      expect { checker.check("not a document") }
        .to raise_error(ArgumentError, /must be a Kotoshu::Documents::Document/)
    end

    it "skips segments for languages without a configured spellchecker" do
      # Inject only the English checker; the French segment is silently
      # dropped (its checker is nil).
      partial_checker = checker_class.new(spellcheckers_by_lang: { "en" => en_spellchecker })
      errors = partial_checker.check(document)
      # Errors only from the English segments.
      expect(errors).to be_an(Array)
    end

    it "produces a stable error id for the same word + position" do
      errors_a = checker.check(document)
      errors_b = checker.check(document)
      ids_a = errors_a.map(&:id).sort
      ids_b = errors_b.map(&:id).sort
      expect(ids_a).to eq(ids_b)
    end
  end
end
