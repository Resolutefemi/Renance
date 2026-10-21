#!/usr/bin/env python3
"""parse_nerdc_schemes - extract the official NERDC 2025 scheme-of-work
tables from the two uploaded source PDFs into per class+subject+term JSON
files under data/school-schemes/nerdc-2025/.

Sources (uploads/):
  Complete-Scheme-of-Work-JSS n SSS New A.pdf            JSS 1-3 + SSS 1-3
  PRE-PRIMARY & PRIMARY SCHOOLS - NERDC Scheme (2025).pdf  Pre-Nursery,
                                                          Nursery 1-3,
                                                          Primary 1-6

Pipeline: pdftotext -layout (cached under .cache/nerdc-schemes/) then a
layout-aware table walker:
  - subject headers "<CLASS> <SUBJECT> SCHEME OF WORK" and friends (trade
    subject titles carry no suffix; the pre-primary PDF also uses
    "<SUBJECT> SCHEME OF WORK (CLASS)" and "<SUBJECT> (CLASS)")
  - term markers FIRST/SECOND/THIRD TERM (case-insensitive, optional
    trailing parenthetical), each confirmed by a following Week-table
    header so table cells that merely mention a term never split a table
  - week rows start with 1..14 (or a range like 11-13 / 1&2); every other
    line is a continuation appended to the column nearest its start
    offset; page footers, page numbers, hyphen wraps and narrow column
    letter wraps are stitched back, bullets become "- " lines
  - one-column tables carry the breakdown as content; multi-column tables
    (English Studies grids, pre-primary activity grids) join the extra
    columns into the content block labelled with the column names, the
    first non-empty column becomes the topic

Outputs (never touches classbasic/ or the curated per-class folders):
  data/school-schemes/nerdc-2025/<class-slug>-<subject-slug>-term<N>.json
  {"class","subject","term","weeks":[{"week","topic","content"}],
   "provenance":{"source":"NERDC 2025 scheme","harvested":"2026-10-04"}}

Usage:
  python3 scripts/parse_nerdc_schemes.py             # extract (resumable)
  python3 scripts/parse_nerdc_schemes.py --force     # rewrite existing files
  python3 scripts/parse_nerdc_schemes.py --stats     # coverage report, no writes
  python3 scripts/parse_nerdc_schemes.py --debug     # segmentation map + warnings
"""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
from collections import defaultdict
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
UPLOADS = REPO / "uploads"
CACHE = REPO / ".cache" / "nerdc-schemes"
OUT = REPO / "data" / "school-schemes" / "nerdc-2025"
HARVESTED = "2026-10-04"
SRC_LABEL = "NERDC 2025 scheme"

JS_PDF = UPLOADS / "Complete-Scheme-of-Work-JSS n SSS New A.pdf"
PRY_PDF = UPLOADS / "PRE-PRIMARY & PRIMARY SCHOOLS - NERDC Scheme (2025).pdf"

# ---------------------------------------------------------------- text rules

DASH_CHARS = "\u2010\u2011\u2012\u2013\u2014\u2015\u2212\uFE63\uFF0D"
DASH_RE = re.compile("[" + DASH_CHARS + "]")
BULLET_CHARS = "\u2022\uF0B7\uF0A7\u25AA\u25CF\u2023\u25E6"
# words joined by single spaces = one table cell segment on a line
SEG_RE = re.compile(r"\S+(?: \S+)*")
ITEM_RE = re.compile(r"^(?:[ivx]{1,4}|\d{1,2})\.(?!\d)", re.I)
WEEKISH_RE = re.compile(r"^\d{1,2}\s*[.)]?$")
WEEK_CELL_RE = re.compile(r"^(\d{1,2})(?:\s*[.&-]\s*(\d{1,2})?)?$")
PLACEHOLDERS = {"", "-", "--", "n/a", "nil", "none", "null"}

