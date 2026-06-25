# Security Policy

## Reporting a Vulnerability

Email security@kotoshu.org with details and a reproduction. You will
receive an acknowledgement within 72 hours. Please do not file public
issues for security reports.

## Supported Versions

The latest 0.x minor is supported. Older minors are not maintained.

## Threat Model

Kotoshu downloads dictionaries, frequency lists, and (optionally)
embedding models from public GitHub repositories on first use:

| Resource | Source repo | Cached at |
|---|---|---|
| Spelling dictionaries | `kotoshu/dictionaries` | `~/.kotoshu/languages/{code}/` |
| Kelly frequency lists | `kotoshu/frequency-list-kelly` | `~/.kotoshu/frequency-lists/{code}/` |
| FastText / ONNX models | `kotoshu/models-fasttext-onnx` | `~/.kotoshu/models/{code}/` |

Downloads flow over HTTPS from `raw.githubusercontent.com`. The threat
model assumes GitHub serves the bytes the repository owner committed,
and treats anyone with push access to those repos as trusted.

## Integrity Verification

Each content repo may ship a `manifest.json` at its root listing every
file with its SHA-256 hash, size, and language/type tags. When a
manifest is present, every download is verified against it:

1. The manifest is fetched once per cache session.
2. Each downloaded file's SHA-256 is computed locally and compared to
   the manifest entry.
3. On mismatch, `Kotoshu::IntegrityError` is raised with the expected
   and actual hashes. The download is rejected and the cache is left
   untouched.
4. Every verification outcome (verified / unverified / mismatch /
   missing) is appended to `~/.kotoshu/audit.log` as one JSON object
   per line.

### Graceful Degradation

When a manifest is **absent** (HTTP 404), verification silently
downgrades to `"unverified"` status and the download proceeds. This
preserves forward compatibility with repos that have not yet shipped a
manifest. The audit log records the difference.

### Strict Mode

`Kotoshu.spellchecker_for(lang, strict: true)` (and the CLI's
`--strict` flag) re-raise on any optional-resource failure — including
integrity mismatches on frequency data — instead of silently
degrading. Spelling-dictionary integrity is always enforced.

## Cache Layout

The cache is written under `$KOTOSHU_HOME` (default `~/.kotoshu/`).
Files are created with the user's default umask. Cache contents are
not encrypted at rest.

## Audit Log

`~/.kotoshu/audit.log` is append-only, JSON-per-line, and never
auto-rotated. Operators in multi-user environments should rotate it
via logrotate or equivalent. To inspect:

[source,bash]
----
cat ~/.kotoshu/audit.log | jq .
----

To clear the audit log:

[source,ruby]
----
Kotoshu::Integrity::AuditLog.new(path: "#{ENV['HOME']}/.kotoshu/audit.log").clear!
----

## Network Egress

`offline: true` (or `KOTOSHU_OFFLINE=1` or `--offline`) disables all
network egress and only reads from the on-disk cache. If a required
resource is not cached, the call raises `Kotoshu::ResourceNotCachedError`
(CLI exits 3). Use `kotoshu fetch LANGUAGE` to pre-warm the cache in
environments without outbound network access.

## Scope

This policy covers the kotoshu gem itself. Vulnerabilities in
dependencies (Thor, suika, onnxruntime) should be reported upstream.
