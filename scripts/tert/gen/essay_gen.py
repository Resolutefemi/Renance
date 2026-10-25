#!/usr/bin/env python3
"""Essay-mode lesson generation: prompt builders, parser, post-processor.

The model writes a 10-section teaching essay in plain prose (JSON mode
suppresses length); this module parses it into the lesson dict.
"""
import re

ESSAY_SYSTEM = """You are a senior curriculum writer for Renance, a Nigerian higher-education learning app. You write rich, thorough teaching material. You always write LONG: every section you write is 4 full paragraphs of 4 to 6 sentences each. You teach with mechanisms, concrete values and worked examples. Plain ASCII only, no double hyphen, no unicode dashes, never mention exams or marks or revision."""


def essay_user(task):
    samples = ", ".join('"%s"' % s for s in task["samples"])
    return """Write a complete teaching lesson on this unit topic as continuous prose.

Discipline: %s
Course section: %s
Unit topic: %s

The lesson has exactly 10 sections. Format each section exactly like this:

===
HEADING: a short specific heading (max 8 words)
PARAGRAPH 1
PARAGRAPH 2
PARAGRAPH 3
PARAGRAPH 4
===

Length rule: every section is 4 paragraphs of 4 to 6 sentences, totalling 260 to 330 words. A section under 250 words or over 400 words is a failure. Count your sentences: at least 16 and at most 23 per section.

Cover, in order: what the topic is, the core mechanism, key structures and details, worked example one, worked example two, numbers and measurements, common errors, connections to real practice, a full realistic scenario, and the deep takeaways.

The placeholder {S} stands for the course subject; depending on the course it will read as %s. Use {S} naturally in 3 to 6 sections, once per section.

Write the whole lesson now. Do not stop early; all 10 sections are required.""" % (
        task["discipline"], task["section"], task["unit"], samples)


def essay_feedback_user(task, errs, prev_short=None):
    """Retry prompt after a rejected essay."""
    base = essay_user(task)
    msg = "\n\nYour previous attempt was REJECTED for these reasons:\n%s" % "; ".join(errs[:8])
    if prev_short:
        msg += "\nIn particular these sections were under 250 words: %s. Every section must run 4 full paragraphs of 4 to 6 sentences, 260 to 390 words. Write MORE in each section: add mechanism detail, concrete values and worked steps." % ", ".join(str(i) for i in prev_short)
    return base + msg


# ------------------------------------------------------------------ parse

_SEC_PREFIX = re.compile(r"^(?:SECTION\s*\d+\s*[:.)]?\s*)(.*)$", re.I)
_HEAD_LABEL = re.compile(r"^HEADING\s*[:\-]?\s*(.+)$", re.I)


def parse_essay(text):
    """Parse sections delimited by lines starting with === (with or without
    inline headings) into [(heading, [paragraph,...]), ...]."""
    text = text.strip()
    sections = []
    cur = None
    for line in text.split("\n"):
        ls = line.strip()
        if ls.startswith("==="):
            if cur is not None and (cur["head"] or cur["lines"]):
                sections.append(cur)
            rest = ls.lstrip("=").strip()
            rest = _SEC_PREFIX.match(rest).group(1).strip() if _SEC_PREFIX.match(rest) else rest
            cur = {"head": rest, "lines": []}
        elif cur is not None:
            cur["lines"].append(line)
    if cur is not None and (cur["head"] or cur["lines"]):
        sections.append(cur)

    out = []
    for s in sections:
        lines = list(s["lines"])
        while lines and not lines[0].strip():
            lines.pop(0)
        while lines and not lines[-1].strip():
            lines.pop()
        head = s["head"]
        if not head and lines:
            head = lines.pop(0).strip()
        if lines:
            m2 = _HEAD_LABEL.match(lines[0].strip())
            if m2 and (not head or len(head.split()) <= 3):
                head = m2.group(1).strip()
                lines.pop(0)
                while lines and not lines[0].strip():
                    lines.pop(0)
        m = _HEAD_LABEL.match(head or "")
        if m:
            head = m.group(1).strip()
        head = (head or "").strip(": -").strip()
        paras_raw = ["\n".join(g) for g in _para_groups(lines)]
        if not paras_raw:
            if not head:
                continue
            paras_raw = [head]
            head = ""
        out.append((head, [p.strip() for p in paras_raw if p.strip()]))
    return out


_LABEL_LINE = re.compile(r"^\s*(PARAGRAPH|SECTION)\s*\d+\s*[:.)]?\s*$", re.I)


