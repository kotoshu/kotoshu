# 64 — HTTP API server & multi-language SDKs

Promotes the cross-ecosystem reach idea into a promotable plan. This is
the "make it big" path for users who don't run Ruby.

## Goal

A self-hostable HTTP API that wraps the Kotoshu library, plus thin SDK
clients in Python, JavaScript/TypeScript, and Go so non-Ruby projects
can use Kotoshu without shelling out to the CLI.

```
┌────────────────┐         ┌─────────────────┐
│  Python app    │  HTTPS  │                 │
│  JS app        ├────────►│  kotoshu server │──► Kotoshu.check / .suggest
│  Go app        │         │  (Rack/Sinatra) │
│  Rust app      │         │                 │
└────────────────┘         └─────────────────┘
```

The server is a **separate gem** (`kotoshu-server`); SDKs are separate
repos under `kotoshu/`. The library gem stays focused on
spell-checking; the server gem holds the HTTP surface.

## Why

Kotoshu is a Ruby library. The Ruby ecosystem is one of many. Without
an HTTP entry point:

- Python shops (Django, Flask) can't use Kotoshu without a Ruby
  subprocess.
- JavaScript shops (Node, Deno, Bun) reach for `spellchecker` (node)
  or `cspell` and never hear about Kotoshu.
- Go shops shell out and parse SARIF — works, but no one's first
  choice.
- Enterprise stacks (Java/Kotlin, .NET) are simply unreachable from a
  Ruby library.

An HTTP API + thin SDKs puts Kotoshu in the same shape as LanguageTool
(which ships a public HTTP API and is the de-facto standard for this)
without giving up the "self-hostable" guarantee that the
privacy-conscious require.

This is also the answer to "more use cases": with the API in place,
the use cases multiply without further Kotoshu work — a browser
extension, a Slack bot, a WordPress plugin, an Obsidian plugin all
become one HTTP call away.

## Tasks

### Phase 1 — HTTP server (`kotoshu-server` gem)

1. **New repo `kotoshu/kotoshu-server`.** Rack-based (Sinatra for the
   routing, or pure Rack for minimalism). Depends on `kotoshu`.
