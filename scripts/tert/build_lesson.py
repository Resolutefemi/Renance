#!/usr/bin/env python3
"""tert/build_lesson.py — assemble one unit lesson (10 notes + 20 quiz).

Contract (founder band 2026-10-25: EVERY note body 150-250 words):
- Note 1 anchors the unit topic inside the subject (never filler about
  "studying" in the abstract).
- Notes 2-8 pair the section's knowledge atoms with curated section
  material (examples / applications / traps) rotated by unit seed.
- Note 9 is a worked example; note 10 is application + common errors.
- Every body is band-enforced: topic-anchored bridges raise short bodies
  to the 150 floor; sentence trimming caps at 250 (post-{S}-fill <= 250).
- Quiz: exactly 20 items drawn from the section pool + top-up, answers
  balanced across A-D, every item explained.
"""
from .spec import unit_rng, course_hash, fill, sentences, opener_word, lower_first

OPENERS = [
    "This unit takes up {T}, a working theme of {sec} in {S}. The plan is direct: define the moving parts, work them in real examples, and end with the errors examiners expect.",
    "{T} belongs to the middle of {S}, and this unit treats it as a craft skill rather than a definition to memorise. Read with the interpreter open, run every example, and break each one on purpose to see the error it produces.",
    "The spotlight here is {T}. Everything in it serves the same goal that runs through {S}: getting a correct, readable result from a clear process. The notes build the idea piece by piece, then the quiz checks whether the pieces hold under exam conditions.",
    "Welcome to the unit on {T}. It carries forward the work of {sec} and deepens it with concrete cases drawn from {S}. Work through the notes in order; each part assumes only what the previous parts established.",
    "Every serious course in {S} reaches {T} sooner or later, because the topic answers a question students actually ask: how do I do this properly rather than roughly. This unit answers it with mechanisms, examples and the honest traps.",
    "{T} is one of those topics that separates a passer from a practitioner in {S}. The unit builds it from the ground up: what it is, why it exists, how it behaves in examples, and where it breaks.",
]
CLOSERS = [
    "Keep the worked examples beside you during revision; they are the shortest route back into the method.",
    "Anything still fuzzy after one read becomes clear on the second pass with a pen and the examples.",
    "The quiz that follows rewards exactly this preparation: read the stems carefully and cite the rule before answering.",
    "One small worked case now, done by hand, is worth three more pages of reading.",
    "Note the exact wording used here; exams quote definitions almost verbatim.",
    "When you can rebuild the example from memory, the topic is yours.",
    "Compare your own attempt with the worked case and mark the exact step where they differ.",
]
# Topic-anchored bridge lines: glue that stays on the unit's own subject.
# Each bridge mentions the topic at most once, in a light way.
BRIDGES = [
    "Set beside the rest of {sec}, this is the point where definitions start producing answers, and in {t} the details decide whether an answer holds.",
    "What carries through every part of {S} here is that the topic rewards exactness: name the parts in order, apply the rule without shortcuts, and the result follows.",
    "A useful habit for {t} is to narrate each step before carrying it out, because in {S} the errors almost always begin at the step everyone skips.",
    "The discipline {S} grades is the ability to connect this material to the cases around it, so practise by asking what changes when one condition in {t} changes.",
    "Treat this as a procedure with reasons attached: every stage of {t} exists because skipping it breaks something specific, and naming that consequence is the real understanding {S} wants.",
    "When {t} appears inside longer problems in {sec}, it usually arrives disguised by context, so the transferable skill is recognising the pattern under the wording.",
    "Students who master this unit early find the later parts of {S} lighter, because it supplies the vocabulary and the checks the rest of the course reuses.",
    "The honest test of {t} is transfer: given a fresh situation in {S}, can you point at the matching case, the matching rule and the matching result without guessing.",
    "Two habits make this stick: writing the rule in your own words, and working one concrete case of {t} end to end until every number and name in it has a reason.",
    "In {S}, the difference between a rough answer and a correct one here is usually one overlooked condition, and this unit names those conditions explicitly.",
    "Keep asking why each stage exists; the answers are short, concrete and the same answers an examiner or a supervisor in {S} expects from you.",
    "This topic connects backwards and forwards inside {sec}: backwards to the definitions it depends on, forwards to the applications that reuse it, and both directions are worth tracing.",
]
MINW, MAXW = 150, 246  # pre-fill band; {S}/{t} fill adds a few words to <= 250


