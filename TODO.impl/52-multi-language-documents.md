# 52 — Multi-language document checking (T3.5)

## Goal

Right now `Kotoshu.check_file` and `Kotoshu::Spellchecker` are
single-language. Real documents mix languages: code comments in
English embedded in French prose, a Japanese paper with English
abstract, etc. This TODO adds per-paragraph language detection and
per-language resolution so a single document is checked with the
right dictionary + rules for each segment.

## Design

### Layer 1: Per-segment detection

`Kotoshu::Language::Identifier` (FastText LID) already exists. Wire
it into a `DocumentSegmenter` that splits a `Kotoshu::Documents::Document`
into language-tagged segments.

    class Kotoshu::Language::Segmenter
      # @param document [Documents::Document]
      # @param threshold [Float] detection confidence threshold (default 0.7)
      # @return [Array<Segment>] language-tagged segments
      def segment(document, threshold: 0.7)
        # Walk document.text_nodes.
        # Group consecutive nodes by detected language.
        # Detect per node (or per paragraph break).
      end
    end

    class Kotoshu::Language::Segment
      # @param language_code [String]
      # @param text_nodes [Array<Documents::TextNode>]
      # @param confidence [Float]
    end

### Layer 2: Per-segment resource resolution

For each segment, resolve the right dictionary + rules via the
existing two-stage `ResourceManager`:

    Kotoshu::ResourceManager.resolve(language: segment.language_code, want: %i[spelling grammar])

### Layer 3: Multi-language check pipeline

    class Kotoshu::MultiLanguageChecker
      def check(document)
        segments = segmenter.segment(document)
        segments.flat_map do |segment|
          bundle = ResourceManager.resolve(language: segment.language_code)
          spellchecker = Spellchecker.new(resource_bundle: bundle)
          segment.text_nodes.flat_map { |node|
            spellchecker.check_text(node.text)
          }
        end
      end
    end

### Layer 4: Result aggregation

Errors carry `source_range` from TODO 50. Per-segment errors already
have positions; aggregation is just a concatenation sorted by
source_range.start.

## Phases

### Phase 1 — Segmenter (this PR series)
- `Language::Segmenter` with paragraph-level detection.
- Specs with mixed-language fixtures (en + de, en + ja).

### Phase 2 — MultiLanguageChecker (this PR series)
- Composes segmenter + spellchecker.
- Carries `source_range` through.

### Phase 3 — CLI integration
- `kotoshu check --language auto FILE` picks the multi-language path.
- Default for `auto` becomes multi-language; single-language mode is
  opt-in via `--language en`.

## Acceptance criteria

- [ ] A document with English prose and French quotes is checked with
      both dictionaries, errors from both languages surface in the
      output with correct source positions.
- [ ] A document with English code comments and Japanese prose is
      checked with the right language per segment.
- [ ] Performance: < 2x the single-language cost for typical mixed
      documents.
- [ ] Full suite stays green.

## Dependencies

- **Blocked by:** TODO 50 (document API with source positions).
- **Blocks:** T3.4 document plugin architecture (plugins want
  multi-language support to come for free).
