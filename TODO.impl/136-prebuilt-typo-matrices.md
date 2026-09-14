# Plan 136 — Prebuilt typo matrices: arming as a download

Status: executed (2026-09-14; models PR #39, rs PR, gem PR — see below)

The v1.7.0 train's improvement backlog named first-arming time
(~25 s derivation) as the last user-visible cost of the typo layer.
The matrix ships as a KTM1 artifact (magic, version, count, dims,
int8 rows, f32 scales — index-parallel to the language's full-tier
vocabulary), derived once by `kotoshu-rs examples/matrix_export`.

## Shipped

- models: `models/en/typo.matrix.en.ktm1` (100k x 256 = 26.0 MB) +
  descriptor + `kotoshu://models/en/typo-matrix` (mirror-only, the
  additive template; validator branch + schema widened; the
  typo-biencoder pair now pins to its own semver tag).
- rs: `TypoIndex::write_rows` / `parse_ktm1` (fully validated),
  `TypoEngine::from_matrix`, the `matrix_export` example, the Ruby
  binding `Kotoshu::Native::TypoEngine.matrix(model, tier, path)`.
  Round-trip test: artifact slates identical to the derived index.
- gem: `ModelCache#{load_cached,download}_typo_matrix` (sha-verified
  resolve; setup fetch is best-effort — a language without a matrix
  arms by deriving), `Engine.for` prefers the cached matrix.

## Measured

- Arming: ~25 s derivation -> 25 ms artifact load (1000x).
- Suggest: unchanged (2 ms); `recieve -> receive` in the slate.
- The artifact round-trip is frozen by tests on both sides of the
  boundary; derive-at-load remains the universal fallback.