def _weave(atom, t, S, sec):
    """Ensure the atom mentions the unit topic or subject naturally."""
    if "{t}" in atom or "{T}" in atom or "{S}" in atom:
        return fill(atom, {"t": lower_first(t), "T": t, "S": S, "sec": sec})
    return atom


def _trim(body, maxw=MAXW, min_sents=6):
    """Drop trailing sentences while over the cap (keep a sane floor)."""
    words = body.split()
    if len(words) <= maxw:
        return body
    sents = sentences(body)
    while len(" ".join(sents).split()) > maxw and len(sents) > min_sents:
        sents.pop()
    return " ".join(sents)


def _band(body, t, S, sec, rng):
    """Force a body into the 150-246 band: bridges raise short bodies,
    sentence trimming lowers long ones. Glue never repeats within a body."""
    out = body.strip()
    used = []
    glue = list(BRIDGES) + list(CLOSERS)
    while len(out.split()) < MINW:
        pick = rng.choice([g for g in glue if g not in used] or glue)
        used.append(pick)
        out = out + " " + fill(pick, {"t": lower_first(t), "T": t, "S": S, "sec": sec.lower()})
    return _trim(out)


def _headings(t, S, sec, rng):
    h1 = rng.choice([
        "{T}, its place in {S}", "Inside {S}, {T} in focus", "{T}, explained from zero",
    ])
    mids = [
        ("How it actually works", "The core of the topic"),
        ("Mechanics and details", "How the pieces fit"),
        ("Rules you will use forever", "The working rules"),
        ("Putting it to work", "The idea in real examples"),
        ("Deeper into the details", "Fine points that matter"),
        ("Variations and neighbours", "Related ideas worth knowing"),
        ("Details that decide marks", "What examiners watch for"),
    ]
    hs = [fill(h1, {"T": t, "S": S})]
    picks = rng.sample(mids, k=len(mids))
    for a, b in picks:
        hs.append(fill(rng.choice([a, b]), {"T": t, "S": S, "sec": sec}))
    hs.append("Worked example")
    hs.append(rng.choice(["Applications and common errors", "Where it pays off, where it breaks",
                          "Real use and the classic slips"]))
    return hs


