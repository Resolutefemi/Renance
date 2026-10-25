#!/usr/bin/env python3
"""tert/build_all.py — mass-build the tertiary ladder + lessons.

For each of the 3,908 tertiary courses:
- keep its 152 unit_ids (TOP-* for section 1, EU ids for sections 2-15)
- section 1 titles become the pack's 12 FOUNDATIONS topics
- sections 2-15 take the pack's 140 unit topics
- every unit gets a lesson: 10 notes + 20 quiz (LessonBlob envelope)

Outputs (under content/tertiary/build/):
- ladder.jsonl        one line per unit: course_id, uid, seq, sec, title, cat
- blobs_N.jsonl       per worker: shard\tuid\tblob_json  (shard = fnv1a32 % 60000)

Usage: python3 tert/build_all.py [--limit N] [--only PACK] [--workers 8]
"""
import json
import os
import sys
import time
from multiprocessing import Pool

sys.path.insert(0, "/home/z/my-project/scripts")
sys.path.insert(0, "/home/z/my-project/scripts/tert")

OUT = "/home/z/my-project/content/tertiary/build"
SHARDS = 60000

# ------------------------------------------------------------------ fnv1a32
def fnv1a32(data):
    """Byte-exact port of Go's hash/fnv 32a (offset 2166136261, prime 16777619)."""
    h = 2166136261
    for b in data.encode("utf-8"):
        h ^= b
        h = (h * 16777619) & 0xFFFFFFFF
    return h


def shard_of(uid):
    return fnv1a32(uid) % SHARDS


# ------------------------------------------------------------------ packs
PACK_SPECS = {
    "computing_python": {"sections": ["computing_python", "computing_python_b"], "topup": "computing_quiz_topup", "module": True},
    "medicine": None, "education": None, "arts": None, "bio_sciences": None,
    "business": None, "english_lang": None, "agriculture": None,
    "eng_electrical": None, "eng_mechanical": None, "chem_phys": None,
    "eng_civil": None, "data_analytics": None, "social_sciences": None,
    "eng_chemical": None, "law": None, "economics": None,
    "accounting_finance": None, "environment": None, "networking": None,
    "computing_general": None,
}

_pack_cache = {}


def load_pack(name):
    if name in _pack_cache:
        return _pack_cache[name]
    import importlib
    if name == "computing_python":
        a = importlib.import_module("packs.computing_python")
        b = importlib.import_module("packs.computing_python_b")
        top = importlib.import_module("packs.computing_quiz_topup")
        sections = a.SECTIONS + b.SECTIONS
        # merge topup into each section's quiz pool
        merged = []
        for i, s in enumerate(sections, start=2):
            d = dict(s)
            d["quiz"] = list(s["quiz"]) + list(top.TOPUP.get("S%d" % i, []))
            merged.append(d)
        pack = {"sections": merged, "foundations": b.FOUNDATIONS}
    else:
        m = importlib.import_module("packs." + name)
        pack = {"sections": m.SECTIONS, "foundations": m.FOUNDATIONS}
    _pack_cache[name] = pack
    return pack


CATS = ["Core Principles", "Methods & Practice", "Applications", "Theory & Principles",
        "Methods & Techniques", "Applications & Practice"]

SEC1_CATEGORY = "Concepts & Foundations"


