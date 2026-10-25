#!/usr/bin/env python3
"""tert/validate.py — enforce the content contract on built lessons."""
import re
import sys

BANNED = [
    "specimen", "practical work",
    "as mentioned above", "in conclusion", "in this unit we will",
    "write the date beside", "half of all wrong answers", "method marks are real marks",
    "stage one is observation",
]

# control characters, emoji and decorative unicode are banned; ASCII
# punctuation like # _ * is legitimate Python syntax in computing content
BAD_GLYPHS = re.compile(r"[\n\r\t]|[\U0001F300-\U0001FAFF\u2600-\u27BF\u2190-\u21FF\u2264\u2265\u00d7\u00f7]")


def opener(text):
    m = re.search(r"[A-Za-z][A-Za-z'-]*", text or "")
    return m.group(0).lower() if m else ""


def validate_lesson(lesson, unit_title, errors):
    uid = lesson["uid"]
    notes, quiz = lesson["notes"], lesson["quiz"]
    if len(notes) != 10:
        errors.append("%s: %d notes" % (uid, len(notes)))
    if len(quiz) != 20:
        errors.append("%s: %d quiz" % (uid, len(quiz)))
    t_first = opener(unit_title)
    prev_open = None
    counts = {"A": 0, "B": 0, "C": 0, "D": 0}
    for i, n in enumerate(notes):
        body = n["body"]
        w = len(body.split())
        cap = 185 if i == 9 else 125   # n10 is the app+traps combo, naturally longer
        if not (55 <= w <= cap):
            errors.append("%s n%d words=%d" % (uid, i + 1, w))
        if BAD_GLYPHS.search(body):
            errors.append("%s n%d glyphs" % (uid, i + 1))
        low = body.lower()
        for b in BANNED:
            if b in low:
                errors.append("%s n%d banned:%s" % (uid, i + 1, b))
        ow = opener(body)
        if ow == prev_open:
            errors.append("%s n%d opener-repeat:%s" % (uid, i + 1, ow))
        prev_open = ow
        if i > 0 and " ".join(body.lower().replace(",", " ").replace(":", " ").replace(".", " ").split()[:8]) == \
                " ".join(unit_title.lower().replace(",", " ").replace(":", " ").replace(".", " ").split()[:8]):
            errors.append("%s n%d opens-with-title" % (uid, i + 1))
    ids = set()
    for q in quiz:
        if q["id"] in ids:
            errors.append("%s dup-id %s" % (uid, q["id"]))
        ids.add(q["id"])
        if not q.get("explanation"):
            errors.append("%s %s no-explain" % (uid, q["id"]))
        if BAD_GLYPHS.search(q["stem"]):
            errors.append("%s %s glyphs" % (uid, q["id"]))
        if q["type"] == "mcq":
            opts = q.get("options", {})
            if len(opts) != 4 or len(set(opts.values())) != 4:
                errors.append("%s %s options" % (uid, q["id"]))
            if q["answer"] not in "ABCD" or len(q["answer"]) != 1:
                errors.append("%s %s answer" % (uid, q["id"]))
            else:
                counts[q["answer"]] += 1
        elif q["type"] == "true_false":
            if q["answer"] not in ("A", "B"):
                errors.append("%s %s tf-answer" % (uid, q["id"]))
        elif q["type"] == "fill_blank":
            if not q.get("answer"):
                errors.append("%s %s fill-empty" % (uid, q["id"]))
        else:
            errors.append("%s %s type:%s" % (uid, q["id"], q["type"]))
    over = {k: v for k, v in counts.items() if v > 7}
    if over:
        errors.append("%s balance %s" % (uid, over))
    return errors


def validate_all(lessons_by_course):
    errors = []
    for cid, lessons in lessons_by_course.items():
        for l in lessons:
            validate_lesson(l, l["title"], errors)
    return errors