2. **Endpoints.**
   - `POST /v1/check` — body: `{ text, language?, format? }`. Returns
     a `DocumentResult`-shaped JSON (mirrors the CLI's `--format json`).
   - `POST /v1/suggest` — body: `{ word, language?, max? }`. Returns
     a `SuggestionSet`-shaped JSON.
   - `POST /v1/detect` — body: `{ text }`. Returns detected language
     + confidence.
   - `GET /v1/languages` — lists supported + cached languages.
   - `GET /v1/health` — liveness probe; returns cache state.
   - `GET /v1/version` — library + server versions.
3. **Resource management.** On startup, the server runs
   `Kotoshu.setup(*configured_languages, want: %i[spelling frequency])`
   so the cache is warm before serving requests. New languages can be
   added at runtime via `POST /v1/admin/setup` (gated behind an admin
   token).
4. **Semantic mode.** Optional: when ONNX is enabled (plan 05), a
   `model: "hybrid"` query param turns on reranking for that request.
   Default `model: "hunspell"` to bound latency.
5. **Concurrency model.** Puma or Falcon (Falcon for async I/O —
   better fit for the long-running suggestion pipeline). Multiple
   workers; each worker owns its own `Spellchecker` instance (or
   shares a thread-safe one — verify in `02-cli-unification`).
6. **Rate limiting + auth.** Optional API key middleware (operator's
   choice). Ship disabled by default; document how to enable.
7. **Observability.** Structured JSON logs (one line per request);
   Prometheus metrics endpoint at `/v1/metrics`. Latency histograms
   for `check` and `suggest`.

### Phase 2 — Docker & ops

8. **`kotoshu/server` Docker image.** Multi-arch (amd64, arm64).
   Pre-warmed with the six full-feature languages. Configurable via
   `KOTOSHU_*` env vars.
9. **Helm chart.** For Kubernetes deployments. Configurable replicas,
   resource limits, language pre-warm list.
10. **`docker-compose.yml`.** For local dev: one command (`docker
    compose up`) gives a running server on `:9292`.
11. **Benchmark suite.** `spec/performance/server_bench.rb`:
    - Throughput: requests/sec on a 4-core machine (target: > 200 rps
      for `check` with short text).
    - Latency p50/p95/p99 for `check` and `suggest`.
    - Memory under sustained load (target: < 2 GB resident with
      `hunspell` mode, < 5 GB with `hybrid`).

### Phase 3 — SDKs

12. **`kotoshu/kotoshu-python`.** PyPI package `kotoshu`.
    - Sync client (`requests`) and async client (`httpx`).
    - Type stubs for IDE autocomplete.
    - Methods: `check(text, language=None)`, `suggest(word, language=None)`,
      `detect(text)`.
    - Streaming client for `POST /v1/check` if/when streaming lands.
13. **`kotoshu/kotoshu-js`.** npm package `@kotoshu/client`.
    - Works in Node, Deno, Bun, and modern browsers (via `fetch`).
    - TypeScript types.
    - Same method surface as the Python SDK.
14. **`kotoshu/kotoshu-go`.** Go module.
    - `kotoshu.NewClient(url)` → `.Check(ctx, text, opts)` etc.
    - Idiomatic Go (context.Context everywhere, typed errors).
15. **SDK contract tests.** A shared OpenAPI spec drives generated
    fixtures; each SDK's test suite runs against the fixtures so the
    SDKs stay in sync with the server.

### Phase 4 — Documentation & reach

16. **OpenAPI spec** in the server repo, published to
    [`openapis.org`](https://openapis.org) cataloging. Auto-generates
    SDK clients in other languages (Rust, .NET, Java) via
    openapi-generator — best-effort, community-supported.
17. **Self-hosting guide.** Step-by-step for Docker, Kubernetes, bare
    Ruby. Covers sizing, language pre-warm, and monitoring.
18. **Privacy guarantee.** Document that self-hosted = your data stays
    in your network. Contrast with LanguageTool's public API.
19. **Migrating from LanguageTool API.** Side-by-side: same input,
    different response shape; provide a shim if there's demand.

## Acceptance criteria

- `docker run -p 9292:9292 kotoshu/server` serves `POST /v1/check`
  within 5 s of container start.
- Throughput > 200 rps for `check` (short text) on a 4-core machine.
- Each SDK has a one-page quickstart that works against a running
  server.
- All SDKs pass contract tests against the latest server release.
- OpenAPI spec validates; auto-generated Rust client compiles.
- Helm chart deploys to a test cluster and serves requests.

## Dependencies

- **Blocked by:**
  - `02-cli-unification` — clean library API to wrap
  - `03-dynamic-download` — resource management for the server
  - `05-semantic-path` — for the `hybrid` mode option
  - `09-integrity-security` — for safe download + verification in
    server-managed cache
- **Blocks:** `11-release-v1` (the server + SDKs are part of the v1
  reach story).
- **Cross-repo:** new repos `kotoshu/kotoshu-server`,
  `kotoshu/kotoshu-python`, `kotoshu/kotoshu-js`, `kotoshu/kotoshu-go`.
- **Promotes from:** implied by "every project, every language" in
  `00-vision.md`.

## Out of scope

- A managed / hosted API (operator concern; document self-hosting
  instead — privacy is the differentiator).
- Multi-tenant features (per-tenant dictionaries, per-tenant rate
  limits). Operators build that on top if needed.
- Real-time streaming of partial check results (defer to a v2 if
  there's demand).
- Auth provider integrations (OAuth, OIDC). Ship an API-key
  middleware; operators wire their own auth in front.
- A Rust SDK in-repo (the OpenAPI-generated client is best-effort;
  accept community contributions if a maintainer steps up).

## Risks

- **Operational burden.** A Docker image + Helm chart is a maintenance
  surface. Decide upfront whether the project commits to LTS-style
  releases of the server, or treats it as community-maintained.
- **API stability.** v1 endpoints must be stable. Freeze the JSON
  shapes before tagging `kotoshu-server` v1.0; thereafter breaking
  changes go to `/v2/*`.
- **Cold-start cost.** Pre-warming six languages on container start
  means slow boot. Tradeoff: eager warm (fast requests, slow boot) vs
  lazy (fast boot, slow first request). Default eager; document
  `KOTOSHU_SERVER_LAZY=1` for the other mode.
- **SDK drift.** Three SDKs × ongoing server changes is real work.
  The OpenAPI-generated contract tests (task 15) are the only sane
  way to keep them aligned; budget for maintaining the spec.

## Status

_Pending._ Phase 1 + 2 is a coherent v0.1; phase 3 SDKs are v0.2; v1.0
is the API-freeze milestone. The single biggest risk is the operational
commitment — confirm with maintainers that the project is willing to
ship and support a server image before starting phase 2.