def build_one(course):
    """Build ladder rows + lesson blobs for one course. Returns
    (ladder_rows, blob_rows) or None when the pack is not fully generated."""
    from tert.spec import subject_phrase, lower_first
    from tert.router import route
    from tert import build_lesson

    pk = route(course)
    if not build_lesson.gen_ready(pk):
        return None
    pack = load_pack(pk)
    sections = pack["sections"]
    foundations = pack["foundations"]
    S = subject_phrase(course["title"], course["dept_name"])
    cid = course["id"]
    by_uid = {u["uid"]: u for u in course["units"]}

    ladder, blobs = [], []
    # ---- section 1: 12 foundation topics from generated F lessons
    s2 = sections[0]
    s1_units = sorted([u for u in course["units"] if u["sec"] == 1], key=lambda u: u["seq"])
    for j, u in enumerate(s1_units):
        title = foundations[j % len(foundations)]
        ladder.append([cid, u["uid"], u["seq"], 1, title, SEC1_CATEGORY])
        notes, kps, summary = build_lesson.build_gen_notes(pk, 1, j + 1, title, S, s2["title"])
        quiz = build_lesson.build_quiz(u["uid"], s2, [], title, S)
        blobs.append((u["uid"], title, notes, quiz, S, kps, summary))
    # ---- sections 2..15 from generated S lessons
    for k, section in enumerate(sections, start=2):
        for j, ut in enumerate(section["units"], start=1):
            uid = "%s-EU%02d%02d" % (cid, k, j)
            o = by_uid.get(uid)
            seq = o["seq"] if o else (j + (k - 2) * 10 + 12)
            ladder.append([cid, uid, seq, k, ut, CATS[(k - 2) % len(CATS)]])
            notes, kps, summary = build_lesson.build_gen_notes(pk, k, j, ut, S, section["title"])
            quiz = build_lesson.build_quiz(uid, section, [], ut, S)
            blobs.append((uid, ut, notes, quiz, S, kps, summary))
    return ladder, blobs


def make_blob(uid, title, notes, quiz, S, kps=None, summary=None):
    from tert.spec import lower_first
    if not summary:
        summary = "%s in %s: what it is, how it works, and how to apply it." % (title, S)
    if not kps:
        kps = []
        for n in notes[1:5]:
            first = n["body"].split(". ")[0].rstrip(".")
            if len(first.split()) >= 6:
                kps.append(first + ".")
    return {
        "topic_id": uid,
        "title": title,
        "summary": summary,
        "notes": notes,
        "key_points": kps[:6],
        "quiz": quiz,
        "drawings": [],
        "source": "curated-v3",
        "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }


WORKER_ID = 0


def worker(args):
    global WORKER_ID
    wid, courses = args
    ladder_f = os.path.join(OUT, "ladder_%d.jsonl" % wid)
    blob_f = os.path.join(OUT, "blobs_%d.jsonl" % wid)
    n_l = n_b = 0
    with open(ladder_f, "w") as lf, open(blob_f, "w") as bf:
        for c in courses:
            ladder, blobs = build_one(c)
            if ladder is None:
                continue
            for row in ladder:
                lf.write(json.dumps(row, ensure_ascii=False) + "\n")
                n_l += 1
            for uid, title, notes, quiz, S, kps, summary in blobs:
                b = make_blob(uid, title, notes, quiz, S, kps, summary)
                shard = shard_of(uid)
                bf.write(json.dumps([shard, uid, b], ensure_ascii=False, separators=(",", ":")) + "\n")
                n_b += 1
    return wid, n_l, n_b


def init_worker(wid):
    global WORKER_ID
    WORKER_ID = wid


def main():
    limit, only, workers = 0, None, 8
    argv = sys.argv[1:]
    if "--limit" in argv:
        limit = int(argv[argv.index("--limit") + 1])
    if "--only" in argv:
        only = argv[argv.index("--only") + 1]
    if "--workers" in argv:
        workers = int(argv[argv.index("--workers") + 1])

    os.makedirs(OUT, exist_ok=True)
    corpus = json.load(open("/home/z/my-project/content/tertiary/corpus.json"))
    if only:
        from tert.router import route
        corpus = [c for c in corpus if route(c) == only]
    if limit:
        corpus = corpus[:limit]
    print("courses to build:", len(corpus))

    from tert.router import route as _r
    chunks = []
    W = min(workers, max(1, len(corpus) // 8))
    per = (len(corpus) + W - 1) // W
    for i in range(W):
        chunks.append((i, corpus[i * per:(i + 1) * per]))

    t0 = time.time()
    if W == 1:
        results = [worker(chunks[0])]
    else:
        with Pool(W) as p:
            results = p.map(worker, chunks)
    total_l = sum(r[1] for r in results)
    total_b = sum(r[2] for r in results)
    print("built %d ladder rows, %d lessons in %.1f min (skipped courses with incomplete packs)" % (
        total_l, total_b, (time.time() - t0) / 60))


if __name__ == "__main__":
    main()
