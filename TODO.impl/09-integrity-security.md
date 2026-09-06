# 09 — Integrity & Security

## Goal

Every resource Kotoshu downloads from the network is verified against a
cryptographic checksum before use. Releases are signed. Downloaded data
cannot silently change without detection.

## Why

`Configuration::SCHEMA` has `auto_download: true` by default. The three
caches pull arbitrary bytes over HTTPS with zero integrity verification.
For CI/CD use (SARIF pipelines), supply-chain attacks (a compromised
GitHub repo swapping in a malicious dictionary), and reproducibility,
this is unacceptable. SLSA / supply-chain-attestation norms now expect
this baseline.

## Tasks

1. **Manifest format.** Define `manifest.json` at the root of each
   content repo:
   ```json
   {
     "version": 1,
     "generated_at": "2026-06-25T10:00:00Z",
     "resources": {
       "en/spelling/index.dic": {
         "size": 49568,
         "sha256": "ab12...",
         "language": "en",
         "type": "spelling",
         "license": "LGPL/MPL/GPL",
         "source": "SCOWL"
       },
                       }
     }
   }
   ```
2. **Manifest fetching.** The caches fetch `manifest.json` first, then
   individual resources. Resources without a manifest entry are refused.
3. **SHA-256 verification.** After download, recompute SHA-256 and
   compare. Mismatch raises `Kotoshu::IntegrityError` with expected vs.
   actual in the message.
4. **Signing (stretch).** Sign `manifest.json` with a Kotoshu project
   key (minisign or sigstore). The gem bundles the public key; CI
   verifies the signature. Stretch goal — checksum-only is the v1
   baseline.
5. **Audit log.** Every download is logged to
   `~/.kotoshu/audit.log` with timestamp, URL, size, SHA-256, source
   manifest hash. Lets users inspect what was fetched.
6. **Pin/lockfile support.** `Kotoshu.configure { |c| c.resource_pin =
   "v1.2.0" }` resolves against a specific content repo tag instead of
   `main`. Required for reproducible CI.
7. **Rate limiting.** Respect GitHub's rate limits (60/hr unauthenticated,
   5000/hr with token). Add exponential backoff and a clear error when
   rate-limited. Support `KOTOSHU_GITHUB_TOKEN` env var.
8. **TLS pinning (optional).** Document that GitHub's CDN cert pin is
   out of scope for v1 but the gem always verifies TLS chain.
9. **Threat model doc.** Add `SECURITY.md` documenting: what we verify
   (checksums), what we don't (signing is stretch), how to report a
   compromised resource.

## Acceptance criteria

- Tampering with a single byte in a cached file causes the next
  `Kotoshu.check` to refuse to load it
- `Kotoshu.check(text, resource_pin: "v1.0.0")` resolves against
  `dictionaries` repo tag `v1.0.0`
- `~/.kotoshu/audit.log` records every download
- CI runs without hitting GitHub rate limits on a fresh runner
- `SECURITY.md` exists and is linked from the README

## Dependencies

- Blocks: `03-dynamic-download` (ResourceManager needs this to verify),
  `11-release`
- Cross-repo: each content repo must ship `manifest.json`:
  - `dictionaries/TODO.impl/01-manifest-checksums.md`
  - `frequency-list-kelly/TODO.impl/02-data-validation.md`
  - `models-fasttext-onnx/TODO.impl/03-manifest-checksums.md`

## Out of scope

- Full SLSA Level 3 attestation (overkill for v1)
- Mirroring/CDN strategy (GitHub raw content is fine for v1)
- Encrypting cached files at rest (user's filesystem is their boundary)

## Status

_Pending._
