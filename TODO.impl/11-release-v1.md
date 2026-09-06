# 11 — Release v1.0

## Goal

Cut a v1.0.0 release of the `kotoshu` gem with everything in plans 01-10
landed (or explicitly descoped), and a published v1.0.0 tag of each
content repo.

## Why

No gem release exists. `git tag` shows nothing on `main`. The gemspec
already references `CHANGELOG.md` which doesn't exist. v1 is the
commitment that the public API is stable and the supported-language
matrix is real.

## Tasks

1. **API freeze audit.** Walk every public method on the `Kotoshu`
   module (`lib/kotoshu.rb`) and the `Configuration` class. Ensure
   every signature is documented, every option is in `SCHEMA`, and the
   YARD docs are complete. After v1, breaking changes require v2.
2. **CHANGELOG.md.** Write the v1.0.0 entry following Keep a Changelog
   format. The gemspec metadata points at this file.
3. **README accuracy pass.** Fix:
   - License (says MIT, actually BSD-2-Clause)
   - ONNX model count (says 6, will be ~30+ at v1)
   - Language matrix (must match `Kotoshu.supported_languages`)
   - CLI examples (every example must work verbatim)
4. **Deprecation policy.** Add `SECURITY.md` (from plan 09) and
   `POLICY.md` documenting semver, supported Ruby versions, EOL
   cadence.
5. **Sign the gem** with a project rubygems.org account. Document
   who has release privileges.
6. **Content repo tags.** Tag each content repo in lockstep:
   - `dictionaries` → `v1.0.0`
   - `frequency-list-kelly` → `v1.0.0`
   - `models-fasttext-onnx` → `v1.0.0`
   Pin the gem's default `resource_sources` URLs to these tags (via
   the manifest system from plan 09).
7. **Release automation.** GitHub Action that, on tag push:
   - Builds the gem
   - Publishes to rubygems.org
   - Creates a GitHub Release with auto-generated notes
8. **Post-release smoke test.** A script that, on a fresh Docker
   container with only Ruby installed:
   - `gem install kotoshu`
   - `ruby -e 'require "kotoshu"; puts Kotoshu.correct?("hello")'`
   - Exercises each documented CLI example from the README
9. **Announcement.** Blog post on kotoshu.github.io (once it exists,
   plan depends on `kotoshu.github.io/TODO.impl/`), Ruby Weekly
   submission, Reddit /r/ruby.

## v1 scope (locked)

In scope:
- Traditional Hunspell path (Latin scripts) — plans 01, 04
- Semantic ONNX reranking — plan 05
- Dynamic download — plan 03
- Integrity verification — plan 09
- Grammar rules (starter pack for the 6 fully-supported languages) —
  plan 08
- CLI with all documented flags — plan 02
- ≥ 30 supported languages with end-to-end coverage

Out of scope (post-v1):
- CJK full support — plan 06 (may ship experimental in v1.1)
- RTL full support — plan 07 (same)
- LSP / HTTP server
- Editor plugins

## Acceptance criteria

- `gem install kotoshu` works on a clean Ruby 3.1+ machine
- `Kotoshu::VERSION == "1.0.0"`
- `git tag v1.0.0` exists on `kotoshu/kotoshu`, `kotoshu/dictionaries`,
  `kotoshu/frequency-list-kelly`, `kotoshu/models-fasttext-onnx`
- The post-release smoke test passes
- rubygems.org page shows the gem with correct metadata
- README's first 100 lines are accurate (no broken examples)

## Dependencies

- Blocked by: all of plans 01-10
- Cross-repo: each content repo's `TODO.impl/03-*-releases.md` (or
  equivalent)

## Out of scope

- v1.1, v2 planning (post-release)
- Marketing beyond the announcement
- Conference talks (delightful but not blocking)

## Status

_Pending._
