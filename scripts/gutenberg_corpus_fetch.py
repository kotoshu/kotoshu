"""Acquire public-domain sentence corpora for the Latin wave
(it/nl/pl/pt) from Project Gutenberg's per-language browse indexes.

License: Project Gutenberg books in these indexes are public domain
worldwide (PG's own terms apply to the hosting, not the texts). We
record source ids + titles per pack for provenance.

Usage:
  python3 wikisource_gutenberg_fetch.py --lang it --budget-words 400000 \
      --out /tmp/corpora/it_sentences.txt --sources /tmp/corpora/it_sources.json
"""
import argparse, html, json, random, re, sys, time
import urllib.request

UA = "kotoshu-corpus-builder/1.0 (kotoshu spell-check research; contact ribose.org)"
BROWSE = "https://www.gutenberg.org/browse/languages/{lang}"
TXT = "https://www.gutenberg.org/cache/epub/{id}/pg{id}.txt"


def get(url, timeout=60):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    return urllib.request.urlopen(req, timeout=timeout).read()


def book_ids_from_index(lang):
    page = get(BROWSE.format(lang=lang)).decode("utf-8", "ignore")
    ids = re.findall(r"/ebooks/(\d+)", page)
    seen, ordered = set(), []
    for i in ids:
        if i not in seen:
            seen.add(i)
            ordered.append(i)
    return ordered


def fetch_book(book_id):
    raw = get(TXT.format(id=book_id)).decode("utf-8", "ignore")
    # strip the PG header/footer boilerplate
    m = re.search(r"\*\*\*\s*START OF (?:THE|THIS) PROJECT GUTENBERG EBOOK.*?\*\*\*",
                  raw, re.I)
    if m:
        raw = raw[m.end():]
    m = re.search(r"\*\*\*\s*END OF (?:THE|THIS) PROJECT GUTENBERG EBOOK", raw, re.I)
    if m:
        raw = raw[:m.start()]
    return raw


def sentences_from(text):
    text = re.sub(r"\s+", " ", text)
    parts = re.split(r"(?<=[.!?])\s+", text)
    out = []
    for s in parts:
        toks = s.strip().split()
        if 4 <= len(toks) <= 40 and len(toks) >= 12:
            out.append(" ".join(toks))
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", required=True)
    ap.add_argument("--budget-words", type=int, default=400000)
    ap.add_argument("--max-books", type=int, default=25)
    ap.add_argument("--out", required=True)
    ap.add_argument("--sources", required=True)
    a = ap.parse_args()

    ids = book_ids_from_index(a.lang)
    print(f"{a.lang}: {len(ids)} index entries; fetching up to {a.max_books} books")
    rng = random.Random(20261119)
    picked = ids[:a.max_books] if len(ids) <= a.max_books else rng.sample(ids, a.max_books)
    sources, sentences, total = [], [], 0
    for bid in picked:
        try:
            raw = fetch_book(bid)
        except Exception as e:
            print(f"  book {bid}: skip ({str(e)[:40]})")
            continue
        sents = sentences_from(raw)
        if len(sents) < 200:
            continue
        take = sents if total + len(sents) <= a.budget_words else sents[:max(0, (a.budget_words - total) * 40 // 25)]
        sentences.extend(take)
        total += sum(len(s.split()) for s in take)
        sources.append({"gutenberg_id": bid, "sentences": len(take)})
        print(f"  book {bid}: +{len(take)} sentences (total words ~{total})")
        if total >= a.budget_words:
            break
        time.sleep(1)
    uniq = sorted(set(sentences))
    open(a.out, "w", encoding="utf-8").write("\n".join(uniq) + "\n")
    json.dump({"language": a.lang, "budget_words": a.budget_words,
               "sources": sources}, open(a.sources, "w"), indent=1)
    print(f"done: {len(uniq)} unique sentences, ~{total} words -> {a.out}")


if __name__ == "__main__":
    main()
