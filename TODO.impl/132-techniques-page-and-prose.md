# Plan 132 — The techniques page; professional prose across the site

Status: executed (2026-09-12, site push; this plan)

## What shipped

1. /docs/techniques — a complete catalog of the stack's techniques in
   four groups (engines, models, delivery, reliability), each entry
   naming the mechanism and its measured effect in full sentences.
   Written as the site's first MDX page: @astrojs/mdx installed and
   wired, DocsLayout applied through an imported component wrapper.
2. A professional rewrite of the published copy: 34 fragment-style
   news titles became declarative sentences, and 69 fragment-stacked
   summaries and senses across all 36 entries were rewritten as full
   sentences with clear subjects. The worst patterns eliminated:
   em-dash fragment leads ("What 1.0 freezes:"), colon-list openers
   ("Also in the patch:"), trailing fragment appends ("— no download,
   no CI seeding"), and lowercase clause starts.
3. The docs pages received the same treatment where fragments
   appeared: the performance error-budget section, the caching
   language-packs section, and three headlines.

## Conventions established

- Text-heavy documentation pages are written in MDX, not .astro HTML.
- News titles are complete clauses; summaries and senses are full
  sentences. Release titles use the "package X.Y.Z: description" form.