FOOTERS = [
    re.compile(r"^\s*\d{1,4}\s*\|.*BACK TO TABLE OF CONTENT", re.I),
    re.compile(r"^\s*GET ACCESS TO MORE EDUCATIONAL RESOURCES", re.I),
    re.compile(r"^\s*BACK TO TABLE OF CONTENT\s*$", re.I),
    re.compile(r"^\s*TABLE OF CONTENT\s*$", re.I),
    re.compile(r"^\s*\d{1,4}\s*\|\s*\d{1,4}\s*\|\s*$"),
    re.compile(r"^\s*\(Ready-to-use lesson notes", re.I),
    re.compile(r"^\s*CLICK HERE\b"),
]
PAGENUM_RE = re.compile(r"^\s*\d{1,4}\s*$")

TERM_RE = re.compile(
    r"^\s{0,10}(FIRST|SECOND|THIRD|1ST|2ND|3RD)\s+TERM(\s*\([^)]{0,40}\))?\s*:?\s*$", re.I
)
TERM_NUM = {"first": 1, "second": 2, "third": 3, "1st": 1, "2nd": 2, "3rd": 3}
WEEKHDR_RE = re.compile(r"^\s{0,12}(week|wee|wk)\b", re.I)
WEEK_WORD_RE = re.compile(r"(?i)^(week|wee|wk)(\s+)(.+)$")
WEEK_WORD_ONLY_RE = re.compile(r"(?i)^(week|wee|wk)$")

PRY_CLASS_TOKEN = r"(?:PRENURSERY|PRE-?NURSERY|NURSERY\s*[123]|PRIMARY\s*[1-6])"
PRY_SECTION_RE = re.compile(rf"^\s{{0,8}}({PRY_CLASS_TOKEN})\s+SCHEME OF WORK\s*$", re.I)
PRY_SOW_TAIL_RE = re.compile(
    rf"\s*SCHEME OF WORK(\s*\(\s*{PRY_CLASS_TOKEN}\s*\))?\s*$", re.I
)
PRY_CLASS_PAREN_RE = re.compile(rf"^(.+?)\s*\(\s*{PRY_CLASS_TOKEN}\s*\)\s*$", re.I)
PRY_CLASS_PREFIX_RE = re.compile(rf"^\s*{PRY_CLASS_TOKEN}\s+", re.I)
PRY_CLASS_NAMES = {
    "prenursery": "Pre-Nursery",
    "pre-nursery": "Pre-Nursery",
    "nursery 1": "Nursery 1",
    "nursery 2": "Nursery 2",
    "nursery 3": "Nursery 3",
    "primary 1": "Primary 1",
    "primary 2": "Primary 2",
    "primary 3": "Primary 3",
    "primary 4": "Primary 4",
    "primary 5": "Primary 5",
    "primary 6": "Primary 6",
}

JS_CLASS_RE = re.compile(r"^\s{0,4}(JSS|SSS|SS)\s*([123])\s+(.+?)\s*$")
ACRONYM_PAREN_RE = re.compile(r"\s*\((?:CRS|IRS|CCA|PV)\)", re.I)

# ---------------------------------------------------------------- naming

SMALL_WORDS = {
    "and", "of", "the", "in", "to", "for", "with", "on", "at", "by", "from",
    "a", "an", "or", "as", "its", "their", "into", "per",
}
KEEP_CAPS = {
    "CCA", "CRS", "IRS", "ICT", "GSM", "PV", "WAEC", "NECO", "SSCE", "HIV",
    "AIDS", "GMO", "GMOs", "MDGs", "IVF", "ECOWAS", "IMF", "ADB", "OPEC",
    "GATT", "UNCTAD", "EFCC", "ICPC", "NAFDAC", "BOP", "SQ3R", "SPQ3R",
    "LSRW", "TV", "CD", "DVD", "JSS", "SSS", "SS", "BECE", "NABTEB", "NATEB",
}
ROMAN = {"I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"}
SUBJECT_OVERRIDES = {
    "LITERATURE-IN-ENGLISH": "Literature-in-English",
    "PREVOCATIONAL STUDIES": "Pre-Vocational Studies",
    "PRE VOCATIONAL STUDIES": "Pre-Vocational Studies",
    "PRE-SCIENCE": "Pre-Science",
    "PRE SCIENCE": "Pre-Science",
}


