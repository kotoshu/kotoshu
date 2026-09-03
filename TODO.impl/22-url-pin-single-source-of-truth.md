# 22 — Single source of truth for URL + pin config (T1, 0.3-blocker)

## Status
Implemented (shipped in the 0.3 line; re-verified 2026-09-03 against 0.6.0).

Evidence:

- `lib/kotoshu/source_registry.rb` — `SourceRegistry` with a frozen
  `SOURCES` map (spelling/grammar/dict_manifest/frequency/freq_manifest/
  model/model_vocab/model_manifest/model_registry), per-repo
  `default_pin` (`dictionaries` → `v1`, the other repos → `main`),
  `url_for` / `pin_for_source`. Zero `require_relative`; autoloaded from
  `lib/kotoshu.rb:46`.
- `Configuration` exposes `repos_base_url` (`KOTOSHU_REPOS_BASE_URL`),
  `dictionaries_pin` (`KOTOSHU_DICTIONARIES_PIN`, default `v1`),
  `frequency_pin`, `models_pin` (`lib/kotoshu/configuration.rb:75-98`)
  and builds the registry via `#source_registry` (ibid., line 478).
- All three caches build URLs through the registry — no inline URL
  strings: `language_cache.rb:195,204,233,261,295`,
  `frequency_cache.rb:232,239`, `model_cache.rb` (now registry-driven,
  see below).
- Spec: `spec/kotoshu/source_registry_spec.rb` — run 2026-09-03,
  19 examples, 0 failures.
- Live check (2026-09-03):
  `Kotoshu::SourceRegistry.new.url_for(:spelling, lang: "en", ext: "aff")`
  → `https://raw.githubusercontent.com/kotoshu/dictionaries/v1/en/spelling/index.aff`
  (exactly the acceptance URL).

Deviations from the plan text:

- `dictionaries_url` / `models_url` were not removed — they remain in
  `SCHEMA` marked "Deprecated" and are consumed nowhere outside
  `configuration.rb`.
- The model source later evolved past URL templates into a tiered
  `registry.json` (`lib/kotoshu/cache/model_registry.rb`,
  TODO.impl/67 M1: mini/fluency/full tiers).

## Problem
Today there are three overlapping configuration knobs for where to fetch
resources from:

```ruby
dictionaries_url: "https://raw.githubusercontent.com/kotoshu/dictionaries/main"
resource_pin:     "main"          # used by language_cache, frequency_cache
models_url:       "https://github.com/kotoshu/models-fasttext-onnx/raw/main"
models_pin:       "main"          # used by model_cache
```

Three problems:

1. **`/main` is baked into `dictionaries_url` even though `resource_pin`
   is meant to be the branch selector.** The URL builder in
   `lib/kotoshu/cache/language_cache.rb:181` is:
   ```ruby
   "#{@url_base}/dictionaries/#{@resource_pin}/#{language}/spelling/index.aff"
   ```
   So the URL is `<url_base>/dictionaries/<pin>/<lang>/...` — and the
   `dictionaries/main` in the default URL is dead weight, never substituted.

2. **Each repo has its own default branch.** `kotoshu/dictionaries` is
   on `v1`; `frequency-list-kelly` and `models-fasttext-onnx` are on
   `main`. A single `resource_pin` cannot honor both.

3. **URL templates are scattered.** `language_cache.rb`, `frequency_cache.rb`,
   `model_cache.rb` each build their own URL strings. No single source.

## Plan

### Introduce `Kotoshu::SourceRegistry`

A new model class — single source of truth for "where does each resource
type live, and at what pin."

```ruby
# lib/kotoshu/source_registry.rb
module Kotoshu
  class SourceRegistry
    Source = Struct.new(:repo, :default_pin, :url_template, keyword_init: true)

    SOURCES = {
      spelling:  Source.new(repo: "dictionaries",          default_pin: "v1",
                            url_template: "%{base}/dictionaries/%{repo}/%{pin}/%{lang}/spelling/index.%{ext}"),
      frequency: Source.new(repo: "frequency-list-kelly",  default_pin: "main",
                            url_template: "%{base}/frequency-list-kelly/%{pin}/data/%{lang}.json"),
      model:     Source.new(repo: "models-fasttext-onnx",  default_pin: "main",
                            url_template: "%{base}/models-fasttext-onnx/%{pin}/models/%{lang}/fasttext.%{lang}.onnx"),
      manifest:  Source.new(repo: "dictionaries",          default_pin: "v1",
                            url_template: "%{base}/dictionaries/%{pin}/manifest.json")
    }.freeze

    def self.url_for(resource_kind, lang: nil, ext: nil, base: nil, pin: nil)
      # ...
    end
  end
end
```

### Replace `dictionaries_url`, `resource_pin`, `models_url`, `models_pin`

In `Configuration`:
- Keep `repos_base_url` (one config knob — the GitHub raw root).
- Keep per-source pin overrides: `dictionaries_pin`, `frequency_pin`,
  `models_pin` — but with correct defaults (`v1` for dictionaries).
- Remove `dictionaries_url`, `models_url`, `resource_pin` (drift-prone).

Caches call `SourceRegistry.url_for(:spelling, lang: "en", ext: "aff")`
instead of building strings.

## Acceptance

- [ ] `SourceRegistry` exists, is fully tested, has zero `require_relative`.
- [ ] `Configuration` exposes only `repos_base_url`, `dictionaries_pin`,
      `frequency_pin`, `models_pin`.
- [ ] Each cache class no longer builds URL strings inline — calls
      `SourceRegistry.url_for`.
- [ ] Default URL for `kotoshu setup en` resolves to a real file
      (i.e. `https://raw.githubusercontent.com/kotoshu/dictionaries/v1/en/spelling/index.aff`).

## Dependency
- Blocks #23 (URL defaults fix), #29 (status command needs to show URLs).
