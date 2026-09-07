# Plan 99 — Site truth pass + measured performance documentation

## Why
The docs were written against the versions live at the time; three releases
later some pages misstate reality. Users deserve the measured numbers the
perf work produced — no spellchecker site publishes per-language sweep
latency; we have it, verified, for eight languages.

## Work (site repo)
1. `/docs/performance` (new page): the measured tables — whole-text check
   latency (1-33 ms per 100 words), per-sweep averages post-0.3.2
   (en 45 ms ... pt 423 ms, fr worst-case note), tier sizes (full/fluency/mini),
   and tuning: personal dictionaries, baselines, tier choice guidance
   (`--tier`), backend choice (ruby vs native vs wasm). Link from the
   playground footnote, /languages, and /install.
2. Truth pass: /docs/clients/action still says the action "installs the gem
   from RubyGems where 0.7.0 gates six languages" — stale; the action now
   rides 0.9.2 (20 full-feature languages, baselines, directory mode).
   Audit every page for version references (0.7.0/0.8.0/0.1.1/wasm 0.2.0)
   and flip to current-with-dates. /playground/server: verify the hosted
   demo state and the run-your-own instructions.
3. Footer/readout: confirm every registry badge resolves (RubyGems 0.9.2,
   npm 0.3.2, PyPI, crates.io).

## Verification
Rendered text extraction on the built site for stale version strings;
every measured number in /docs/performance traceable to the 0.3.2 bench
harness (kotoshu-rs PR #23 table) — no inferred numbers.

## Status
Pending
