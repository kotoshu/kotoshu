# 80 — Ecosystem docs: every channel documented

## Context

The site documents the gem well (cli, caching, configuration, api,
comparison, migration, plugins). But the ecosystem now ships on
eight channels, and a Python/JS/Go/Rust user arriving at
kotoshu.org finds no path in. Audience: non-Ruby developers —
exactly who the access libraries (plan 67) were built for.

## Channels to document (verified live 2026-09-05)

| Channel | Package | What a user needs |
|---|---|---|
| PyPI | `kotoshu`, `kotoshu-native` | pip install, Python API, maturin wheel note |
| npm | `@kotoshu/client`, `@kotoshu/wasm` | npm install, JS API, browser/Node |
| crates.io | `kotoshu` | cargo add, Rust API, KOSH-v1 batch format |
| Go | `kotoshu-go` | go get, HTTP-mode usage |
| RubyGems | `kotoshu` | already documented (link) |
| HTTP | `kotoshu-server` | /v1/check contract, docker run |
| LSP | `kotoshu-lsp` | gem install + editor config (Neovim lspconfig, generic LSP) |
| CI | `action-kotoshu` | workflow yaml, SARIF upload |

## Structure

- `/install` becomes a channel-picker (tabs or a table: language →
  command), each linking to a per-channel page under
  `/docs/clients/…`.
- `/docs/clients/python|javascript|rust|go|http|lsp|action` pages:
  install, minimal example, capability notes (which engine tier,
  what is native vs client), link to package registry page.
- Per-channel quick starts **verified by running them** (pip install
  + 5-line script; npm install + node -e; cargo add + cargo run;
  docker run + curl) — the docs/quickstart-verification precedent
  (gem plan 28) applies: no example ships unexecuted.
- The audiences page cross-links each persona to their channel.

## Phases

1. `/install` restructure (channel picker).
2. Seven per-channel pages + examples verified.
3. Nav/sitemap/search-index updates.

## Owner gates

None.

## Status

**Implemented (2026-09-05, site PR #2).** /install is a channel catalog
(8 channels); seven guides under /docs/clients/ (python javascript rust
go http lsp action). Every quick start executed for real (pip, npm http
+ wasm, cargo, go, server-from-source + curl, LSP stdio handshake);
the action YAML parse-validated only. Each page carries a verified-date
annotation. kotoshu-server docs intentionally show run-from-source
until the empty 0.1.0 gem is republished.