def _para_groups(lines):
    cur = []
    for l in lines:
        if _LABEL_LINE.match(l):
            continue
        if l.strip():
            cur.append(l)
        elif cur:
            yield cur
            cur = []
    if cur:
        yield cur


# ------------------------------------------------------- post-processing

ASCII_MAP = {
    "\u2014": " - ", "\u2013": " - ", "\u2018": "'", "\u2019": "'",
    "\u201c": "'", "\u201d": "'", "\u2026": "...", "\u00a0": " ",
    "\u2011": "-", "\u2012": "-", "\u2010": "-", "\u2212": "-",
    "\u00b0": " degrees ", "\u2022": "-", "\u00d7": "x", "\u00f7": "/",
    "\u2265": ">=", "\u2264": "<=", "\u2260": "!=",
    "\u03c0": "pi", "\u03a3": "sum", "\u0394": "delta", "\u0394".lower(): "delta",
    "\u03b8": "theta", "\u2248": "about ", "\u03bc": "u", "\u03a9": "ohm",
    "\u03b1": "alpha", "\u03b2": "beta", "\u03b3": "gamma", "\u03c1": "rho",
    "\u03bb": "lambda", "\u03c3": "sigma", "\u03c4": "tau", "\u03c6": "phi",
    "\u03c9": "omega", "\u00b1": "+/-", "\u221a": "sqrt", "\u221e": "infinity",
    "\u2234": "therefore", "\u2261": "equals", "\u2192": " to ", "\u00bd": "half",
    "\u00b2": " squared", "\u00b3": " cubed",
}

_S_REPLACEMENTS = ["this field", "the discipline", "this area"]


def to_ascii(s):
    for k, r in ASCII_MAP.items():
        s = s.replace(k, r)
    return s


_TAGTIGHT = re.compile(r"(?<=[A-Za-z0-9_)}\]'])<(?=[A-Za-z0-9_(])")


def fix_dashes_and_brackets(s):
    """Deterministic repairs: spaced double dash to single dash, tight code
    comparisons spaced out so the app renderer never sees a tag-like <."""
    s = s.replace(" -- ", " - ").replace("--", "-")
    s = _TAGTIGHT.sub(" < ", s)
    return s


def dedupe_s(body):
    """Keep at most one {S} per note; replace extras with natural phrases."""
    parts = body.split("{S}")
    if len(parts) <= 2:
        return body
    out = parts[0]
    for i, p in enumerate(parts[1:]):
        out += ("{S}" if i == 0 else _S_REPLACEMENTS[i % len(_S_REPLACEMENTS)]) + p
    return out


_SENT_SPLIT = re.compile(r"(?<=[.!?])\s+")


def trim_to_400(body, maxw=400):
    """Drop trailing sentences while over the word cap (min 10 sentences kept)."""
    words = body.split()
    if len(words) <= maxw:
        return body
    sents = _SENT_SPLIT.split(body)
    while len(" ".join(sents).split()) > maxw and len(sents) > 10:
        sents.pop()
    return " ".join(sents)


def first_sentence(text, lo=8, hi=45):
    for s in _SENT_SPLIT.split(text):
        s = s.strip()
        if lo <= len(s.split()) <= hi:
            return s if s.endswith((".", "!", "?")) else s + "."
    return None


def build_lesson(text, unit_title):
    """Parse + post-process an essay into the final lesson dict."""
    secs = parse_essay(text)
    notes = []
    for head, paras in secs[:10]:
        body = to_ascii("\n\n".join(paras))
        body = fix_dashes_and_brackets(body)
        body = dedupe_s(body)
        body = trim_to_400(body)
        head = to_ascii(head) or (unit_title[:60])
        notes.append({"heading": head, "body": body})
    # summary: prefer section 1 first sentence, fall back per-section scan
    summary = None
    for n in notes:
        summary = first_sentence(n["body"].replace("\n", " "))
        if summary:
            break
    if not summary:
        summary = "%s: what it is, how it works, and how to apply it." % unit_title
    summary = summary[0].upper() + summary[1:]
    if len(summary.split()) > 45:
        summary = " ".join(summary.split()[:40]) + "."
    # key points: first sentences of the last notes (mechanism/example/errors/takeaway)
    kps = []
    for idx in (2, 4, 7, 10):
        if idx <= len(notes):
            fs = first_sentence(notes[idx - 1]["body"].replace("\n", " "))
            if fs:
                kps.append(fs)
    if len(kps) < 3:
        for n in notes:
            if len(kps) >= 4:
                break
            fs = first_sentence(n["body"].replace("\n", " "))
            if fs and fs not in kps:
                kps.append(fs)
    return {"summary": summary, "notes": notes, "key_points": kps[:6]}