def slugify(name: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-")


def _title_word(word: str, first: bool, last: bool) -> str:
    up = word.upper()
    if up in KEEP_CAPS:
        return up
    if word in {"MDGs", "GMOs"}:
        return word
    if up in ROMAN and len(word) <= 4:
        return up
    if word.lower() in SMALL_WORDS and not (first or last):
        return word.lower()
    if not word:
        return word
    return word[0].upper() + word[1:].lower()


def titlecase(text: str) -> str:
    words = text.split()
    out = []
    for i, w in enumerate(words):
        if "-" in w and len(w) > 1:
            parts = w.split("-")
            out.append("-".join(
                _title_word(p, j == 0, j == len(parts) - 1)
                for j, p in enumerate(parts)
            ))
        else:
            out.append(_title_word(w, i == 0, i == len(words) - 1))
    return " ".join(out)


def canonical_subject(raw: str, class_slug: str) -> str:
    """Normalise a header subject string into its display name."""
    name = raw.strip()
    name = ACRONYM_PAREN_RE.sub("", name)
    name = re.sub(r"\s*&\s*", " and ", name)
    name = re.sub(r"\s{2,}", " ", name).strip(" -")
    key = name.upper()
    if class_slug.startswith("sss-") and key in {"ENGLISH STUDIES", "ENGLISH LANGUAGE"}:
        key = "ENGLISH LANGUAGE"
    if key == "CATERING AND CRAFT":
        key = "CATERING AND CRAFT PRACTICE"
    if key in SUBJECT_OVERRIDES:
        return SUBJECT_OVERRIDES[key]
    if not key:
        return ""
    return titlecase(key)


# ---------------------------------------------------------------- helpers

def is_noise(line: str) -> bool:
    if not line.strip():
        return True
    if PAGENUM_RE.match(line):
        return True
    for rx in FOOTERS:
        if rx.match(line):
            return True
    return False


def norm_dash(text: str) -> str:
    return DASH_RE.sub("-", text)


def next_nonnoise(lines: list[str], i: int, count: int) -> list[str]:
    out: list[str] = []
    j = i + 1
    while j < len(lines) and len(out) < count:
        if not is_noise(lines[j]):
            out.append(lines[j])
        j += 1
    return out


def term_number(line: str, lines: list[str], i: int) -> int | None:
    """Term marker, only when a Week table header follows close by."""
    m = TERM_RE.match(line)
    if not m:
        return None
    for probe in next_nonnoise(lines, i, 6):
        if WEEKHDR_RE.match(probe):
            return TERM_NUM[m.group(1).lower()]
    return None


# ---------------------------------------------------------------- grammars

class JSGrammar:
    """Complete-Scheme-of-Work-JSS n SSS New A.pdf"""

    pdf = JS_PDF
    key = "js"

    @staticmethod
    def header(line: str, lines: list[str], i: int):
        """Return (class_name, subject_raw) or None."""
        m = JS_CLASS_RE.match(line)
        if not m:
            return None
        prefix, num, rest = m.group(1), m.group(2), m.group(3)
        if not rest:
            return None
        if not rest.upper().rstrip(" ").endswith("SCHEME OF WORK"):
            # trade subject titles have no suffix; confirm via term marker
            if not any(TERM_RE.match(p) for p in next_nonnoise(lines, i, 4)):
                return None
        subject = re.sub(r"\s*SCHEME OF WORK\s*$", "", rest, flags=re.I).strip()
        subject = PRY_CLASS_PREFIX_RE.sub("", subject) if False else subject
        cls = f"JSS {num}" if prefix == "JSS" else f"SSS {num}"
        return cls, subject


class PryGrammar:
    """PRE-PRIMARY & PRIMARY SCHOOLS - NERDC Scheme (2025).pdf"""

    pdf = PRY_PDF
    key = "pry"

    @staticmethod
    def section_class(line: str) -> str | None:
        m = PRY_SECTION_RE.match(line)
        if not m:
            return None
        return PRY_CLASS_NAMES[re.sub(r"\s+", " ", m.group(1).upper()).strip()]

    @staticmethod
    def header(line: str, lines: list[str], i: int):
        """Return (class_name, subject_raw) or None."""
        s = line.strip()
        if not s or "....." in s or "|" in s:
            return None
        # a standalone class line is noise, not a header
        if re.sub(r"\s+", " ", s.upper()) in PRY_CLASS_NAMES:
            return None
        if not PRY_SOW_TAIL_RE.search(s):
            # "<SUBJECT> (CLASS)" variant, e.g. ENGLISH LANGUAGE (PRIMARY 1)
            if not PRY_CLASS_PAREN_RE.match(s):
                return None
        if not any(TERM_RE.match(p) for p in next_nonnoise(lines, i, 4)):
            return None
        name = PRY_CLASS_PAREN_RE.sub(lambda m: m.group(1), s)  # drop trailing (CLASS)
        name = re.sub(r"\s*SCHEME OF WORK\s*$", "", name, flags=re.I).strip()
        # class prefix on 2nd/3rd term headers
        cls = None
        m = PRY_CLASS_PREFIX_RE.match(name + " ")
        if m:
            cls = PRY_CLASS_NAMES[re.sub(r"\s+", " ", m.group(0).upper()).strip()]
            name = PRY_CLASS_PREFIX_RE.sub("", name, count=1).strip()
        if not name:
            return None
        return cls, name


GRAMMARS = [JSGrammar, PryGrammar]


# ---------------------------------------------------------------- walk

def walk(lines: list[str], grammar, log) -> list[dict]:
    """Split the text into (class, subject, term) sections."""
    sections: list[dict] = []
    cur_class: str | None = None
    cur_subject: str | None = None
    cur: dict | None = None
    for i, line in enumerate(lines):
        if grammar is PryGrammar:
            sec = grammar.section_class(line)
            if sec:
                cur_class = sec
                cur_subject = None
                cur = None
                continue
        hdr = grammar.header(line, lines, i)
        if hdr:
            cls, subject = hdr
            if cls:
                cur_class = cls
            cur_subject = subject
            cur = None
            continue
        term = term_number(line, lines, i)
        if term:
            if not cur_class or not cur_subject:
                log(f"[{grammar.key}] term marker without subject at line {i+1}: {line.strip()!r}")
                continue
            cur = {
                "grammar": grammar.key,
                "class": cur_class,
                "subject": cur_subject,
                "term": term,
                "lines": [line],
                "at": i + 1,
            }
            sections.append(cur)
            continue
        if cur is not None:
            cur["lines"].append(line)
    return sections


# ---------------------------------------------------------------- table parse

def split_week_header(line: str):
    """Column starts + names from a 'Week Topic Content ...' header line."""
    segs = [(m.start(), m.group(0)) for m in SEG_RE.finditer(line)]
    if not segs:
        return None
    s0, t0 = segs[0]
    m = WEEK_WORD_RE.match(t0)
    if m:  # "Week Topic" glued by a single space
        col1 = s0 + m.start(3)
        names = [m.group(1), m.group(3)] + [t for _, t in segs[1:]]
        starts = [s0, col1] + [s for s, _ in segs[1:]]
    elif WEEK_WORD_ONLY_RE.match(t0) and len(segs) >= 2:
        names = [t0] + [t for _, t in segs[1:]]
        starts = [s0] + [s for s, _ in segs[1:]]
    else:
        return None
    if len(starts) < 2 or any(
        b - a <= 1 for a, b in zip(starts, starts[1:])
    ):
        return None
    return starts, names


def parse_week_cell(cell: str) -> int | None:
    s = norm_dash(cell).strip()
    s = s.rstrip(").").strip()
    m = WEEK_CELL_RE.match(s)
    if not m:
        return None
    wk = int(m.group(1))
    return wk if 1 <= wk <= 14 else None


def nearest_col(start: int, col_starts: list[int]) -> int:
    best, bd = 1, abs(col_starts[1] - start)
    for k in range(2, len(col_starts)):
        d = abs(col_starts[k] - start)
        if d <= bd:  # tie -> later column
            best, bd = k, d
    return best


def feed_segments(row: dict, line: str, col_starts: list[int], is_row: bool):
    for m in SEG_RE.finditer(line):
        s, text = m.start(), m.group(0)
        if s < col_starts[1] - 2:
            continue
        if is_row and s < col_starts[1] and WEEKISH_RE.match(text):
            continue  # "1." style week marker
        row["cols"][nearest_col(s, col_starts)].append(text)


def is_header_cont(line: str, col_starts: list[int]) -> bool:
    segs = [(m.start(), m.group(0)) for m in SEG_RE.finditer(line)]
    if not segs:
        return False
    for s, t in segs:
        if len(t) > 16:
            return False
        if min(abs(col_starts[k] - s) for k in range(len(col_starts))) > 8:
            return False
    return True


def merge_header_cont(line: str, col_starts: list[int], names: list[str]):
    for m in SEG_RE.finditer(line):
        s, t = m.start(), m.group(0)
        k = min(range(len(col_starts)), key=lambda j: (abs(col_starts[j] - s), -j))
        base = names[k].strip()
        if not base:
            names[k] = t
            continue
        if len(t) <= 3 and t.isalpha() and base[-1].isalpha():
            names[k] = base + t  # stacked letters: "CONTEN" + "T"
        else:
            names[k] = base + " " + t


def parse_table(sec: dict, log) -> list[dict]:
    lines = sec["lines"]
    hdr_idx = None
    parsed = None
    seen = 0
    for j, line in enumerate(lines):
        if is_noise(line):
            continue
        seen += 1
        if WEEKHDR_RE.match(line):
            parsed = split_week_header(line)
            hdr_idx = j
            break
        if seen >= 4:
            break
    if hdr_idx is None or parsed is None:
        log(f"no table header: {sec['class']} {sec['subject']} term {sec['term']} (line {sec['at']})")
        return []
    col_starts, names = parsed
    rows: list[dict] = []
    cur: dict | None = None
    poisoned = False
    chain_until = hdr_idx + 4
    j = hdr_idx + 1
    while j < len(lines):
        line = lines[j]
        j += 1
        if is_noise(line):
            continue
        lead = re.search(r"\S", line)
        if cur is None and not rows and (j - 1) <= chain_until and is_header_cont(line, col_starts):
            merge_header_cont(line, col_starts, names)
            continue
        if lead and lead.start() >= col_starts[1] - 2:
            if cur is None or poisoned:
                continue
            feed_segments(cur, line, col_starts, is_row=False)
            continue
        wk = parse_week_cell(line[: col_starts[1]])
        if wk is None:
            continue  # stray text left of the topic column
        if rows and wk < rows[-1]["week"]:
            poisoned = True  # numbered listing between sections, not a row
            continue
        if rows and wk == rows[-1]["week"]:
            cur = rows[-1]
        else:
            cur = {"week": wk, "cols": [[] for _ in col_starts]}
            rows.append(cur)
        poisoned = False
        feed_segments(cur, line, col_starts, is_row=True)
    sec["col_names"] = names
    return rows


# ---------------------------------------------------------------- cell assembly

def join_fragments(frags: list[str]) -> str:
    parts: list[str] = []
    for raw in frags:
        f = norm_dash(raw).strip()
        if not f:
            continue
        if f == "-":
            parts.append("\n-")
            continue
        if f[0] in BULLET_CHARS:
            parts.append("\n" + f)
            continue
        if not parts:
            parts.append(f)
            continue
        prev = parts[-1]
        if ITEM_RE.match(f):
            parts.append("\n" + f)
        elif prev.endswith("-") and f[0].islower():
            parts[-1] = prev + f  # word wrap "step-" + "by-step"
        elif (
            prev[-1:].islower()
            and f[0].islower()
            and len(f.split()[0]) == 1
            and f[0] not in "ai"
        ):
            parts[-1] = prev + f  # narrow column wrap "Recognitio" + "n of"
        else:
            parts.append(f)
    out = ""
    for p in parts:
        if p.startswith("\n"):
            out += "\n" + p[1:].strip()
        else:
            out += " " + p
    return out.strip()


def clean_text(text: str) -> str:
    text = text.replace("\u00a0", " ")
    for b in BULLET_CHARS:
        text = text.replace(b, "\n-")
    text = text.replace("\u2026", "...")
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r" *\n *", "\n", text)
    text = re.sub(r"\n{2,}", "\n", text)
    text = re.sub(r"--+", "-", text)
    lines = []
    for ln in text.split("\n"):
        ln = ln.strip()
        ln = re.sub(r"^-(?=\S)", "- ", ln)  # "-Create" -> "- Create"
        if ln and ln not in {"-", "--"}:
            lines.append(ln)
    return "\n".join(lines).strip()


