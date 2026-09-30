# 6 — The three-API implementation plan

## Ruby (the gem — the canonical engine)

- `lib/kotoshu/grammar/pos_tagger.rb` — the rule-based tagger
- `lib/kotoshu/grammar/pattern_matchers/pos_sequence_matcher.rb`
- `lib/kotoshu/grammar/pattern_matchers/agreement_matcher.rb`
- `lib/kotoshu/grammar/rules/en/*.yml` — the rule data
- `lib/kotoshu/checks/grammar_check.rb` — updated (POS-aware)
- Specs for every rule (FP budget + recall)

## Rust (kotoshu-rs — the fast C-ABI/wasm engine)

- `kotoshu/src/grammar/mod.rs` — the rule evaluation port
- `kotoshu/src/grammar/pos_tagger.rs` — the tagger port
- `kotoshu/src/grammar/rules.rs` — embedded rules (serde_yaml)
- `kotoshu/src/grammar/tests.rs` — port the specs
- The rules are the same YAML — the Rust engine loads and
  evaluates them; both engines produce identical results
  (verified by shared conformance vectors, like the spelling)

## TS (@kotoshu/client — the HTTP API + optional WASM)

- HTTP: the server runs the gem — TS users get grammar checks
  through `POST /check` with `grammar: true` (automatic once the
  server resolves the gem)
- WASM: the grammar rule evaluation runs in the wasm build (the
  rules are data; the POS tagger is portable; the WASM budget is
  comfortable for grammar rules — no large index needed)
- The TS client adds a `grammar` flag to the `check()` method

## Conformance vectors

The grammar conformance vectors use the same pattern as the
spelling vectors: one JSONL line per test case
(input → expected errors → expected suggestions), frozen from the
gem and replayed through the rs engine (rake kotoshu:conformance).
EOF
echo "file 6 written"