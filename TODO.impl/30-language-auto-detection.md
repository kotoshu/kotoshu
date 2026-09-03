# 30 — Default `--language auto` for `kotoshu check` (T2, 0.3-blocker)

## Status
Implemented (shipped in the 0.3 line; re-verified 2026-09-03 against 0.6.0).

Evidence:

- `lib/kotoshu/cli/language_resolver.rb` implements the exact flag
  matrix from this plan: omitted/`auto` → detect with fallback;
  `default` → `Configuration.default_language`; any code → as-is.
  A detection only "sticks" if the language is set up
  (`Kotoshu.setup?`), otherwise the default is used and the result
  carries the note `Detected: X (fallback: en)` — printed to stderr by
  `cli.rb#resolve_language` (`warn "# #{result.note}"`).
- `--language` defaults to `auto` on the wired CLI check
  (`lib/kotoshu/cli.rb:86`).
- `Kotoshu.detect_language` exists on the facade (`lib/kotoshu.rb:436`).
- Specs: `spec/kotoshu/cli/language_resolver_spec.rb` (run 2026-09-03,
  0 failures) and `spec/kotoshu/language/detector_spec.rb`
  (20 examples, 0 failures, 1 pending).

Deviations from the plan text:

- Option A (bundled FastText LID model) was NOT taken — CLI auto mode
  uses character-set heuristics (`Kotoshu::Language.detect`), which
  need no model download. The FastText LID (`Language::Identifier`)
  remains a separate surface.
- The Arabic LID gap from plan 36 still stands: the Arabic example in
  `spec/kotoshu/language/detector_spec.rb` is `pending "FastText LID
  missing Arabic vector — see TODO.impl/30-language-auto-detection.md"`
  (still failing if un-pended, hence pending).

## Problem
Today `kotoshu check file.txt` with no `--language` flag — behavior is
undefined. Likely uses `Configuration.default_language` ("en") silently,
which is wrong for non-English content.

Auto-detection (`Language::Identifier` via FastText LID) exists, but using
it as the default would surprise users with another model download.

## Plan

### Default behavior matrix
| `--language` value | Behavior |
|---|---|
| (omitted) | `auto` (see below) |
| `auto` | Run LID on first N tokens; use detected language |
| `en`, `de`, etc. | Use specified |
| `default` | Use `Configuration.default_language` (configurable, default "en") |

### `auto` resolution algorithm
1. Read first 1 KB of input.
2. Run `Kotoshu::Language::Identifier.detect(text)`.
3. If detected language is set up (`Kotoshu.setup?(lang)`), use it.
4. Else fall back to `Configuration.default_language`.
5. Emit a one-line note to stderr: `# Detected: de (fallback: en)`.

### LID model handling
LID uses a FastText LID model. Where does it come from?
- **Option A:** ship a tiny bundled model (~1 MB, 127-lang LID is small).
- **Option B:** download on first `auto` use (with prompt per TODO #24).

Recommend Option A — bundle the model. It's small and foundational.

## Acceptance

- [ ] `kotoshu check file.txt` (no flag) auto-detects.
- [ ] `--language en` skips detection, uses en.
- [ ] `--language default` uses default_language.
- [ ] Detection prints a one-line note to stderr.
- [ ] Falls back gracefully when detected language isn't set up.

## Dependencies
- #24 (auto-setup prompt) — to handle "detected language not set up".
