# 07 — RTL Script Support (Arabic, Hebrew, Persian, Urdu)

## Goal

Right-to-left scripts work end-to-end with correct shaping, normalization,
and bidirectional handling.

## Why

ROADMAP plan `007-rtl-languages.md` is 🔲 Not Started. The
`dictionaries` repo has `ar`, `he`, `fa` (likely; verify) dirs.
Hunspell handles RTL fine in principle, but Ruby's default string
handling needs explicit care.

## Tasks

1. **Verify dictionary coverage** in the `dictionaries` repo for `ar`,
   `he`, `fa`, `ur`. If any are missing, file under
   `dictionaries/TODO.impl/02-coverage-matrix.md`.
2. **Unicode normalization.** Arabic especially has presentation forms
   (U+FExx range) that must be normalized to canonical forms (U+06xx)
   before lookup. Add a `RtlNormalizer` under
   `lib/kotoshu/language/normalizer/`.
3. **Bidi handling in output.** When SARIF/text output contains mixed
   RTL/LTR (e.g. error message in English pointing at Arabic text),
   apply explicit Unicode bidi marks (LRM/RLM) so terminal and editor
   render correctly. Verify the `DisplayFormatter` handles this.
4. **Tokenizer.** Arabic/Hebrew script tokenizers differ from Latin
   (clitics, the definite article "ال"). Add
   `ArabicTokenizer`/`HebrewTokenizer` under
   `lib/kotoshu/language/tokenizer/`.
5. **Keyboard layouts.** Add Arabic (101/102), Hebrew standard. Map to
   the existing `KeyboardProximityStrategy`.
6. **FastText models.** All four languages have upstream FastText
   crawl vectors. Verify they're in `models-fasttext-onnx` (the local
   repo has 158 models; spot-check ar/he/fa/ur are present).
7. **Grammar rules (light).** Common confusions: Arabic alif variants
   (ا/أ/إ/آ), Hebrew similar-final letter pairs (כ/ך, מ/ם). Ship as
   `dictionaries/{code}/grammar/confusion.yaml`.
8. **Kelly frequency.** Arabic has Kelly data; verify Hebrew/Persian/Urdu
   coverage in `frequency-list-kelly` and file extension tasks if
   missing.
9. **Regression tests.** Each RTL language gets a spec with a known
   error and assertion that the suggestion is in the correct script
   and the position offset is correct in codepoints.

## Acceptance criteria

- `Kotoshu.check("السلام عليكم")` (correct) → no errors
- `Kotoshu.check("السلم عليكم")` (missing alif) → flagged with
  suggestion "السلام"
- SARIF output for an RTL error renders correctly on GitHub
- Terminal output doesn't corrupt cursor position from bidi reordering

## Dependencies

- Blocks: nothing
- Blocked by: `03-dynamic-download`, `04-language-modules`
- Cross-repo: `dictionaries/TODO.impl/02-coverage-matrix.md`,
  `frequency-list-kelly/TODO.impl/01-extend-coverage.md`,
  `models-fasttext-onnx/TODO.impl/01-publish-all-models.md`

## Out of scope

- Diacritics-only checking (tashkeel) for Arabic — future
- Ligature-aware suggestions
- Calligraphy-style variants

## Status

_Pending._
