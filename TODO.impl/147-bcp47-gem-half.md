# Plan 147: the BCP-47 gem half (variant codes through the engine)

## Status: proposed - executes when the first variant model ships (plan 20)

Owner approval recorded with plan 19 (models repo): the registry now
accepts zh-Hans-CN / zh-Hant-TW / zh-Hant-HK. This plan carries the
codes through the Ruby engine so `kotoshu setup zh-Hans-CN` works the
day the first variant entries land.

## Touchpoints (enumerated, each with its spec)

1. **ModelRegistry + lutaml model**: the language field already
   passes through (lutaml tolerates any string); the REGISTRY ID
   regexes if any - grep `kotoshu://models/{lang}` constructions
   (model_cache.rb:56-92, 344, 572-589) - ids carry the subtag
   verbatim (`kotoshu://models/zh-Hans-CN/full`).
2. **Cache ids + directories**: "{lang}:onnx[:tier]" ids and
   cache/{lang}/models/... paths - dashes are path-safe; add specs
   asserting a subtag language round-trips
   (supports_resource?, load_cached_tier).
3. **CLI + validation**: `kotoshu setup zh-Hans-CN` - the setup path
   validates language codes somewhere (find the gate); widen to the
   plan-19 pattern with CANONICAL CASING (zh-hans-cn rejected with a
   helpful message).
4. **Dictionaries mapping** (the real design point): variant models
   need variant DICTIONARIES. zh-Hans-CN -> the existing zh
   dictionary; zh-Hant-TW / zh-Hant-HK need Traditional dictionaries
   (an acquisition - the dictionaries repo currently ships
   simplified only). Until they exist, the Hant variants are
   model-only (spell-check degrades to model vocab) - record the
   dependency in the registry notes.
5. **language_info / LanguageCache**: the module-languages list is
   dictionary-driven; model-only variants surface via
   languages_setup (the plan-141 union) - spec that too.

## Gates

- Full suite green with a fixture registry entry for zh-Hans-CN
  (synthetic, no download): resolve, cache id round-trip,
  lowercase-rejection message.
- No behavior change for existing two-letter languages (byte-identical
  paths).
