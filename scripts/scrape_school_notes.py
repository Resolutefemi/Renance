#!/usr/bin/env python3
"""scrape_school_notes - legally harvest class notes for the Renance
school platform and emit bulk-import JSON.

Sources are free Nigerian K-12 note sites whose robots.txt allows content
crawling. Every topic keeps its provenance (source site + URL) and is
normalized to the founder content rule: no long hyphens anywhere.

Adapters:
  classnotes.ng   WordPress /lesson/ pages (sitemap listed in robots.txt)
  flashlearners   WordPress posts (sitemap)
  passnownow      course listing pages (JS-gated content: listing only)

Behavior:
  - single-threaded, 1.2s delay per request, browser UA with contact
  - honors robots.txt (checked at runtime via urllib.robotparser)
  - resumes: pages already in data/school-notes/cache are not refetched
  - output: data/school-notes/<source>/<class>-<subject>-<term>.json
    shaped exactly like the /school/bulk-notes body per class+subject

Usage:
  python3 scripts/scrape_school_notes.py --source classnotes --max-pages 120
  python3 scripts/scrape_school_notes.py --all --max-pages 200
"""
from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.robotparser
from html import unescape
from pathlib import Path
from urllib.parse import urlparse
from urllib.request import Request, urlopen

REPO = Path(__file__).resolve().parents[1]
OUT = REPO / "data" / "school-notes"
CACHE = OUT / "cache"

UA = (
    "RenanceNotesBot/1.0 (+https://renance.com; educational notes sync; "
    "contact ariyooluwafemi487@gmail.com)"
)
DELAY = 1.2

# class slug grammar -> (class name, level)
CLASS_PATTERNS = [
    (r"jss\s*1|js1|jss-one", "JSS 1"),
    (r"jss\s*2|js2|jss-two", "JSS 2"),
    (r"jss\s*3|js3|jss-two|jss-three", "JSS 3"),
    (r"sss\s*1|ss1|sss-one", "SSS 1"),
    (r"sss\s*2|ss2", "SSS 2"),
    (r"sss\s*3|ss3", "SSS 3"),
    (r"primary\s*1|pri\s*1|basic\s*1", "Primary 1"),
    (r"primary\s*2|pri\s*2|basic\s*2", "Primary 2"),
    (r"primary\s*3|pri\s*3|basic\s*3", "Primary 3"),
    (r"primary\s*4|pri\s*4|basic\s*4", "Primary 4"),
    (r"primary\s*5|pri\s*5|basic\s*5", "Primary 5"),
    (r"primary\s*6|pri\s*6|basic\s*6", "Primary 6"),
]

SUBJECT_CANON = [
    (r"basic\s*science", "Basic Science"),
    (r"basic\s*tech", "Basic Technology"),
    (r"computer|ict", "Computer Studies"),
    (r"civic", "Civic Education"),
    (r"business\s*studies", "Business Studies"),
    (r"english", "English Studies"),
    (r"math|mathematic", "Mathematics"),
    (r"social\s*studies", "Social Studies"),
    (r"agricul", "Agricultural Science"),
    (r"home\s*econ", "Home Economics"),
    (r"physical|health\s*ed|p\.?h\.?e", "Physical & Health Education"),
    (r"cultural|creative\s*art", "Cultural & Creative Arts"),
    (r"christian|c\.?r\.?s", "Christian Religious Studies"),
    (r"islamic|i\.?r\.?s", "Islamic Religious Studies"),
    (r"security", "Security Education"),
    (r"french", "French"),
    (r"nigerian\s*language|yoruba|igbo|hausa", "Nigerian Language"),
    (r"physics", "Physics"),
    (r"chemistry", "Chemistry"),
    (r"biology", "Biology"),
    (r"economics", "Economics"),
    (r"geography", "Geography"),
    (r"government", "Government"),
    (r"literature", "Literature-in-English"),
    (r"commerce", "Commerce"),
    (r"financial\s*account|accounting", "Financial Accounting"),
    (r"further\s*math", "Further Mathematics"),
    (r"technical\s*draw", "Technical Drawing"),
]

TERM_PATTERNS = [
    (r"third|3rd|term-?3|t3", 3),
    (r"second|2nd|term-?2|t2", 2),
    (r"first|1st|term-?1|t1", 1),
]

# The founder rule: the long hyphen never ships.
LONG_DASH = re.compile("[\u2010\u2012\u2013\u2014\u2015]")
TAG_RE = re.compile(r"<[^>]+>")
WS_RE = re.compile(r"[ \t]+")
BLANK_RE = re.compile(r"\n{3,}")


def normalize(text: str) -> str:
    text = LONG_DASH.sub("-", text)
    text = re.sub(r"[ \t]*-[ \t]*-{2,}[ \t]*", " - ", text)  # stray runs
    return text


