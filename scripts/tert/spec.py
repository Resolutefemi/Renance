#!/usr/bin/env python3
"""tert.spec — shared scaffolding for the tertiary content engine.

Design contract (founder directive 2026-10-25):
- Every unit teaches its OWN topic with the course subject's real vocabulary.
- No cross-discipline contamination (no specimens in programming, no
  encryption in a nutrition course), no "philosophy of studying" filler.
- Deterministic: same unit_id always yields byte-identical content.
- Notes: exactly 10, bodies 60-110 words. Quiz: exactly 20, four distinct
  options, answers balanced (no letter over 7), one-line rule explanations.
"""
import hashlib
import random
import re

# ------------------------------------------------------------------ rng

def unit_rng(unit_id):
    """Deterministic RNG seeded by the unit id (mirrors the Go engine's
    philosophy: content is a pure function of the id)."""
    seed = int(hashlib.sha256(unit_id.encode()).hexdigest()[:12], 16)
    return random.Random(seed)


def course_hash(course_id):
    return int(hashlib.sha256(course_id.encode()).hexdigest()[:8], 16)


# ------------------------------------------------------- subject phrase

_LEAD_STRIPPERS = [
    "introduction to ", "fundamentals of ", "foundation of ", "foundations of ",
    "elements of ", "basics of ", "basic ", "concepts of ", "concepts in ",
    "principles of ", "principle of ", "essentials of ", "general ",
    "outline of ", "survey of ", "overview of ", "understanding ",
]
_TRAIL_JUNK = re.compile(
    r"\b(i{1,3}|iv|vi{0,3}|ix|x|xi{0,3}|1|2|3|4)\s*$|\(part\s+[ivx0-9]+\)\s*$", re.I)

PROPER = {
    "python", "java", "javascript", "nigerian", "africa", "african", "english",
    "islamic", "christian", "yoruba", "hausa", "igbo", "french", "arabic",
    "chinese", "mandarin", "nigeria", "lagos", "google", "excel", "sql",
    "c++", "visual basic", "british", "european", "nuc", "jamb", "waec",
}


def subject_phrase(title, dept_name=""):
    """A short, sentence-friendly noun phrase for the course subject.

    'Computer Programming I (Python)'      -> 'Python programming'
    'Programming for AI (Python)'          -> 'Python programming'
    'Introduction to Cost Accounting'      -> 'cost accounting'
    'Nigerian Legal System'                -> 'the Nigerian legal system'
    """
    t = title.strip()
    paren = re.findall(r"\(([^)]+)\)", t)
    if paren:
        p = paren[-1].strip()
        pl = p.lower()
        if pl == "python":
            return "Python programming"
        if pl in ("java/c++", "java", "c++"):
            return "Java and C++ programming"
        if pl in ("python", "r", "sql", "excel"):
            return "%s programming" % p
        if len(p) <= 40 and not re.search(r"(part|module)", pl):
            # qualifier names the real subject: use it
            phrase = p
            low = phrase.lower()
            if low.split()[0] in ("introduction", "fundamentals", "elements", "basics"):
                phrase = " ".join(phrase.split()[2:]) or phrase
            return fix_case(phrase)
    base = re.sub(r"\([^)]*\)", " ", t)
    base = _TRAIL_JUNK.sub(" ", base)
    base = re.sub(r"\s+", " ", base).strip().strip("-").strip()
    low = base.lower()
    for s in _LEAD_STRIPPERS:
        if low.startswith(s):
            base = base[len(s):]
            low = base.lower()
    base = re.sub(r"\s*&\s*", " and ", base)
    if low.startswith("nigerian ") and not base.lower().startswith("the "):
        base = "the " + base
    # drop a leading course-code if it leaked in
    base = re.sub(r"^[A-Z]{2,4}\s*\d{3,4}\s*", "", base).strip()
    if not base:
        base = (dept_name or "the course").strip()
    return fix_case(base)


ACRONYMS = {"ICT", "AI", "SQL", "HTML", "NIN", "BVN", "PEP"}


def fix_case(phrase):
    """Subject phrases read mid-sentence: lowercase everything except
    proper nouns and acronyms."""
    words = phrase.split()
    out = []
    for i, w in enumerate(words):
        core = w.strip("(),.:;&'-").upper()
        if core in {p.upper() for p in PROPER} or w.strip("(),.:;") in ACRONYMS:
            out.append(w)
        elif i == 0:
            out.append(w[0].lower() + w[1:] if w[:1].isupper() else w)
        else:
            out.append(w[0].lower() + w[1:] if w[:1].isupper() and len(w) > 1 else w)
    return " ".join(out)


def lower_first(s):
    if s and s[:1].isupper() and s.split()[0].lower() not in PROPER:
        return s[0].lower() + s[1:]
    return s


def title_case(s):
    small = {"of", "and", "the", "in", "for", "to", "a", "an", "on", "with", "at", "by"}
    words = s.split()
    out = []
    for i, w in enumerate(words):
        lw = w.lower()
        if i and lw in small:
            out.append(lw)
        elif lw in PROPER or w[:1].isupper():
            out.append(w)
        else:
            out.append(w[0].upper() + w[1:])
    return " ".join(out)


# ------------------------------------------------------------- text kit

def fill(template, mapping):
    out = template
    for k, v in mapping.items():
        out = out.replace("{" + k + "}", v)
    return out


def sentences(text):
    return [s.strip() for s in re.split(r"(?<=[.!?])\s+", text.strip()) if s.strip()]


def body_len_ok(text, lo=55, hi=115):
    n = len(text.split())
    return lo <= n <= hi


WORD_RE = re.compile(r"[A-Za-z][A-Za-z'-]*")


def opener_word(text):
    m = WORD_RE.search(text or "")
    return (m.group(0).lower() if m else "")


# -------------------------------------------------------------- options

LETTERS = "ABCD"


def balanced_options(items, rng):
    """items: list of dicts {stem, correct, slips:[3], explanation}.
    Shuffles each item's options, then re-rolls permutations until the
    answer letters are balanced (no letter over max_share)."""
    n = len(items)
    max_share = max(4, (n + 3) // 4 + 1)  # for 20 items -> 6
    for _ in range(400):
        for it in items:
            opts = [it["correct"]] + list(it["slips"])
            rng.shuffle(opts)
            it["_options"] = opts
            it["_answer"] = LETTERS[opts.index(it["correct"])]
        counts = {L: 0 for L in LETTERS}
        for it in items:
            counts[it["_answer"]] += 1
        if max(counts.values()) <= max_share:
            return
    # leave last permutation in place; validator will report
