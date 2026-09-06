# 51 — Grammar engine expansion (T3.3)

## Goal

Ship useful grammar rule packs for English, building on the existing
`Kotoshu::Grammar` skeleton. Currently we have:

- `EN_A_VS_AN` (article usage before vowel/consonant sounds)
- `EN_THERE_THEIR` (their vs there)
- `EN_DOUBLE_NEGATIVE` (with the correlative-idiom exception fix
  from PR #52)

Each pack adds one or more rules for a common confusion. The intent
is to demonstrate the engine works for real-world cases — not to
match LanguageTool's 5000-rule corpus.

## Phases

### Phase 1 — Possessive / contraction pairs

| Rule ID         | Pattern                                       | Why                          |
|-----------------|-----------------------------------------------|------------------------------|
| EN_ITS_IT_S     | `its` vs `it's` from POS + context            | Possessive vs contraction    |
| EN_YOUR_YOURE   | `your` vs `you're`                            | Possessive vs contraction    |
| EN_WHOSE_WHO_IS | `whose` vs `who's`                            | Possessive vs contraction    |

These all need a context-check matcher that looks at surrounding
verbs. Reuse the existing `PossessiveContextMatcher` pattern.

### Phase 2 — Common confusion pairs

| Rule ID            | From → To                  | Detection heuristic                |
|--------------------|----------------------------|------------------------------------|
| EN_THEN_THAN       | `then` → `than` (and vice versa) | Pre-comparison ("bigger then")  |
| EN_AFFECT_EFFECT   | `affect` ↔ `effect`        | POS (verb vs noun)                 |
| EN_ACCEPT_EXCEPT   | `accept` ↔ `except`        | Context (preposition vs verb)      |
| EN_LOSE_LOOSE      | `lose` ↔ `loose`           | POS                                |

### Phase 3 — Capitalization

| Rule ID                | Detection                                 |
|------------------------|-------------------------------------------|
| EN_SENTENCE_START_CAP  | First letter after `.`, `!`, `?`          |
| EN_PROPER_NOUN_CAP     | Common proper nouns ("monday", "english") |

Capitalization rules need a SentenceStartMatcher — new matcher type.

### Phase 4 — Rule packs per language

- Move `data/en/grammar/rules.yaml` rules into a `RulePack` abstraction.
- Each language can have multiple packs (base, formal, technical).
- Loader picks the right pack based on configuration.

## Design

- Each rule lives in `data/{lang}/grammar/rules.yaml` (data-driven,
  same as today).
- New matcher types go in `lib/kotoshu/grammar/pattern_matchers/`.
- Rule engine itself doesn't change — Phase 4 just adds a RulePack
  layer over the existing loader.

## Acceptance criteria

- [ ] At least 4 new rule packs shipped for English (Phase 1 + Phase 2).
- [ ] Each rule has direct specs in `spec/kotoshu/languages/en/`.
- [ ] No false positives on the example sentences in the rule
      descriptions.
- [ ] Full suite stays green (2945+ examples, 0 failures).

## Dependencies

- **Blocked by:** none.
- **Blocks:** T3.4 multi-language document checking (the same engine
  is used; per-paragraph language detection picks the right rule
  pack).