def finalize_cell(frags: list[str]) -> str:
    text = clean_text(join_fragments(frags))
    if text.lower() in PLACEHOLDERS:
        return ""
    return text


def compose_week(row: dict, col_names: list[str]):
    cells = [finalize_cell(c) for c in row["cols"][1:]]
    names = [n.strip() for n in col_names[1:]]
    topic_idx = next(
        (i for i, n in enumerate(names) if n.upper() in {"TOPIC", "TOPICS"}), None
    )
    if topic_idx is not None and cells[topic_idx]:
        topic = cells[topic_idx]
        rest = [(names[i], cells[i]) for i in range(len(cells)) if i != topic_idx and cells[i]]
    else:
        filled = [(names[i], cells[i]) for i in range(len(cells)) if cells[i]]
        if not filled:
            return None
        topic, rest = filled[0][1], filled[1:]
    if len(rest) == 1:
        content = rest[0][1]
    elif rest:
        content = "\n".join(f"{titlecase(n)}: {t}" for n, t in rest)
    else:
        content = ""
    if not topic and not content:
        return None
    return {"week": row["week"], "topic": topic, "content": content}


# ---------------------------------------------------------------- pipeline

def ensure_text(pdf: Path, key: str) -> Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    txt = CACHE / f"{key}.txt"
    if not txt.exists() or txt.stat().st_size == 0:
        subprocess.run(
            ["pdftotext", "-layout", str(pdf), str(txt)], check=True,
            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
        )
    return txt


