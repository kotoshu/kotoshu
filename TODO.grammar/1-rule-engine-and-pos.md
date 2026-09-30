# 1 — Rule engine enhancement + POS tagging

The existing `Grammar::RuleEngine` + 8 pattern matchers handle
word-list, regex, and simple pattern rules. To reach LanguageTool-
class rules we need POS-aware matching.

## Phase 1a: POS tagger (rule-based, no ML dependency)

A suffix-and-context POS tagger for en that classifies each token
into a reduced tagset (the 20 that grammar rules actually need):

```
NOUN, VERB_BASE, VERB_3SG, VERB_PAST, VERB_PARTICIPLE,
ADJ, ADV, PREP, DET, PRON, CONJ, INTERJ, MODAL, NUMBER, OTHER
```

Algorithm (deterministic, no model, ~100 rules):
1. Suffix rules: `-ing` → VERB_PARTICIPLE, `-ed` → VERB_PAST,
   `-ly` → ADV, `-tion` → NOUN, etc. (~40 suffix rules)
2. Word-list overrides: common irregulars (be/have/do, the, a, an...)
3. Context disambiguation: "the ___ NOUN" → ADJ|NOUN (choose ADJ
   if suffix matches); "MODAL ___" → VERB_BASE
4. Capitalization: mid-sentence Capitalized → PROPER_NOUN

Target speed: <1ms per sentence (Ruby: pure hash lookups).

## Phase 1b: Rule format (YAML, API-agnostic)

```yaml
- id: EN_SUBJECT_VERB_AGREEMENT
  category: agreement
  language: en
  pattern:
    - { pos: PRON, word: [he, she, it] }
    - { pos: NOUN, singular: true }
    - { pos: VERB_BASE, exception: [modal] }
  message: "Subject-verb agreement: '{{1}}' requires a third-person verb"
  suggestion: "{{2}}s"  # suffix template
  examples:
    - { bad: "He go to school", good: "He goes to school" }
  fp_budget: 0.02  # max false-positive rate
```

The same YAML loads in Ruby (the gem), Rust (serde_yaml), and TS
(JSON via the HTTP API). The pattern DSL is a sequence of token
constraints: word match, POS match, regex, negation, optional.

## Phase 1c: The pattern matchers — what needs building

Existing 8 matchers cover:
- word_list_matcher: word in/out of set
- regex/phrase_matcher: literal or regex sequence
- double_negative_matcher: negation co-occurrence
- vowel_sound_matcher: a/an
- possessive_context_matcher / possessive_contraction_matcher
- sentence_start_matcher

New matchers needed:
- `pos_sequence_matcher`: match a POS-tag sequence (the main new
  matcher — evaluates the tagger output against pattern constraints)
- `agreement_matcher`: subject-verb, pronoun-antecedent (uses the
  POS tags + morphology heuristics)
- `collocation_matcher`: two words that co-occur with wrong
  preposition/particle (e.g. "depend of" → "depend on")
EOF
echo "file 1 written"