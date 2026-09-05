# 86 — Site truth wave 2: ignores, Windows, playground breadth

## Context

Wave 1 shipped features the site does not document yet, and one docs
bug: the CLI page claims the personal dictionary lives at
`~/.config/kotoshu/personal_dictionary` — the gem actually uses
`personal.dic` (Paths.personal_dictionary_path, KOTOSHU_PERSONAL_DIC
override). Wrong paths in docs are worse than no docs.

## Phases

1. **CLI docs fixes + ignoring & baselines guide**: correct the
   personal-dictionary path everywhere it appears; new docs page
   covering `kotoshu:disable-line` / `-next-line [WORDS]` /
   `-file` blocks per format, `kotoshu baseline init` + `check
   --baseline` semantics (count budgets, stale entries, SARIF
   suppression marking), and the pre-commit hook — matching gem PR
   #118 exactly (read its README sections + specs as the source of
   truth, not this plan).
2. **Windows page**: the CI matrix now runs 3.3/3.4/4.0 on
   windows-latest green — document first-class Windows support:
   `gem install kotoshu` on Windows, onnxruntime soft-dep behavior,
   path handling, and the native extension's Windows status (it is
   NOT built in CI — pending; say so honestly). Link from /install.
3. **Playground breadth**: offer every language whose dictionary the
   CDN can serve well — at minimum the 22 model languages plus the
   staged-dictionary set with sane sizes (cap the list at languages
   whose .aff+.dic < ~5 MB on the CDN; largest dictionaries get a
   size note). Dictionary-only behavior unchanged until plan 85
   ships.
4. **Matrix flip** (sequences on plan 84): when the gem modules land,
   FULL_LANGUAGES grows per the merged module list; the "staged +
   model" note shrinks. If 84 has not merged when you reach this
   phase, skip it and note it — do not block the other phases.

## Constraints

House rules: verify against the gem source (paths, flags), run the
build, CDP-check the playground still works after the language list
change. No new dependencies.

## Status

**Pending.**
