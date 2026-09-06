# 03 — Dynamic Resource Download

## Goal

One call — `Kotoshu.check(text)` — works for any of the supported
languages without the user pre-installing anything. The library detects
language, resolves what's needed, downloads it, verifies integrity, and
caches.

This is the heart of the project's promise.

## Why

Today the three caches (`LanguageCache`, `FrequencyCache`, `ModelCache`)
exist independently. The user (or the spellchecker) has to know which to
call. Configuration is keyed on `dictionary_type` and `language`, but
there's no unified resolver that takes arbitrary text and yields the full
resource bundle.

## The missing piece: `ResourceManager`

A new top-level component (autoloaded from
`lib/kotoshu/resource_manager.rb`) that owns the contract:

```ruby
bundle = Kotoshu::ResourceManager.resolve(
  text: "Guten Tag, wie geht's?",
  language: :auto,           # or "de", "en-US", nil
  want: %i[spelling frequency embeddings grammar],
  force_download: false
)
# => #<ResourceBundle
#      language: "de",
#      dictionary: #<Dictionary::Hunspell ...>,
#      frequency: #<FrequencyData ...>,
#      model: #<OnnxModel ...>,           # nil if unavailable
#      rules: #<Grammar::RuleSet ...>,    # nil if not present
#      cached: true,
#      source_urls: [...]>
```

The `Spellchecker` is rewritten to take a `ResourceBundle` instead of a
single `Dictionary::Base`.

## Tasks

1. **Define `ResourceBundle`** as a value object (Struct or plain class —
   no hand-rolled `to_h`; project rule). Fields: `language`, `dictionary`,
   `frequency`, `model`, `rules`, `cached`, `source_urls`.
2. **Implement `ResourceManager.resolve`.** Pseudocode:
   ```
   detect language if :auto (Language::Identifier)
   parallel-fetch each wanted resource (cache → download → verify)
   construct ResourceBundle
   ```
   Use existing caches — don't reimplement.
3. **Manifest verification** (depends on `09-integrity-security` and on
   each content repo shipping a `manifest.json` with SHA-256s). Every
   download is rejected if the checksum doesn't match.
4. **Offline mode.** `Kotoshu.check(text, offline: true)` only uses cached
   resources; raises `ResourceNotCachedError` if missing instead of
   hitting the network. Required for CI/CD and air-gapped use.
5. **Strict mode.** `Kotoshu.check(text, strict: true)` raises if any
   wanted resource can't be obtained (vs. default graceful degradation:
   missing model → skip semantic rerank; missing frequency → no bonus).
6. **Cache pre-warm CLI**. `kotoshu fetch de en es fr pt ru` resolves and
   downloads all resource types for those languages. Useful before
   air travel / CI.
7. **Configuration knobs**. Add to `Configuration::SCHEMA`:
   - `resource_sources` — hash mapping resource type → URL base
     (defaults to current `dictionaries_url`)
   - `offline` (boolean, default false)
   - `strict_resources` (boolean, default false)
   - `parallel_downloads` (integer, default 4)
8. **Progress reporting.** A `Progress` callback hooks into the cache
   downloads so the CLI can show `[en] downloading dictionary (3.2MB)…`
9. **Spec coverage.** A new `spec/integration/dynamic_resolution_spec.rb`
   with a fake HTTP server (Sinatra::Base, no VCR — project rule from
   commit `90aa886`) that serves fixtures and verifies the full resolve →
   cache → re-use cycle. Tag `:network` so it's skippable.

## Acceptance criteria

- `Kotoshu.check("Bonjour le monde")` works on a fresh machine after
  installing only the gem (auto-downloads fr dictionary + Kelly + ONNX)
- `Kotoshu.check("こんにちは", offline: true)` raises a useful error
  explaining what to pre-fetch
- All downloads verify checksums; mismatch raises
  `IntegrityError` with the expected vs. actual hash
- CLI `kotoshu fetch de` warms every resource type for German
- No network call when the cache is hot

## Dependencies

- Blocks: `04-language-modules`, `05-semantic`, `06-cjk`, `07-rtl`
- Blocked by: `09-integrity-security`, and each content repo's
  `01-manifest-checksums.md`

## Out of scope

- P2P distribution, torrent mirrors
- Streaming/incremental dictionary load (load whole file then index)
- WebAssembly / in-browser use

## Status

_Pending._
