# 8 — Statistical collocation layer (DEMOTED to a ranking signal)

DEMOTION (2026-09-30): a collocation-anomaly score only DETECTS that
a word pair is unusual. It cannot produce the correct correction —
"depend of" is anomalous, but the embedding neighborhood does not
tell you the fix is "depend on". Detection without generation is not
a grammar checker. Context-dependent grammar is handled by the
neural tagger (TODO.grammar/9), which both detects AND generates the
correction from full-sentence context.

## What remains valid here

The fasttext embeddings (57 languages) stay useful as a SECONDARY
signal only:

- reranking candidate suggestions the rule engine produces (prefer
  the candidate that fits the embedding context)
- cheap anomaly prefiltering to route sentences to the neural layer

They are no longer a standalone "grammar layer". No rule fires on
embedding anomaly alone; every user-facing error must carry a
correction string from a rule or the tagger.

## Acceptance (demoted scope)

- suggestion reranking measurably improves top-1 quality on the
  grammar example suites
- zero user-facing errors sourced from bare anomaly scores
