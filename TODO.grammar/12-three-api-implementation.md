# 12 — Three-API grammar conformance (Ruby / Rust / TS)

## The rule format is data — all three APIs load the same YAML

```yaml
- id: EN_SV_AGREEMENT_3SG
  category: agreement
  pattern:
    - { pos: PRON_3SG }
    - { pos: VERB_BASE }
  message: "..."
```

## Ruby (the gem — the canonical engine)

✅ Shipped:
- `Grammar::PosTagger` (17-tag, rule-based)
- `Grammar::PatternMatchers::PosSequenceMatcher`
- 20 YAML rules (agreement + word confusion)
- 15 specs

Next:
- The RuleEngine wiring to load from the rules directory
- The GrammarCheck check to run rules end-to-end
- The remaining 130 rules

## Rust (kotoshu-rs — the fast C-ABI/wasm engine)

Port needed:
- `grammar/pos_tagger.rs` (the tagger port — same word lists + suffix
  rules, pure Rust, no dependency)
- `grammar/rule_engine.rs` (the matcher port — same YAML parsing via
  serde_yaml, same pattern evaluation)
- `grammar/rules.rs` (embedded rules or loaded from the same YAML)
- Conformance vectors (like the spelling vectors): input → expected
  errors → expected suggestions

The rules are data: the same YAML loads in both engines. The POS
tagger must produce identical tags (verified by conformance tests).

## TS (@kotoshu/client — HTTP API + optional WASM)

- **HTTP**: the server runs the gem → TS users get grammar checks
  through the existing `POST /check` endpoint with `grammar: true`
- **WASM**: the grammar rule evaluation runs in the wasm build:
  - The rules are small (YAML data, no model needed for rule-based)
  - The POS tagger is portable (word lists + suffix rules)
  - The memory budget is comfortable (no large index, unlike SymSpell)

## Conformance vectors

Same pattern as the spelling vectors: frozen JSONL, replayed through
both engines, identical results required.

```json
{"kind":"grammar","language":"en","input":"He go to school","expected":[{"rule_id":"EN_SV_AGREEMENT_3SG","start":1,"end":1}]}
```

## The pipeline

1. Ruby: the rules work end-to-end (through GrammarCheck) ← we are here
2. Rust: the conformance vectors exist, both engines replay them
3. TS: the HTTP server carries grammar, the WASM build carries rules