def fetch(url: str, robots: urllib.robotparser.RobotFileParser | None) -> bytes | None:
    if robots and not robots.can_fetch(UA, url):
        print(f"  robots disallow: {url}")
        return None
    key = CACHE / (re.sub(r"[^a-z0-9]+", "_", url.lower())[-180:] + ".html")
    if key.exists() and key.stat().st_size > 0:
        return key.read_bytes()
    try:
        req = Request(url, headers={"User-Agent": UA, "Accept-Language": "en"})
        with urlopen(req, timeout=30) as r:
            data = r.read()
        time.sleep(DELAY)
        key.write_bytes(data)
        return data
    except Exception as e:  # noqa: BLE001 - scraper must survive flaky hosts
        print(f"  fetch failed ({e}): {url}")
        return None


def strip_html(fragment: str) -> str:
    """HTML -> readable plain text (paragraphs preserved)."""
    fragment = re.sub(r"<script.*?</script>|<style.*?</style>", "", fragment, flags=re.S | re.I)
    fragment = re.sub(r"<(br|/p|/li|/h[1-6]|/div)[^>]*>", "\n", fragment, flags=re.I)
    fragment = re.sub(r"<li[^>]*>", "\n- ", fragment, flags=re.I)
    text = TAG_RE.sub("", fragment)
    text = unescape(text)
    lines = [WS_RE.sub(" ", ln).strip() for ln in text.splitlines()]
    text = "\n".join(ln for ln in lines if ln)
    return BLANK_RE.sub("\n\n", normalize(text)).strip()


def canon_class(text: str) -> str | None:
    low = text.lower()
    for pat, name in CLASS_PATTERNS:
        if re.search(pat, low):
            return name
    return None


def canon_subject(text: str) -> str | None:
    low = text.lower()
    best = None
    for pat, name in SUBJECT_CANON:
        if re.search(pat, low):
            best = name  # later patterns are more specific
            break
    return best


def canon_term(text: str) -> int:
    low = text.lower()
    for pat, n in TERM_PATTERNS:
        if re.search(pat, low):
            return n
    return 1


def entry_content(html: str) -> str:
    """WordPress main article body."""
    m = re.search(
        r"<div[^>]*class=\"[^\"]*(?:entry-content|elementor-widget-theme-post-content|post-content)[^\"]*\"[^>]*>(.*)",
        html,
        flags=re.S | re.I,
    )
    frag = m.group(1) if m else html
    # cut at comments / related-posts noise
    for stop in ("</article>", "id=\"comments", "class=\"comments", "class=\"related"):
        idx = frag.lower().find(stop.lower())
        if idx > 500:
            frag = frag[:idx]
    return strip_html(frag)


def locs(xml: bytes) -> list[str]:
    return re.findall(rb"<loc>\s*([^<\s]+)\s*</loc>", xml)


def urls_from_sitemaps(index_urls: list[str], host: str, filter_re: re.Pattern, robots, limit: int) -> list[str]:
    out: list[str] = []
    seen: set[str] = set()
    for index_url in index_urls:
        idx = fetch(index_url, robots)
        if not idx:
            continue
        subs = [u.decode() for u in locs(idx)]
        posts = [u for u in subs if u.endswith(".xml")]
        if posts:
            for p in posts[:12]:
                if len(out) >= limit:
                    break
                data = fetch(p, robots)
                if not data:
                    continue
                for u in (x.decode() for x in locs(data)):
                    if filter_re.search(u) and u not in seen:
                        seen.add(u)
                        out.append(u)
                        if len(out) >= limit:
                            break
        else:
            for u in (x.decode() for x in locs(idx)):
                if filter_re.search(u) and u not in seen:
                    seen.add(u)
                    out.append(u)
                    if len(out) >= limit:
                        break
        if len(out) >= limit:
            break
    _ = host
    return out


def slug_fields(url: str):
    """('subject-jss1-first-term', ...) -> (class, subject, term)."""
    slug = urlparse(url).path.strip("/").split("/")[-1]
    text = slug.replace("-", " ")
    cls = canon_class(text)
    subj = canon_subject(text)
    term = canon_term(text)
    return slug, cls, subj, term


def parse_classnotes(html: bytes, url: str):
    text = html.decode("utf-8", errors="replace")
    title = ""
    t = re.search(r"<title>(.*?)</title>", text, re.S | re.I)
    if t:
        title = strip_html(t.group(1))
    slug, cls, subj, term = slug_fields(url)
    if not (cls and subj):
        return None
    content = entry_content(text)
    if len(content) < 200:
        return None
    return {
        "class": cls,
        "subject": subj,
        "term": term,
        "title": title or slug,
        "content": content[:20000],
        "source": "classnotes.ng",
        "sourceUrl": url,
    }


