# Plan 102 — Language detection end to end: registry mirror, wasm, playground

## Why
The gem detects document language (server /v1/detect) using its own detection
model — but the registry mirrors none of it, the wasm surface has no detect
API, and the playground makes a user pick a language dropdown blind. A
writer pasting text should be told what it is. The FastText LID model is
tiny (~1 MB) and the mirror pattern is proven (v1.2.1+).

## Work
1. Models repo: add the LID model as a registry resource (converted like the
   tiers, int8-quantized if gates hold vs the float32 labels), mirrored with
   ACAO:*; registry v1.4.x alongside plan 101 (coordinate the version).
2. kotoshu-rs: `detect_language(bytes, vocab_bytes) -> {code, score}` on the
   model surface beside loadModel/rerank; wasm export `detectLanguage`;
   tests against the gem's detection outputs on a fixed multilingual corpus.
3. Playground (rides the site follow-up with plans 99/100 flips): on load
   and on demand ("detect" affordance beside the lang select), load the LID
   model (~1 MB, cached like the semantic tier) and set/select the language,
   showing the detected code + confidence. Never auto-switch a user's
   explicit choice silently — propose it.

## Verification
Registry mirror ACAO + size checks; wasm parity vs gem detect on the corpus;
playground verified with multilingual paste (en/de/ru/ja/ar).

## Status
Pending