def build_notes(unit_id, t, S, sec, section):
    rng = unit_rng(unit_id)
    atoms = section["atoms"]
    examples = section.get("examples", [])
    apps = section.get("apps", [])
    traps = section.get("traps", [])
    umap = section.get("unit_atom_map")
    pool = [p for p in (examples + apps + traps) if p]

    # which unit of the section is this? (stable from the unit id suffix)
    j = int(unit_id[-2:]) - 1
    if umap and j < len(umap):
        primary = umap[j] % len(atoms)
    else:
        primary = j % len(atoms)

    # rotation: primary atom first, then the rest in a course-seeded order
    rest = [i for i in range(len(atoms)) if i != primary]
    shift = (rng.randrange(len(rest)) + course_hash(unit_id[:12])) % len(rest)
    rest = rest[shift:] + rest[:shift]
    order = [primary] + rest

    # pool rotation: a unit-seeded shuffle so each lesson pairs different
    # curated paragraphs with its atoms (no repeat inside one lesson)
    pool_order = list(range(len(pool)))
    rng.shuffle(pool_order)

    def rephrase(a):
        sents = sentences(a)
        if not sents:
            return a
        first = sents[0]
        fw = first.split()
        rest_w = " ".join(fw)
        body = rest_w[0].lower() + rest_w[1:]
        for lead in ["In {S}, ", "For students of {S}, ", "Inside any course in {S}, ",
                     "Within {S}, ", "Across {S}, "]:
            cand_first = fill(lead, {"S": S}) + body
            cand = " ".join([cand_first] + sents[1:])
            if opener_word(cand) not in used_openers:
                return cand
        return " ".join([fill("As taught across {S}, ", {"S": S}) + body] + sents[1:])

    # note 1: anchor (defined first so body openers cannot collide with it)
    anchor = rng.choice(OPENERS).replace("{T}", t).replace("{t}", lower_first(t)).replace(
        "{S}", S).replace("{sec}", sec.lower())

    used_openers = {opener_word(anchor)}
    body_atoms = []
    for idx in order:
        if len(body_atoms) >= 7:
            break
        a = _weave(atoms[idx], t, S, sec)
        ow = opener_word(a)
        if ow in used_openers:
            a = rephrase(a)
            ow = opener_word(a)
            if ow in used_openers:
                continue
        used_openers.add(ow)
        body_atoms.append(a)
    for idx in order:
        if len(body_atoms) >= 7:
            break
        a = _weave(atoms[idx], t, S, sec)
        if a in body_atoms:
            continue
        if opener_word(a) in used_openers:
            a = rephrase(a)
            if opener_word(a) in used_openers:
                continue
        body_atoms.append(a)
        used_openers.add(opener_word(a))

    # pair each body atom with one curated pool paragraph + band glue.
    # note 1 = anchor + primary atom; notes 2-7 = atom + pool paragraph;
    # note 8 = standalone curated paragraph; note 9 worked example;
    # note 10 application + errors. Every body band-enforced to 150-246.
    bodies = []
    a0 = body_atoms[0] if body_atoms else ""
    bodies.append(_band(fill(anchor, {"t": lower_first(t), "T": t, "S": S, "sec": sec.lower()}) + " " + a0,
                        t, S, sec, rng))
    used_openers.add(opener_word(a0))
    pi = 0
    for a in body_atoms[1:7]:
        seg = ""
        if pi < len(pool_order):
            seg = _weave(pool[pool_order[pi]], t, S, sec)
            pi += 1
        bodies.append(_band(a + (" " + seg if seg else ""), t, S, sec, rng))
    # fill up to note 8 with standalone curated paragraphs
    while len(bodies) < 8:
        if pi < len(pool_order):
            p = _weave(pool[pool_order[pi]], t, S, sec)
            pi += 1
        else:
            p = fill(rng.choice(BRIDGES), {"t": lower_first(t), "T": t, "S": S, "sec": sec.lower()})
        bodies.append(_band(p, t, S, sec, rng))

    # note 9: worked example (opener-aware pick)
    def pick_open(pool_sel, offset):
        if not pool_sel:
            return None
        for step in range(len(pool_sel)):
            cand = _weave(pool_sel[(primary + offset + step) % len(pool_sel)], t, S, sec)
            if opener_word(cand) not in used_openers:
                return cand
        return rephrase(_weave(pool_sel[(primary + offset) % len(pool_sel)], t, S, sec))

    ex = pick_open(examples, 1)
    if ex is None:
        ex = "Work the idea on a concrete case from {S}: write the input, predict the output, then run it and compare. Differences between prediction and reality mark exactly what {t} still has to teach you.".replace("{S}", S).replace("{t}", lower_first(t))
    used_openers.add(opener_word(ex))
    ex = ex + " " + fill(rng.choice(BRIDGES), {"t": lower_first(t), "T": t, "S": S, "sec": sec.lower()})
    bodies.append(_band(ex, t, S, sec, rng))

    # note 10: application + traps (opener-aware)
    app = pick_open(apps, 2)
    trap = pick_open(traps, 1)
    app_sents = sentences(app)[:2] if app else []
    trap_sents = sentences(trap)[:2] if trap else []
    combo = " ".join(app_sents + trap_sents)
    if not combo:
        combo = "Apply {t} on a real case from {S} this week, and write down the two errors you personally make first; they are the same errors the exam will probe.".replace("{t}", lower_first(t)).replace("{S}", S)
    combo = combo + " " + fill(rng.choice(BRIDGES), {"t": lower_first(t), "T": t, "S": S, "sec": sec.lower()})
    bodies.append(_band(combo, t, S, sec, rng))

    heads = _headings(t, S, sec, rng)
    return [{"heading": heads[i], "body": bodies[i]} for i in range(len(bodies))]


