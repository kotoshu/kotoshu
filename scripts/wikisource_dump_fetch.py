"""Acquire public-domain sentence corpora from Wikisource STATIC DUMPS
(dumps.wikimedia.org) — the API walker (wikisource_corpus_fetch.py) is
IP-throttled (429 persists a day later); static dump downloads are not
API requests and are not throttled.

Stream-parse the pages-articles XML.bz2 (no full decompress), keep
main-namespace pages (ns 0), strip wikitext to plaintext, sentence-split
with the same filters as the API walker, budget-capped, sources manifest
(page titles) for provenance.

Usage:
  python3 wikisource_dump_fetch.py --lang nl \
      --dump https://dumps.wikimedia.org/nlwikisource/latest/nlwikisource-latest-pages-articles.xml.bz2 \
      --budget-words 400000 \
      --out ~/.cache/kotoshu-gec/corpora/base_nl.txt \
      --sources ~/.cache/kotoshu-gec/corpora/nl_sources_ws.json
"""
import argparse, bz2, json, re, sys
import urllib.request

UA = "kotoshu-corpus-builder/1.0 (kotoshu spell-check research; contact ribose.org)"

PAGE_RE = re.compile(r"<page>(.*?)</page>", re.S)
TITLE_RE = re.compile(r"<title>(.*?)</title>", re.S)
NS_RE = re.compile(r"<ns>(\d+)</ns>")
TEXT_RE = re.compile(r"<text[^>]*>(.*?)</text>", re.S)


def fetch(url, out_path):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=120) as resp, open(out_path, "wb") as f:
        total, done = int(resp.headers.get("Content-Length", 0)), 0
        while True:
            chunk = resp.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
            done += len(chunk)
            if total and done % (50 << 20) < (1 << 20):
                print(f"  download {done >> 20}MB / {total >> 20}MB", flush=True)
    return out_path


def wiki_to_text(raw):
    raw = re.sub(r"<!--.*?-->", " ", raw, flags=re.S)
    raw = re.sub(r"<ref[^>/]*/>", " ", raw)
    raw = re.sub(r"<ref[^>]*>.*?</ref>", " ", raw, flags=re.S)
    # nested templates: unfold smallest-first until none remain
    prev = None
    while prev != raw:
        prev = raw
        raw = re.sub(r"\{\{[^{}]*\}\}", " ", raw)
    raw = re.sub(r"\[\[(?:[^|\]]*\|)?([^\]]+)\]\]", r"\1", raw)
    raw = re.sub(r"\[https?://\S+\s+([^\]]+)\]", r"\1", raw)
    raw = re.sub(r"\[https?://\S+\]", " ", raw)
    raw = re.sub(r"'''?", "", raw)
    raw = re.sub(r"<[^>]+>", " ", raw)
    raw = re.sub(r"^\s*[{|}].*$", " ", raw, flags=re.M)  # tables/misc markup lines
    raw = re.sub(r"^=+\s*[^=]*\s*=+\s*$", " ", raw, flags=re.M)
    raw = re.sub(r"^[:*#;].*$", " ", raw, flags=re.M)
    raw = re.sub(r"\s+", " ", raw)
    return raw


def sentences_from(text):
    out = []
    for s in re.split(r"(?<=[.!?])\s+", text):
        toks = s.strip().split()
        if 4 <= len(toks) <= 40 and len(s) >= 25:
            out.append(" ".join(toks))
    return out


def iter_pages(xml_path):
    with bz2.open(xml_path, "rt", encoding="utf-8", errors="ignore") as f:
        buf = []
        for line in f:
            buf.append(line)
            if "</page>" in line:
                chunk = "".join(buf)
                buf = []
                m = PAGE_RE.search(chunk)
                if not m:
                    continue
                yield m.group(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--lang", required=True)
    ap.add_argument("--dump", required=True)
    ap.add_argument("--budget-words", type=int, default=400000)
    ap.add_argument("--min-sents-per-page", type=int, default=100)
    ap.add_argument("--out", required=True)
    ap.add_argument("--sources", required=True)
    a = ap.parse_args()

    xml_path = a.out + ".dump.xml.bz2"
    if len(sys.argv) > 1 and __import__("os").path.exists(xml_path) and __import__("os").path.getsize(xml_path) > 0:
        print(f"reusing cached dump {xml_path}")
    else:
        print(f"downloading {a.dump}", flush=True)
        fetch(a.dump, xml_path)
        print(f"downloaded {__import__('os').path.getsize(xml_path) >> 20}MB", flush=True)

    sources, sentences, total, pages_kept, pages_seen = [], [], 0, 0, 0
    for page in iter_pages(xml_path):
        pages_seen += 1
        ns = NS_RE.search(page)
        if not ns or ns.group(1) != "0":
            continue
        tm = TITLE_RE.search(page)
        xm = TEXT_RE.search(page)
        if not xm or not tm:
            continue
        sents = sentences_from(wiki_to_text(xm.group(1)))
        if len(sents) < a.min_sents_per_page:
            continue
        take = sents
        if total + len(sents) * 25 > a.budget_words:
            take = sents[:max(0, (a.budget_words - total) * 40 // 25 // 40) or 50]
        if not take:
            break
        sentences.extend(take)
        total += sum(len(s.split()) for s in take)
        pages_kept += 1
        sources.append({"title": tm.group(1), "host": "dumps.wikimedia.org",
                        "sentences": len(take)})
        if pages_kept % 10 == 0:
            print(f"  {pages_seen} pages seen, {pages_kept} kept, ~{total} words", flush=True)
        if total >= a.budget_words:
            break

    uniq = sorted(set(sentences))
    open(a.out, "w", encoding="utf-8").write("\n".join(uniq) + "\n")
    json.dump({"language": a.lang, "source": a.dump,
               "budget_words": a.budget_words, "pages_seen": pages_seen,
               "pages_kept": pages_kept, "sources": sources},
              open(a.sources, "w"), indent=1, ensure_ascii=False)
    print(f"done: {len(uniq)} unique sentences ~{total} words "
          f"({pages_seen} seen / {pages_kept} kept) -> {a.out}", flush=True)


if __name__ == "__main__":
    main()
