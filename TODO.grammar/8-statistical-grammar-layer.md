# 8 — Statistical grammar layer (our unique advantage)

Nobody else has client-side statistical grammar checking. We have the
models (57 languages of fasttext embeddings); the wiring is the work.

## What it catches (that rules miss)

- **Collocation errors**: "depend of" → "depend on" (the embedding
  distance between "depend" and "of" is anomalous)
- **Redundant prepositions**: "discuss about" → "discuss"
- **Wrong preposition**: "interesting in" → "interested in"
- **Agreement errors the rules miss**: complex subjects with
  intervening phrases ("The list of items ARE..." → "IS")
- **Word order anomalies**: "have I a question" vs "do I have"

## How it works

For each pair of adjacent words in a sentence:
1. Look up the fasttext embedding for each word
2. Compute the context likelihood (how expected is this word pair?)
3. If the pair is anomalous (below a threshold) AND neither word is
   flagged by spelling, flag it as a potential grammar error
4. Offer suggestions from the nearest neighbors in embedding space

## What we already have

- The fasttext models: ✅ 57 languages, ONNX, int8, client-side
- The embedding lookup infrastructure: ✅ (Embeddings::Vocabulary, SimilaritySearch)
- The realword detection: ✅ already scores context anomaly
- The ONNX runtime: ✅ same infrastructure as the spelling models

## What we need to build

- The pair-scoring function (two adjacent words → anomaly score)
- The grammar-specific threshold calibration
- The suggestion generation (nearest neighbor in the pair context)
- The integration with the rule engine (rules first, stats on residual)

## Performance target

- Pair scoring: <0.5ms per word pair (embedding lookups are cached)
- A 20-word sentence: <10ms on the statistical layer
- Combined with rules: <15ms per sentence (client-side viable)

## The hybrid pipeline

```
1. Rule engine fires (high precision, fast)          → 80% of errors
2. Statistical layer on unflagged pairs (recall)     → the long tail
3. Optional: neural tagger (if a model is loaded)    → the hardest cases
```
