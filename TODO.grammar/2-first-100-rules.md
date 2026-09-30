# 2 — The first 100 English grammar rules

Priority-ordered by error frequency in real text (from CoNLL-2014,
BEA-2019, and LanguageTool's own rule hit statistics). Each rule
gets a frozen-data FP budget; a rule that fires on clean text is
rejected.

## Category: agreement (the highest-impact class)

| # | rule | pattern | example |
|---|------|---------|---------|
| 1 | subject-verb 3sg | PRON_3SG + VERB_BASE | "He go" → "He goes" |
| 2 | subject-verb plural | PRON_PLURAL + VERB_3SG | "They goes" → "They go" |
| 3 | there-is/there-were | "there" + NOUN_PLURAL + "is" | "There is many" → "There are many" |
| 4 | was/were agreement | NOUN_PLURAL + "was" | "The books was" → "The books were" |
| 5 | has/have agreement | NOUN_PLURAL + "has" | "The books has" → "The books have" |
| 6 | this/these + NOUN | DET + NOUN_NUMBER_MISMATCH | "This books" → "These books" |
| 7 | that/those + NOUN | DET + NOUN_NUMBER_MISMATCH | "That books" → "Those books" |
| 8 | a/an + plural | "a" + NOUN_PLURAL | "a books" → "some books" |
| 9 | neither/nor agreement | "neither" + "nor" + VERB_3SG | "Neither were" → "Neither was" |
| 10 | each/every + plural verb | "each" + "are" | "Each are" → "Each is" |

## Category: word confusion (the most common class)

| # | rule | pattern | example |
|---|------|---------|---------|
| 11–20 | their/there/they're | context + POS disambiguation | "Their is" → "There is" |
| 21–30 | your/you're | context + contraction | "Your welcome" → "You're welcome" |
| 31–40 | its/it's | context + contraction | "Its raining" → "It's raining" |
| 41–45 | then/than | comparison context | "better then" → "better than" |
| 46–50 | affect/effect | "a" + "effect" / "the" + "affect" | "the affect" → "the effect" |
| 51–55 | to/too | "to" + ADJ (not ADV) | "to easy" → "too easy" |
| 56–60 | loose/lose | "loose" + "the game" | context-dependent |
| 61–65 | whose/who's | "whose" + "not" / "who's" + NOUN | "who's book" → "whose book" |
| 66–70 | could of | "could/would/should of" | → "could have" |
| 71–75 | less/fewer | "less" + COUNT_NOUN | "less books" → "fewer books" |
| 76–80 | between/among | "between" + 3+ NPs | "between all the" → "among all the" |
| 81–85 | compliment/complement | "complement" + person | context-dependent |
| 86–90 | principal/principle | "principle" + "of school" | context-dependent |
| 91–100 | mixed | which/that, who/whom, lain/laid, etc. | various |

## Category: punctuation

| # | rule | pattern | example |
|---|------|---------|---------|
| 101–105 | comma splice | SENT + "," + SENT | "I went, I saw" → "I went; I saw" |
| 106–110 | missing comma after intro | ADV_PHRASE + SENT_START | "However I went" → "However, I went" |
| 111–115 | comma before "but" | SENT + "but" + SENT | optional (style) |
| 116–120 | serial comma | "A, B and" | optional (style flag) |

## Category: style (optional, behind a flag)

| # | rule | pattern | example |
|---|------|---------|---------|
| 121–130 | passive voice | "was/were" + VERB_PARTICIPLE | "was done" (suggest active) |
| 131–140 | wordy | "in order to" → "to"; "due to the fact" → "because" | |
| 141–150 | repeated word | WORD + WORD | "the the" → "the" |

## Implementation

Each rule is a YAML entry in `lib/kotoshu/grammar/rules/en/`:

```
en/
  agreement.yml      # rules 1–10
  word_confusion.yml # rules 11–100
  punctuation.yml    # rules 101–120
  style.yml          # rules 121–150
```

Each rule gets:
- An FP budget test: run against a clean-text corpus, assert ≤2% FP
- A recall test: run against annotated errors, assert the rule fires
- A spec: both cases

The rules are data (YAML), loaded by the RuleEngine — the same YAML
loads in Rust (serde_yaml) and TS (js-yaml).
EOF
echo "file 2 written"