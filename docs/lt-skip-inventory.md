# LT rule-skip inventory (2026-10-30, LT master grammar.xml, en)

Measured with scripts/lt_convert.rb on grammar/lt-loader (branch):
5,556 LT en rules -> 2,762 converted (49.7%), 2,794 skipped.

## Skip reasons (expansion targets ranked)
1. inflected 689 + antipattern_inflected 258 = **947** -- hunspell-inflected
   expansion (#204): expand ENTITY tokens via morphological synthesizer
2. empty_token 626 + antipattern_empty_token 422 = 1,048 -- zero-width token
   edges; needs matcher support for optional-before/after
3. chunk/phrasename 172+71 = 243 -- chunk-parse dependency (out of engine scope)
4. no_pattern 135 / no_message 125 -- incomplete LT sources, skip stays
5. postag 88+70+44 = 202 -- pos_mapper coverage growth
6. repeat_range 39+33 = 72 -- quantifier range support in recursive matcher

Priority: bucket 1 (#204 proper) -> bucket 6 (small matcher feature) -> bucket 5.
