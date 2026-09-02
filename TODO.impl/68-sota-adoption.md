# 68 — SOTA Techniques: Research Adoption Plan

Mandate: survey 2023–2026 ML/AI and spellcheck research (arxiv, ACL,
lab reports) and the current frontier model lines, and decide what
Kotoshu adopts, adapts, or rejects. Research conducted 2026-09-02; the
full sourced brief lives in this plan's "Findings" section. Companion
execution context: [65](65-universal-kotoshu.md) (pillars),
[66](66-kotoshu-core.md) (Rust core, `ort`), [67](67-kotoshu-rs-and-access-libraries.md)
(delivery train); models-repo plans 06/07 (tiers, registry) already
shipped eval-gated tiers.

## Findings (compressed; URLs are the evidence)

### Spelling / GEC state of the art

| Approach | Class | BEA-2019 F0.5 | Note |
|---|---|---|---|
| GECToR-style tagging + distill | 100–250M | ~74–75 | Still beats prompting on precision-weighted benches — small supervised > LLM prompting for correction ([NLP-progress](http://nlpprogress.com/english/grammatical_error_correction.html), [Grammarly GECToR](https://www.grammarly.com/blog/engineering/experimenting-with-gector/)) |
| T5/BART seq2seq | 250M–3B | ~73 | Linear-decoding tricks close the gap ([gec-papers](https://github.com/Chunngai/gec-papers)) |
| Prompted GPT-4-class | API-scale | high-50s–60s | Win on JFLEG *fluency*, lose on precision ([OpenReview](https://openreview.net/forum?id=yAMayChodt)) |
| Fine-tuned 1–8B LLM | edge-LLM | closing | Overcorrection risk ([arxiv 2509.20811](https://arxiv.org/html/2509.20811v1)) |
| Masked-LM real-word ranking | small | ~85% acc | The closest published twin to our pipeline: dictionary candidates + neural ranker, with **training-data construction called "the crucial component"** ([arxiv 2410.23514](https://arxiv.org/html/2410.23514v1)) |

LLM-as-GEC-evaluator is now standard practice
([BEA 2024](https://aclanthology.org/2024.bea-1.6/)) — relevant to our
eval harness, not our runtime.

### Embeddings / tiering (directly about our shipped tiers)

- **Matryoshka / 2D-MRL**: plain truncation of non-MRL embeddings is
  safe until deep reduction; MRL training only pays beyond that
  ([arxiv 2205.13147](https://arxiv.org/abs/2205.13147),
  [arxiv 2605.16608](https://arxiv.org/html/2605.16608v2)). Our tiers
  already are 2D truncation (vocab axis prefix + kept dims) —
  independently validated by 2D-MRL work
  ([arxiv 2410.13230](https://arxiv.org/html/2410.13230v1),
  [HF guide](https://huggingface.co/blog/matryoshka)). **A single
  frequency-ordered file with declared truncation points can replace
  three artifacts with no retraining.**
- **Quantization**: int8 near-lossless (matches our 0.9999 rank_corr);
  int4 with group-wise scales (≤128) still beats ANN-approximation
  error ([arxiv 2501.10534](https://arxiv.org/html/2501.10534v1)).
  Full 120 MB → int4 ≈ 15–20 MB near-lossless.
- **Static embeddings**: Model2Vec/Potion — distilled static
  embeddings, ~30 MB, 500× faster, beats other statics on MTEB
  ([MinishLab](https://github.com/MinishLab/model2vec),
  [fastText comparison](https://minish.ai/blog/2025-07-28-fasttext/)).
  Word-keyed like ours — same OOV gap.
- **OOV (our biggest functional gap — models are word-keyed)**:
  fastText hashed char 3–6-gram buckets remain the standard answer;
  collision-aware hash embeddings improve them
  ([arxiv 1709.03933](https://arxiv.org/abs/1709.03933)).

### Named model lines — verified, techniques extracted

- **Claude Fable 5 / 5.1** — VERIFIED
  ([announce](https://www.anthropic.com/news/claude-fable-5-mythos-5),
  [5.1](https://www.anthropic.com/claude-fable-and-mythos-5-1),
  [Willison](https://simonwillison.net/2026/Jun/9/claude-fable-5/));
  "Fable 5.0" is not a named release. Techniques: same-weights
  multi-safeguard releases, 5-level reasoning-effort control, cheap
  cache reads. **Relevance: low** — effort-tiering is already our
  tier/backend model.
- **GLM 5.1/5.2/5.3/5.3-Flash** — VERIFIED
  ([tech report](https://arxiv.org/html/2602.15763v1), z.ai blogs).
  Key adoptable idea from 5.3: **RL on synthesized verifiable
  environments with binary rewards** — all gains from post-training on
  the same base. Spelling correction is verifiable by construction
  (output == reference), making it an ideal small-scale RL domain.
- **DeepSeek V4 Pro/Flash** — VERIFIED
  ([report](https://arxiv.org/html/2606.19348v1)). Adoptable:
  specialist→student **on-policy distillation (reverse KL)** — the
  exact recipe for distilling a big reranker into our tier sizes;
  FP4/QAT embedding-table practice. MoE/CSA/1M-context: scale-mismatched.
- **Hy4** — IDENTIFIED as Tencent Hunyuan Hy4 preview (770B/49B MoE,
  Apache-2.0, [HF](https://huggingface.co/tencent/Hy4-preview)).
  **Relevance: low** — no training details published.

## Adoption matrix

### Adopt now (Ruby today, no new deps)

| # | What | Where it lands | Why now |
|---|---|---|---|
| A1 | **Multilingual keyboard-aware typo generator** (MULTYPO-style) for the eval harness — our current `run_eval.py` typos are ASCII-lowercase-only, nearly meaningless for de/ru/ja/zh | models repo, `eval/` | Biggest correctness hole in our own gates; pure code; keyboard layouts already exist in the gem ([MULTYPO](https://github.com/cisnlp/multypo)) |
| A2 | **GitHub Typo Corpus** as a real-world multilingual eval set (350k+ edits, 15+ languages) alongside the synthetic proxy | models repo, `eval/corpora/` (download-once, cache) | Grounds the proxy metric in real human typos ([corpus](https://github.com/mhagiwara/github-typo-corpus), [LREC paper](https://aclanthology.org/2020.lrec-1.835/)) |
| A3 | **Confidence cascade, formalized**: dictionary/affix verdict first; ONNX rerank only for uncertain candidates; document thresholds | gem, semantic path (plan 05) | Published hybrid twin does exactly this; we half-do it today ([arxiv 2410.23514](https://arxiv.org/html/2410.23514v1)) |
| A4 | **Single nested (2D-Matryoshka) artifact**: one frequency-ordered file + declared truncation points replacing mini/fluency downloads; separate files stay available | models repo, post-07 experiment | Truncation safety is literature-validated; one download serves all tiers ([arxiv 2605.16608](https://arxiv.org/html/2605.16608v2)) |

### Adopt with kotoshu-rs (ort / Rust core)

| # | What | Lands in | Why then |
|---|---|---|---|
| B1 | **int4 group-128 quantized full tier** (120 MB → ~15–20 MB near-lossless); possibly a `nano` tier | kotoshu-rs P3 + models repo tiers | Needs the core's own dequant math / ort support; near-lossless per [2501.10534](https://arxiv.org/html/2501.10534v1) |
| B2 | **Hashed char n-gram OOV fallback** (fastText buckets or collision-aware hashing) so unseen words still embed | kotoshu-rs P3; converter in models repo | Fixes the word-keyed OOV gap at last ([1709.03933](https://arxiv.org/abs/1709.03933)) |
| B3 | **Tiny cross-encoder reranker option** (~22M distilled MiniLM class, ONNX) behind the provider trait | kotoshu-rs P3+ | Better rerank than cosine bi-encoder for hard cases; our ≤25-candidate scale keeps it cheap ([sbert efficiency](https://sbert.net/docs/cross_encoder/usage/efficiency.html)) |

### Adopt later (deliberate, data-gated)

| # | What | Gate |
|---|---|---|
| C1 | **Model2Vec/Potion static embeddings** as reranker base (~30 MB, 500× faster) | per-model license verified for redistribution; win over fastText shown on our eval |
| C2 | **RL with binary verifiable rewards** to train reranker weights (GLM-5.3 recipe, scaled down ~10⁶) | after conformance vectors exist (67 M3) so reward is measurable; needs a training pipeline owner |
| C3 | **On-policy distillation** of a large teacher into tier-sized rerankers (DeepSeek V4 recipe) | same gate as C2 |
| C4 | **LLM-as-evaluator** for eval reports (offline, not CI) | optional; proxy metrics suffice until corpora land |
| C5 | **Optional external LLM mode** (1–8B fine-tuned GEC or API) as an explicit opt-in "heavy" backend | user demand; never default (latency/RAM violate our constraints) |

### Reject

- **Shipping any LLM as the default engine** — violates small/offline/CPU.
- **MoE, MLA/CSA attention, 1M-context techniques** — meaningful only at
  10⁹+ parameter scale; a 300-dim embedding table has nothing to sparse-ify.
- **Distillation-prevention / watermarking / cache-economics patterns**
  from the frontier labs — business-side, not engine-side.

## Near-term execution (promotes from this plan)

1. **A1 typo generator** — extend `eval/` with per-language keyboard
   noise models driven by the gem's existing layout data; regenerate
   all 18 reports; gates unchanged (they will get *harder*, honestly).
2. **A2 corpus benchmark** — fetch script + cache + report format;
   license (MIT) recorded in the registry-style metadata.
3. **A4 nested-artifact experiment** — build `fasttext.{lang}.matryoshka.onnx`
   (full matrix, frequency-ordered, truncation manifest), eval
   truncated views against the shipped tiers; adopt only if equal or
   better; registry ids unchanged.
4. Record B1/B2 as named milestones inside plan 66 P3 (no separate
   plan files until the core exists).

## Owner gates

New tier names (`nano`), changing the default tier, any new model
licenses (Model2Vec per-model, GitHub Typo Corpus MIT), and anything
requiring network in eval CI — all owner decisions.

## Status

**Adopted 2026-09-02.** Items A1–A4 promote to models-repo execution;
B1–B3 fold into plan 66 P3; C/D items remain gated. Research brief
preserved above for provenance.