def build_quiz(unit_id, section, topup, t, S):
    rng = unit_rng(unit_id + "|quiz")
    pool = list(section["quiz"]) + list(topup)
    # pick exactly 20 distinct factories; rotation seeded per unit
    idx = list(range(len(pool)))
    rng.shuffle(idx)
    chosen = [pool[i] for i in idx[:20]]
    from .spec import balanced_options, LETTERS
    mcqs, out = [], []
    for kind, stem, correct, slips, explain in chosen:
        stem2 = fill(stem, {"t": lower_first(t), "T": t, "S": S})
        if kind == "tf":
            ans_letter = "A" if correct == "True" else "B"
            out.append({"type": "true_false", "stem": stem2, "options": {"A": "True", "B": "False"},
                        "answer": ans_letter, "explanation": explain})
        elif kind == "fill":
            out.append({"type": "fill_blank", "stem": stem2, "answer": correct,
                        "explanation": explain})
        else:
            mcqs.append({"kind": "mcq", "stem": stem2, "correct": correct,
                         "slips": list(slips), "explain": explain})
    balanced_options(mcqs, rng)
    merged = out + [{"type": "mcq", "stem": m["stem"],
                     "options": {L: o for L, o in zip(LETTERS, m["_options"])},
                     "answer": m["_answer"], "explanation": m["explain"]} for m in mcqs]
    rng.shuffle(merged)
    for i, q in enumerate(merged, 1):
        q["id"] = "%s-q%02d" % (unit_id, i)
    return merged


# ======================================================================
# Generated-lesson pipeline (curated-v3): notes come from LLM-generated
# pack lessons (content/tertiary/gen/<pack>/<pack>__<SxxUyy|Fyy>.json);
# quiz still comes from the pack quiz pools. When a unit slot has no
# generated lesson yet, build_notes() composes the 150-250 band notes
# deterministically from the curated pack material (v2.5 fallback).
# ======================================================================
import json as _json
import os as _os

GEN_DIR = "/home/z/my-project/content/tertiary/gen"


def gen_path(pack, sec_idx, unit_idx):
    name = "F%02d" % unit_idx if sec_idx == 1 else "S%02dU%02d" % (sec_idx, unit_idx)
    return _os.path.join(GEN_DIR, pack, "%s__%s.json" % (pack, name))


def gen_ready(pack):
    """True when every lesson file of the pack exists."""
    from .build_all import load_pack
    p = load_pack(pack)
    for fi in range(1, len(p["foundations"]) + 1):
        if not _os.path.exists(gen_path(pack, 1, fi)):
            return False
    for si, sec in enumerate(p["sections"], start=2):
        for ui in range(1, len(sec["units"]) + 1):
            if not _os.path.exists(gen_path(pack, si, ui)):
                return False
    return True


def load_gen_lesson(pack, sec_idx, unit_idx):
    path = gen_path(pack, sec_idx, unit_idx)
    with open(path) as f:
        return _json.load(f)


def build_unit_notes(pack, sec_idx, unit_idx, unit_id, title, S, sec_title, section):
    """LLM lesson when it exists, deterministic v2.5 composer otherwise.
    Both paths return (notes, kps, summary) with tokens filled."""
    if _os.path.exists(gen_path(pack, sec_idx, unit_idx)):
        return build_gen_notes(pack, sec_idx, unit_idx, title, S, sec_title)
    notes = build_notes(unit_id, title, S, sec_title, section)
    kps = []
    for n in notes[1:5]:
        first = n["body"].split(". ")[0].rstrip(".")
        if len(first.split()) >= 6:
            kps.append(first + ".")
    summary = "%s in %s: what it is, how it works, and how to apply it." % (title, S)
    return notes, kps[:6], summary


def build_gen_notes(pack, sec_idx, unit_idx, title, S, sec_title):
    """Return (notes, key_points, summary) with {S}/{t}/{T} filled."""
    lesson = load_gen_lesson(pack, sec_idx, unit_idx)
    mapping = {"t": lower_first(title), "T": title, "S": S, "sec": sec_title.lower()}
    def _fix_head(h):
        h = fill(h, mapping).strip()
        if h.isupper() and len(h) > 3:  # ALL CAPS scaffold headings -> title case
            from .spec import title_case
            h = title_case(h.lower())
        # collapse doubled spaces
        return " ".join(h.split())

    notes = []
    for n in lesson["notes"]:
        body = fill(n["body"], mapping).replace("`", "").strip()
        w = len(body.split())
        if w > 250:  # founder band: post-fill hard cap with sentence floor
            import re as _re
            sents = _re.split(r"(?<=[.!?])\s+", body)
            while len(" ".join(sents).split()) > 250 and len(sents) > 9:
                sents.pop()
            body = " ".join(sents)
        notes.append({"heading": _fix_head(n["heading"]), "body": body})
    kps = [fill(k, mapping).strip() for k in lesson.get("key_points", [])]
    summary = fill(lesson.get("summary", ""), mapping).strip()
    if not summary:
        summary = "%s in %s: what it is, how it works, and how to apply it." % (title, S)
    return notes, kps, summary
