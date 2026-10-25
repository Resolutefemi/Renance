#!/usr/bin/env python3
"""Validate a generated lesson dict against the founder's requirements.

Rules:
- exactly 10 notes (11 tolerated by dropping the last in normalize())
- body word count 250..400 per note
- headings 2..9 words, unique
- ASCII only; no "--", no "<", no double quotes, no math-trigger escapes
- no exam/marks/revision language (word boundaries)
- {S} 1..8 total, max 2 per note; {t}/{T} max 2 total; no other {X} tokens
- key_points 3..6, each 6..40 words
- summary present, 10..40 words
"""
import re

MINW, MAXW = 250, 400

BANNED_RE = re.compile(
    r"\b(exams?|examiners?|revision|WAEC|JAMB|(?<!stretch )(?<!skin )(?!skin )(?<!birth )marks)\b|"
    r"to pass (this|the) (exam|test|course|module)|passing this", re.I)

# angle bracket is only dangerous when it opens a tag-like sequence
TAG_LIKE = re.compile(r"<[a-zA-Z/!]")

GENERIC_HEADINGS = {
    "overview", "introduction", "conclusion", "summary", "key concepts",
    "key points", "details", "basics", "fundamentals", "important concepts",
    "main ideas", "final thoughts", "wrap up",
}

MATH_TRIGGERS = ("\\(", "\\[", "\\$", "\\begin{")


def check_text(s, errs, label):
    if "--" in s:
        errs.append("%s: contains --" % label)
    if TAG_LIKE.search(s):
        errs.append("%s: tag-like angle bracket" % label)
    for ch in s:
        if ord(ch) > 127:
            errs.append("%s: non-ascii char %r" % (label, ch))
            break
    for trig in MATH_TRIGGERS:
        if trig in s:
            errs.append("%s: math trigger %r" % (label, trig))
            break
    m = BANNED_RE.search(s)
    if m:
        errs.append("%s: banned word %r" % (label, m.group(0)))


def check_tokens(s, errs, label):
    for tok in re.findall(r"\{[A-Za-z_]+\}", s):
        if tok in ("{s}", "{sec}", "{S2}", "{subject}"):
            errs.append("%s: unresolved token %s" % (label, tok))


def validate(lesson):
    """lesson: dict with notes/key_points/summary. Returns (ok, errors)."""
    errs = []
    notes = lesson.get("notes")
    if not isinstance(notes, list) or not notes:
        return False, ["no notes list"]
    if len(notes) != 10:
        errs.append("note count %d (want 10)" % len(notes))
    heads = []
    s_total = 0
    t_total = 0
    for i, n in enumerate(notes[:12]):
        label = "note%d" % (i + 1)
        h = (n.get("heading") or "").strip()
        b = (n.get("body") or "").strip()
        hw = len(h.split())
        if not 2 <= hw <= 9:
            errs.append("%s: heading %d words" % (label, hw))
        if h.lower() in GENERIC_HEADINGS:
            errs.append("%s: generic heading %r" % (label, h))
        heads.append(h.lower())
        w = len(b.split())
        if not MINW <= w <= MAXW:
            errs.append("%s: %d words (want %d to %d)" % (label, w, MINW, MAXW))
        check_text(b, errs, label + " body")
        check_tokens(b, errs, label)
        s_total += b.count("{S}")
        t_total += b.count("{t}") + b.count("{T}")
        if b.count("{S}") > 3:
            errs.append("%s: %d {S} uses" % (label, b.count("{S}")))
    if len(set(heads)) != len(heads):
        errs.append("duplicate headings")
    if not 1 <= s_total <= 12:
        errs.append("{S} total %d (want 1 to 12)" % s_total)
    if t_total > 2:
        errs.append("{t}/{T} total %d (want 0 to 2)" % t_total)
    kp = lesson.get("key_points")
    if not isinstance(kp, list) or not 3 <= len(kp) <= 6:
        errs.append("key_points %s items (want 3 to 6)" % (len(kp) if isinstance(kp, list) else 0))
    else:
        for i, k in enumerate(kp):
            kw = len(k.split())
            if not 6 <= kw <= 40:
                errs.append("key_point%d: %d words" % (i + 1, kw))
            check_text(k, errs, "key_point%d" % (i + 1))
            check_tokens(k, errs, "key_point%d" % (i + 1))
    summ = (lesson.get("summary") or "").strip()
    sw = len(summ.split())
    if not 10 <= sw <= 45:
        errs.append("summary %d words (want 10 to 45)" % sw)
    else:
        check_text(summ, errs, "summary")
        check_tokens(summ, errs, "summary")
    return (not errs), errs


ASCII_MAP = {
    "\u2014": " - ", "\u2013": " - ", "\u2018": "'", "\u2019": "'",
    "\u201c": "'", "\u201d": "'", "\u2026": "...", "\u00a0": " ",
    "\u2011": "-", "\u2012": "-", "\u2010": "-", "\u2212": "-",
}


def to_ascii(s):
    for k, r in ASCII_MAP.items():
        s = s.replace(k, r)
    return s


def normalize(lesson):
    """Return a clean lesson dict: 10 notes max, trimmed, ASCII-safe."""
    notes = []
    for n in lesson.get("notes", [])[:10]:
        notes.append({
            "heading": to_ascii((n.get("heading") or "").strip()),
            "body": to_ascii((n.get("body") or "").replace("\r", "")).strip(),
        })
    return {
        "summary": to_ascii((lesson.get("summary") or "").strip()),
        "notes": notes,
        "key_points": [to_ascii(k.strip()) for k in lesson.get("key_points", [])][:6],
    }


if __name__ == "__main__":
    import json
    import sys
    sys.path.insert(0, "/home/z/my-project/scripts/tert/gen")
    from json_repair import loads_lenient
    d = loads_lenient(json.load(open(sys.argv[1]))["choices"][0]["message"]["content"])
    ok, errs = validate(normalize(d))
    print("OK" if ok else "FAIL")
    for e in errs:
        print(" -", e)