def load_lines(pdf: Path, key: str) -> list[str]:
    text = ensure_text(pdf, key).read_text(encoding="utf-8").replace("\f", "")
    lines = text.split("\n")
    for i, line in enumerate(lines):
        s = line.strip()
        if s.startswith("SAMPLE LESSON NOTE") and "..." not in s:
            return lines[:i]  # sample lesson notes appendix, not schemes
    return lines


def build_corpus(log) -> list[dict]:
    """Parse every section of both PDFs into output records."""
    records: list[dict] = []
    for grammar in GRAMMARS:
        lines = load_lines(grammar.pdf, grammar.key)
        sections = walk(lines, grammar, log)
        log(f"[{grammar.key}] {len(sections)} term sections found")
        for sec in sections:
            rows = parse_table(sec, log)
            weeks = []
            for row in rows:
                entry = compose_week(row, sec["col_names"])
                if entry:
                    weeks.append(entry)
            subject = canonical_subject(sec["subject"], slugify(sec["class"]))
            records.append({
                "class": sec["class"],
                "subject": subject,
                "term": sec["term"],
                "weeks": weeks,
                "at": sec["at"],
                "raw_subject": sec["subject"],
            })
    return records


def file_name(rec: dict) -> str:
    return f"{slugify(rec['class'])}-{slugify(rec['subject'])}-term{rec['term']}.json"


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--force", action="store_true", help="rewrite existing output files")
    ap.add_argument("--stats", action="store_true", help="coverage report only, no writes")
    ap.add_argument("--debug", action="store_true", help="print the segmentation map")
    args = ap.parse_args()

    warnings: list[str] = []
    log = warnings.append
    records = build_corpus(log)

    if args.debug:
        for rec in records:
            print(
                f"{rec['class']:<12} {rec['subject']:<44} term {rec['term']}  "
                f"weeks={len(rec['weeks']):>2}  (pdf line {rec['at']}, raw={rec['raw_subject']!r})"
            )
        for w in warnings:
            print("WARN:", w)

    # collision guard: same class+subject+term seen twice
    seen: dict[str, dict] = {}
    for rec in records:
        key = file_name(rec)
        if key in seen:
            log(f"duplicate section merged into {key}: kept {len(seen[key]['weeks'])} weeks, dropped {len(rec['weeks'])}")
            continue
        seen[key] = rec

    if args.stats:
        by_class: dict[str, dict[str, dict[int, int]]] = defaultdict(lambda: defaultdict(dict))
        for key, rec in seen.items():
            by_class[rec["class"]][rec["subject"]][rec["term"]] = len(rec["weeks"])
        total_files = 0
        print(f"{'class':<12} {'subjects':>8} {'terms':>6} {'weeks':>6}  missing terms")
        for cls in sorted(by_class, key=lambda c: (order_key(c), c)):
            subjects = by_class[cls]
            n_terms = sum(len(t) for t in subjects.values())
            n_weeks = sum(sum(t.values()) for t in subjects.values())
            gaps = [f"{s} (t{t})" for s, t in sorted(subjects.items()) for t in (1, 2, 3) if t not in t]
            total_files += n_terms
            print(f"{cls:<12} {len(subjects):>8} {n_terms:>6} {n_weeks:>6}  {', '.join(gaps) if gaps else '-'}")
        print(f"\nfiles to write: {total_files} | sections parsed: {len(records)} | warnings: {len(warnings)}")
        on_disk = len(list(OUT.glob("*-term[123].json")))
        print(f"files already on disk: {on_disk}")
        for w in warnings:
            print("WARN:", w)
        return 0

    OUT.mkdir(parents=True, exist_ok=True)
    written = skipped = empty = 0
    for key in sorted(seen):
        rec = seen[key]
        path = OUT / key
        if not rec["weeks"]:
            empty += 1
            log(f"empty weeks, not written: {key} (pdf line {rec['at']})")
            continue
        if path.exists() and not args.force:
            skipped += 1
            continue
        payload = {
            "class": rec["class"],
            "subject": rec["subject"],
            "term": rec["term"],
            "weeks": rec["weeks"],
            "provenance": {"source": SRC_LABEL, "harvested": HARVESTED},
        }
        path.write_text(
            json.dumps(payload, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        written += 1
    print(f"written: {written}, skipped (exist): {skipped}, empty (not written): {empty}")
    for w in warnings:
        print("WARN:", w)
    return 0


def order_key(cls: str):
    order = ["Pre-Nursery", "Nursery 1", "Nursery 2", "Nursery 3"] + [
        f"Primary {i}" for i in range(1, 7)
    ] + [f"JSS {i}" for i in (1, 2, 3)] + [f"SSS {i}" for i in (1, 2, 3)]
    return order.index(cls) if cls in order else 99


if __name__ == "__main__":
    sys.exit(main())
