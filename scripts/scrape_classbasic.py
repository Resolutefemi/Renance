#!/usr/bin/env python3
"""scrape_classbasic - harvest lesson notes, schemes of work and exam
questions from classbasic.com (ClassRoomNotes) into Renance bulk-import
corpora.

Why this source: classbasic.com publishes Nigerian basic-education
lesson notes, week-by-week schemes of work and per-term examination
papers, and its robots.txt allows every crawler (only AI-training bots
are named out). The site serves its pages to mobile and tablet browsers
only, so the fetch presents a mobile browser UA that still carries the
Renance contact string. Every harvested row keeps its source URL, and
the founder's no-long-hyphen rule is enforced on every text field.

Corpora written (all under data/):
  data/school-notes/classbasic/<file>.json    -> POST /school/bulk-notes
  data/school-schemes/classbasic/<file>.json  -> POST /school/bulk-schemes
  data/school-exams/classbasic/<file>.json    -> POST /school/bulk-exam-questions

Exam answer keys are not published on the source pages, so every
harvested question ships answerIndex = -1 ("key pending, teacher to
set"). The bulk exam endpoint accepts -1 and the portal marks such
questions for teacher review; nothing auto-grades them.

Usage:
  python3 scripts/scrape_classbasic.py --kinds schemes --max-pages 500
  python3 scripts/scrape_classbasic.py --kinds exams --max-pages 800
  python3 scripts/scrape_classbasic.py --kinds notes --max-pages 400
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
OUT_NOTES = REPO / "data" / "school-notes" / "classbasic"
OUT_SCHEMES = REPO / "data" / "school-schemes" / "classbasic"
OUT_EXAMS = REPO / "data" / "school-exams" / "classbasic"
CACHE = REPO / "data" / "school-notes" / "cache"

# The site gates desktop agents; a mobile browser identity with our bot
# contact appended is what any tablet visitor would present.
UA = (
    "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) "
    "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 "
    "Safari/604.1 RenanceNotesBot/1.0 (+https://renance.com; "
    "educational notes sync; contact ariyooluwafemi487@gmail.com)"
)
DELAY = 1.2

SOURCE = "classbasic.com"
PROVENANCE = {
    "source": SOURCE,
    "method": (
        "respectful crawl, robots.txt honored, mobile UA as the site "
        "serves, credited per item, exam keys left to teachers"
    ),
}

LONG_DASH = re.compile("[\u2010\u2012\u2013\u2014\u2015]")
WS_RE = re.compile(r"[ \t]+")
BLANK_RE = re.compile(r"\n{3,}")

STOPS = (
    "share this", "related posts", "post navigation", "leave a reply",
    "previous article", "next article", "tagged", "pdf download",
    "click here to download", "about the author", "copyright",
)

CLASS_PATTERNS = [
    (r"\bbasic[- ]?9\b|\bjss[- ]?3\b|\bjs3\b", "JSS 3"),
    (r"\bbasic[- ]?8\b|\bjss[- ]?2\b|\bjs2\b", "JSS 2"),
    (r"\bbasic[- ]?7\b|\bjss[- ]?1\b|\bjs1\b", "JSS 1"),
    (r"\bbasic[- ]?6\b|\bprimary[- ]?6\b|\bpri[- ]?6\b", "Primary 6"),
    (r"\bbasic[- ]?5\b|\bprimary[- ]?5\b|\bpri[- ]?5\b", "Primary 5"),
    (r"\bbasic[- ]?4\b|\bprimary[- ]?4\b|\bpri[- ]?4\b", "Primary 4"),
    (r"\bbasic[- ]?3\b|\bprimary[- ]?3\b|\bpri[- ]?3\b", "Primary 3"),
    (r"\bbasic[- ]?2\b|\bprimary[- ]?2\b|\bpri[- ]?2\b", "Primary 2"),
    (r"\bbasic[- ]?1\b|\bprimary[- ]?1\b|\bpri[- ]?1\b", "Primary 1"),
]

# Ordered, most specific first. `level` says which catalog name to use
# when the primary and junior bands name the subject differently.
SUBJECT_PATTERNS = [
    (r"basic\s*science\s*(?:and|&)?\s*technology", ("Basic Science & Technology", "Basic Science")),
    (r"national\s*values", "National Values Education"),
    (r"pre\s*-?vocational", "Pre-vocational Studies"),
    (r"cultural\s*(?:and|&)?\s*creative\s*arts?", "Cultural & Creative Arts"),
    (r"christian\s*religious|c\.?r\.?s\b", "Christian Religious Studies"),
    (r"islamic\s*religious|i\.?r\.?s\b", "Islamic Religious Studies"),
    (r"social\s*studies", "Social Studies"),
    (r"civic", "Civic Education"),
    (r"security\s*education", "Security Education"),
    (r"business\s*studies", "Business Studies"),
    (r"computer\s*studies|information\s*technology|computer\s*(?:science|ict)", ("Computer Studies", "Computer Studies")),
    (r"home\s*economics|home\s*mak", "Home Economics"),
    (r"agric(?:ul(?:tural)?)?(?:\s*science)?", "Agricultural Science"),
    (r"physical(?:\s*(?:and|&))?\s*health|\bp\.?h\.?e\b", "Physical & Health Education"),
    (r"literature(?:\s*in)?(?:\s*english)?", "Literature-in-English"),
    (r"english\s*(?:studies|language|structure)|\benglish\b", "English Studies"),
    (r"quantitative\s*reasoning", "Quantitative Reasoning"),
    (r"verbal\s*reasoning", "Verbal Reasoning"),
    (r"math(?:ematic)?s?", "Mathematics"),
    (r"\byoruba\b|\bigbo\b|\bhausa\b|\bnigerian\s*language\b", "Nigerian Language"),
    (r"french", "French"),
    (r"economics", "Economics"),
    (r"government", "Government"),
    (r"geography", "Geography"),
    (r"\bcommerce\b", "Commerce"),
    (r"financial\s*account|accounting", "Financial Accounting"),
    (r"further\s*(?:math|mathe)", "Further Mathematics"),
    (r"technical\s*draw", "Technical Drawing"),
    (r"\bphysics\b", "Physics"),
    (r"\bchemistry\b", "Chemistry"),
    (r"\bbiolog\b", "Biology"),
    (r"basic\s*tech", "Basic Technology"),
]

TERM_PATTERNS = [
    (r"third|3rd", 3),
    (r"second|2nd", 2),
    (r"first|1st", 1),
]

JUNK_RE = re.compile(
    r"holiday|mid-?term-?(?:break|test)?-?(?:and-?break)?|news|date|forms?"
    r"|brochure|school-fees|lists?-of|amount|vacanc|admission|cut-?off|"
    r"nursery|kg\b|age-|workbook-?(?:assessment)?-?mid"
)


def normalize(text: str) -> str:
    text = LONG_DASH.sub("-", text)
    text = re.sub(r"[ \t]*-[ \t]*-{2,}[ \t]*", " - ", text)
    return text


def fetch(url: str, robots: urllib.robotparser.RobotFileParser) -> bytes | None:
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
    except Exception as e:  # noqa: BLE001
        print(f"  fetch failed ({e}): {url}")
        return None


def to_lines(fragment: str) -> list[str]:
    fragment = re.sub(r"<script.*?</script>|<style.*?</style>", "", fragment, flags=re.S | re.I)
    fragment = re.sub(r"</t[dh]>", " | ", fragment, flags=re.I)
    fragment = re.sub(r"<(br|/p|/li|/h[1-6]|/tr|/div)[^>]*>", "\n", fragment, flags=re.I)
    fragment = re.sub(r"<li[^>]*>", "\n- ", fragment, flags=re.I)
    text = unescape(re.sub(r"<[^>]+>", "", fragment))
    lines = [WS_RE.sub(" ", ln).strip() for ln in text.splitlines()]
    return [ln for ln in lines if ln]


def article_after_h1(html: str) -> tuple[str, list[str]]:
    """Title from the h1, body lines from after the h1, cut at footer noise."""
    m = re.search(r"<h1[^>]*>(.*?)</h1>", html, flags=re.S | re.I)
    title = normalize(unescape(re.sub(r"<[^>]+>", "", m.group(1)))).strip() if m else ""
    lines = to_lines(html[m.end():] if m else html)
    end = len(lines)
    for i, ln in enumerate(lines):
        low = ln.lower()
        if any(s in low for s in STOPS):
            end = i
            break
    return title, lines[:end]


def slug_of(url: str) -> str:
    return urlparse(url).path.strip("/").split("/")[-1]


def canon_class(slug: str) -> str | None:
    for pat, name in CLASS_PATTERNS:
        if re.search(pat, slug):
            return name
    return None


def canon_term(slug: str) -> int:
    for pat, n in TERM_PATTERNS:
        if re.search(pat, slug):
            return n
    return 1


def canon_subject(slug: str, cls: str) -> str | None:
    low = slug.replace("-", " ")
    for pat, name in SUBJECT_PATTERNS:
        if re.search(pat, low):
            if isinstance(name, tuple):
                # (primary-name, junior-name)
                name = name[0] if cls.startswith("Primary") else name[1]
            return name
    return None


def is_junk(slug: str) -> bool:
    return bool(JUNK_RE.search(slug))


def scheme_lines(lines: list[str]) -> list[dict]:
    """Pull WEEK n -> TOPIC -> CONTENT rows out of a scheme-of-work page.

    A scheme row keeps the topic plus the content bullets under it; the
    bullets are what make a scheme a usable syllabus draft (the topic is
    the row, the bullets become the topic's note seed).
    """
    start = None
    for i, ln in enumerate(lines):
        if re.match(r"^scheme\s+of\s+work$", ln.strip(), re.I):
            start = i
            break
    if start is None:
        return []
    weeks: list[dict] = []
    cur: dict | None = None
    for raw in lines[start + 1:]:
        ln = raw.strip().strip("|").strip()
        if not ln:
            continue
        low = ln.lower()
        m = re.match(r"^week\s*(\d{1,2})\b", low)
        if m:
            if cur and cur.get("topic"):
                weeks.append(cur)
            cur = {"week": int(m.group(1)), "topic": "", "content": []}
            continue
        if cur is None:
            continue
        tm = re.match(r"^(?:topic|lesson)\s*(?:[-:]|\u2013)?\s*(.+)$", ln, re.I)
        if tm and not cur["topic"]:
            cur["topic"] = normalize(tm.group(1)).strip(" |")[:300]
            continue
        # content bullets carry the real syllabus detail
        if low.startswith("content") or low.startswith("contents"):
            continue
        if re.match(r"^(?:theme|instructional|reference|materials?)\b", low):
            continue
        if re.match(r"^(?:revision|examination|test)\b", low) and not cur["topic"]:
            cur["topic"] = normalize(ln)[:300]
            continue
        bullet = ln.lstrip("-\u2022 ").strip()
        if bullet and len(cur["content"]) < 20 and len(bullet) > 2:
            cur["content"].append(normalize(bullet)[:300])
    if cur and cur.get("topic"):
        weeks.append(cur)
    return [w for w in weeks if w["topic"]]


def exam_questions(lines: list[str]) -> list[dict]:
    """Parse SECTION A style MCQs. No answer keys exist on the source,
    so every question ships answerIndex = -1 for teacher review."""
    body: list[str] = []
    in_a = False
    for ln in lines:
        up = ln.upper()
        if "SECTION A" in up:
            in_a = True
            continue
        if "SECTION B" in up or "SECTION C" in up:
            break
        if in_a:
            body.append(ln)
    if not body:
        return []
    q_re = re.compile(r"^(\d{1,2})[.)]\s*(.*)$")
    o_re = re.compile(r"^\(?([a-eA-E])\)?[.)]\s*(.*)$")
    questions: list[dict] = []
    cur: dict | None = None
    for ln in body:
        mq = q_re.match(ln)
        mo = o_re.match(ln)
        if mq:
            if cur and len(cur["options"]) >= 2:
                questions.append(cur)
            cur = {"question": normalize(mq.group(2)).strip(), "options": []}
            continue
        if mo and cur is not None:
            opt = normalize(mo.group(2)).strip()
            if opt and len(cur["options"]) < 6:
                cur["options"].append(opt)
            continue
        if cur is not None and cur["options"] == [] and ln and not re.match(r"^[A-Z\s]+$", ln):
            # continuation of the question stem
            if len(cur["question"]) < 400:
                cur["question"] = (cur["question"] + " " + normalize(ln)).strip()
    if cur and len(cur["options"]) >= 2:
        questions.append(cur)
    return [
        {
            "question": q["question"][:600],
            "options": q["options"],
            "answerIndex": -1,
            "source": SOURCE,
            "sourceUrl": "",
        }
        for q in questions
        if q["question"] and len(q["question"]) > 8
    ]


def urls_from_sitemaps(robots, limit: int, kinds: list[str]) -> list[str]:
    want_scheme = "schemes" in kinds
    want_exam = "exams" in kinds
    want_note = "notes" in kinds

    def classify(slug: str) -> str | None:
        if slug.startswith("scheme-of-work") or "scheme-of-work" in slug:
            return "schemes" if want_scheme else None
        if "examination" in slug or "exam-questions" in slug:
            return "exams" if want_exam else None
        return "notes" if want_note else None

    out: list[str] = []
    seen: set[str] = set()
    idx = fetch("https://classbasic.com/sitemap_index.xml", robots)
    if not idx:
        return out
    subs = [u.decode() for u in re.findall(rb"<loc>\s*([^<\s]+)</loc>", idx)]
    for sub in subs:
        if len(out) >= limit:
            break
        if "post-sitemap" not in sub:
            continue
        data = fetch(sub, robots)
        if not data:
            continue
        for u in (x.decode() for x in re.findall(rb"<loc>\s*([^<\s]+)</loc>", data)):
            if len(out) >= limit:
                break
            slug = slug_of(u)
            if slug in seen or is_junk(slug):
                continue
            kind = classify(slug)
            if not kind:
                continue
            cls = canon_class(slug)
            if cls is None and kind != "notes":
                continue
            # notes need a class bucket too; exam/scheme need subject
            if cls is None:
                continue
            seen.add(slug)
            out.append(u)
    return out


def slug_file(name: str) -> str:
    return re.sub(r"[^a-z0-9-]+", "-", name.lower()).strip("-")


def write_corpora(buckets: dict, kind: str) -> int:
    files = 0
    for (cls, subj, term), items in sorted(buckets.items()):
        if not items:
            continue
        fname = f"{slug_file(cls)}-{slug_file(subj)}-term{term}.json"
        if kind == "notes":
            payload = {
                "class": cls, "subject": subj, "term": term, "session": "",
                "overwrite": False, "provenance": PROVENANCE, "topics": items,
            }
            dest = OUT_NOTES / fname
        elif kind == "schemes":
            payload = {
                "class": cls, "subject": subj, "term": term,
                "weeks": [
                    {"week": w["week"], "topic": w["topic"],
                     "content": "\n".join(w.get("content", []))}
                    for w in items
                ],
                "provenance": PROVENANCE,
            }
            dest = OUT_SCHEMES / fname
        else:
            payload = {
                "class": cls, "subject": subj, "term": term,
                "band": "primary" if cls.startswith("Primary") else "junior",
                "questions": items, "provenance": PROVENANCE,
            }
            dest = OUT_EXAMS / fname
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        files += 1
    return files


def run(kinds: list[str], max_pages: int) -> None:
    CACHE.mkdir(parents=True, exist_ok=True)
    robots = urllib.robotparser.RobotFileParser()
    robots_txt = fetch("https://classbasic.com/robots.txt", None)
    robots.parse(robots_txt.decode().splitlines() if robots_txt else [])

    urls = urls_from_sitemaps(robots, max_pages, kinds)
    print(f"classbasic: {len(urls)} candidate urls for kinds={kinds}")

    nb: dict[tuple, list] = {}
    sb: dict[tuple, list] = {}
    eb: dict[tuple, list] = {}
    ok = 0
    for u in urls:
        data = fetch(u, robots)
        if not data:
            continue
        html = data.decode("utf-8", errors="replace")
        slug = slug_of(u)
        cls = canon_class(slug)
        if not cls:
            continue
        term = canon_term(slug)
        subj = canon_subject(slug, cls)
        if not subj:
            continue
        title, lines = article_after_h1(html)
        if len(lines) < 8:
            continue
        if slug.startswith("scheme-of-work") or "scheme-of-work" in slug:
            weeks = scheme_lines(lines)
            if not weeks:
                continue
            key = (cls, subj, term)
            existing = {(w["week"], w["topic"]) for w in sb.get(key, [])}
            for w in weeks:
                if (w["week"], w["topic"]) not in existing and len(sb.get(key, [])) < 20:
                    w["source"] = SOURCE
                    w["sourceUrl"] = u
                    sb.setdefault(key, []).append(w)
            ok += 1
        elif "examination" in slug or "exam-questions" in slug:
            qs = exam_questions(lines)
            if not qs:
                continue
            key = (cls, subj, term)
            for q in qs:
                if len(eb.get(key, [])) >= 60:
                    break
                q["sourceUrl"] = u
                eb.setdefault(key, []).append(q)
            ok += 1
        else:
            key = (cls, subj, term)
            if len(nb.get(key, [])) >= 40:
                continue
            first = lines[0][:120] if lines else title
            nb.setdefault(key, []).append({
                "title": title or first,
                "week": len(nb.get(key, [])) + 1,
                "content": normalize("\n".join(lines))[:20000],
                "source": SOURCE,
                "sourceUrl": u,
            })
            ok += 1

    print(f"classbasic: captured {ok} pages")
    print(f"notes files: {write_corpora(nb, 'notes')}")
    print(f"schemes files: {write_corpora(sb, 'schemes')}")
    print(f"exams files: {write_corpora(eb, 'exams')}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--kinds", default="schemes,exams,notes",
                    help="comma list: schemes,exams,notes")
    ap.add_argument("--max-pages", type=int, default=400)
    args = ap.parse_args()
    kinds = [k.strip() for k in args.kinds.split(",") if k.strip()]
    try:
        run(kinds, args.max_pages)
    except Exception as e:  # noqa: BLE001
        print(f"classbasic run failed: {e}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()
