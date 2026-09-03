# 76 — Optional External LLM Backend (adopt-later C5)

From [68-sota-adoption.md](68-sota-adoption.md) item C5 and its
rejection note: LLMs never become the default engine (violates small/
offline/CPU), but an explicit opt-in "heavy" backend can exist for
users who want maximum fluency polishing and accept the cost.

## Goal

A `Kotoshu::Backends::Llm` adapter behind the same interfaces the
engine already exposes (checker/reranker seams), delegating
sentence-level polishing to a local (1–8B via ONNX Runtime GenAI /
llama.cpp) or API model. Default OFF; absent config = today's behavior
exactly.

## Design constraints

1. Adapter pattern, no engine changes: register like any plugin;
   capability flags mark it slow/networked so callers can decline.
2. Two transports: local GGUF/ORT-GenAI (user-supplied model path) and
   HTTP API (user-supplied endpoint + key via env). No keys in code,
   no telemetry.
3. Interactive surfaces (LSP, CLI `--interactive`) surface a visible
   "heavy mode" indicator; CI surfaces refuse it by default.
4. Output contract: same suggestion objects; LLM refinements only
   applied on explicit accept in interactive mode.

## Acceptance

- Engine untouched with backend disabled (existing suite proves it);
  adapter specs use a stub server (no real API in tests); docs state
  latency/memory expectations honestly.

## Status

_Planning — gated_ on user demand. Not scheduled until someone asks
for it.
