# The ecosystem release map

How every channel cuts. Version numbers are always the owner's call;
everything here is the mechanical flow once the number is chosen.

## kotoshu (the gem)

`release.yml` is workflow-dispatched with `next_version`:

```
gh workflow run release.yml -R kotoshu/kotoshu --ref main -f next_version=X.Y.Z
```

The workflow bumps `lib/kotoshu/version.rb`, tags `vX.Y.Z`, publishes
the pure-Ruby gem, builds the five native platform gems from the TAG
(each leg pushes through the same trusted publishing), then the verify
job asserts all six RubyGems artifacts AND installs the shipped gem to
assert the native surface (`TypoModel`/`TypoTier`/`TypoEngine` +
`TypoEngine.matrix`).

After a cut: rebuild the docker image (`docker-kotoshu-ci` `ci.yml`,
workflow_dispatch), update the site install page + news entry.

The ext pins kotoshu-rs main by rev in `Cargo.lock`. After EVERY rs
merge: `bundle exec rake ext:update`, commit the refreshed lock
through a PR. The weekly `ext-pin-drift.yml` catches lapses; the
release surface guard catches one that slipped through.

## kotoshu (the crate)

Version bump PR → tag `kotoshu-vX.Y.Z` → `release-crate.yml` publishes
via crates.io trusted publishing.

## @kotoshu/wasm

Only when the wasm surface changes: tag `@kotoshu/wasm-vX.Y.Z` →
`release-npm.yml` (npm OIDC; node 24 needed for keyless).

## kotoshu-lsp / kotoshu-server

`release.yml` workflow_dispatched with `next_version` (rubygems
trusted publishing, same shape as the gem's).

## kotoshu-native (PyPI wheels)

Tag `kotoshu-native-vX.Y.Z` → `release-pypi.yml` (keyless ONCE the
owner registers the trusted publisher on pypi.org: owner `kotoshu`,
repo `kotoshu-rs`, workflow `release-pypi.yml`, environment empty).
Before that registration: the stored `~/.pypirc` token + twine over
the CI-built artifacts.

## The model registry

See `models-fasttext-onnx/docs/RELEASING.md` (the standard cut plus
the typo promotion steps). Mirror-only additions (e.g. new KTM1
matrices) serve from main without a cut; `paired_vocab_sha256` cross-
checks at generation. The validator's `--check-urls --urls-ref` gate
must pass on the branch that adds artifacts.

## The site

`kotoshu.github.io` is direct-main by convention. News entries carry
verified dates (registry timestamps, tag dates — never inferred).

## Client SDKs (py / js / go)

`kotoshu-py`: `release.yml` tag-triggered (same publisher
registration story, repo `kotoshu-py`, workflow `release.yml`).
`kotoshu-js` (@kotoshu/client): npm publish is owner-published.
`kotoshu-go`: a `vX.Y.Z` tag is the release (module proxy).

## Invariants worth remembering

- Platform gems build from the tag, never pre-bump main.
- Nothing counts as released until its verify job says so — counts
  prove nothing, surfaces do (the 1.0.4 lesson).
- The dictionaries repo's default branch is `v1`, not main. Every URL
  the library builds points at a live ref (plan 145).