def parse_flashlearners(html: bytes, url: str):
    text = html.decode("utf-8", errors="replace")
    slug, cls, subj, term = slug_fields(url)
    if not (cls and subj):
        return None
    content = entry_content(text)
    if len(content) < 200:
        return None
    return {
        "class": cls,
        "subject": subj,
        "term": term,
        "title": subj + " - " + cls + " (flashlearners)",
        "content": content[:20000],
        "source": "flashlearners.com",
        "sourceUrl": url,
    }


def parse_edudelight(html: bytes, url: str):
    """edudelight.com lesson notes (WordPress). Same respectful rules as
    the other adapters: robots.txt is honored upstream in fetch(), every
    topic keeps its source URL, and the long-hyphen rule applies."""
    text = html.decode("utf-8", errors="replace")
    slug, cls, subj, term = slug_fields(url)
    if not (cls and subj):
        return None
    content = entry_content(text)
    if len(content) < 200:
        return None
    return {
        "class": cls,
        "subject": subj,
        "term": term,
        "title": subj + " - " + cls + " (edudelight)",
        "content": content[:20000],
        "source": "edudelight.com",
        "sourceUrl": url,
    }


def run(source: str, max_pages: int):
    CACHE.mkdir(parents=True, exist_ok=True)
    configs = {
        # Postponed per the founder: classnotes stays available explicitly
        # but is out of the weekly rotation.
        "classnotes": {
            "host": "https://www.classnotes.ng",
            "sitemap": ["https://www.classnotes.ng/sitemap_index.xml"],
            "lesson": re.compile(r"classnotes\.ng/lesson/"),
            "parser": parse_classnotes,
        },
        "flashlearners": {
            "host": "https://flashlearners.com",
            "sitemap": ["https://flashlearners.com/sitemap_index.xml"],
            "lesson": re.compile(r"flashlearners\.com/(jss|sss|primary|basic|english|math|civic|computer|business|social|agricul)"),
            "parser": parse_flashlearners,
        },
        "edudelight": {
            "host": "https://edudelight.com",
            "sitemap": ["https://edudelight.com/sitemap_index.xml", "https://edudelight.com/wp-sitemap.xml"],
            "lesson": re.compile(r"edudelight\.com/(jss|sss|primary|basic|lesson|notes|class)"),
            "parser": parse_edudelight,
        },
    }
    cfg = configs[source]
    robots = urllib.robotparser.RobotFileParser()
    robots.parse(fetch(cfg["host"] + "/robots.txt", None).decode().splitlines() if True else [])

    urls = urls_from_sitemaps(cfg["sitemap"], cfg["host"], cfg["lesson"], robots, max_pages)
    print(f"{source}: {len(urls)} candidate lesson urls")

    buckets: dict[tuple, list] = {}
    ok = 0
    for u in urls:
        data = fetch(u, robots)
        if not data:
            continue
        try:
            item = cfg["parser"](data, u)
        except Exception as e:  # noqa: BLE001
            print(f"  parse failed: {u} ({e})")
            continue
        if not item:
            continue
        key = (item["class"], item["subject"], item["term"])
        buckets.setdefault(key, [])
        if len(buckets[key]) >= 40:
            continue
        # per-lesson entry: title = first meaningful heading-ish line
        first_line = item["content"].splitlines()[0][:120] if item["content"] else item["title"]
        buckets[key].append(
            {
                "title": first_line,
                "week": len(buckets[key]) + 1,
                "content": item["content"],
                "source": item["source"],
                "sourceUrl": item["sourceUrl"],
            }
        )
        ok += 1
        print(f"  captured [{key[0]} / {key[1]} / T{key[2]}] {u}")

    dest = OUT / source
    dest.mkdir(parents=True, exist_ok=True)
    files = 0
    for (cls, subj, term), topics in sorted(buckets.items()):
        payload = {
            "class": cls,
            "subject": subj,
            "term": term,
            "session": "",
            "overwrite": False,
            "provenance": {
                "source": topics[0]["source"],
                "method": "respectful crawl, robots.txt honored, credited per topic",
            },
            "topics": topics,
        }
        fname = f"{cls.lower().replace(' ', '')}-{subj.lower().replace(' ', '-')}-term{term}.json"
        (dest / fname).write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        files += 1
    print(f"{source}: wrote {files} corpus file(s), {ok} topics")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--source", choices=["classnotes", "flashlearners", "edudelight"])
    ap.add_argument("--all", action="store_true", help="the active weekly sources (classnotes is postponed)")
    ap.add_argument("--max-pages", type=int, default=150)
    args = ap.parse_args()
    # Active rotation: flashlearners + edudelight. classnotes is postponed
    # until its robots/permissions posture is re-checked; it stays
    # selectable with an explicit --source classnotes.
    sources = ["flashlearners", "edudelight"] if args.all else ([args.source] if args.source else [])
    if not sources:
        ap.error("pick --source or --all")
    for s in sources:
        try:
            run(s, args.max_pages)
        except Exception as e:  # noqa: BLE001
            print(f"{s} run failed: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
