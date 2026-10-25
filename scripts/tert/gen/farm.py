#!/usr/bin/env python3
"""farm.py — essay-mode lesson generation farm.

Generates one validated 10-note lesson (250 to 400 words per note) for every
pack unit-topic and foundation topic (3,192 tasks). Essay mode: the model
writes plain prose sections which we parse, post-process and validate.

Resumable: a task is done when its output file exists. Ledger per attempt.
Workers: 2-3 (API concurrency ceiling ~2-3 streams; 429s back off).

Usage:
  python3 farm.py [--workers 3] [--limit N] [--only-pack NAME] [--max-fail N]
  python3 farm.py --status
"""
import json
import os
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from essay_gen import (ESSAY_SYSTEM, build_lesson, essay_feedback_user,  # noqa: E402
                       essay_user, dedupe_s, to_ascii)
from json_repair import loads_lenient  # noqa: E402
from validate_lesson import normalize, validate  # noqa: E402
from zai_client import chat  # noqa: E402

GEN = "/home/z/my-project/content/tertiary/gen"
TASKS = os.path.join(GEN, "tasks.json")
LEDGER = os.path.join(GEN, "ledger.jsonl")

MODELS = ["glm-4-plus", "glm-4-plus", "glm-4-plus", "glm-4.6", "glm-4-plus"]
MAX_ATTEMPTS = 5

lock = threading.Lock()
stats = {"done": 0, "fail": 0, "attempts": 0, "tokens": 0, "start": time.time()}


def out_path(task):
    return os.path.join(GEN, task["pack"], task["id"].replace("/", "__") + ".json")


def _log(tid, attempt, ok, errs, ctok, secs, model):
    with lock:
        with open(LEDGER, "a") as f:
            f.write(json.dumps({"id": tid, "attempt": attempt, "ok": ok,
                                "errs": errs, "ctok": ctok, "secs": round(secs, 1),
                                "model": model, "ts": time.time()},
                               ensure_ascii=False) + "\n")


def run_task(task):
    tid = task["id"]
    op = out_path(task)
    if os.path.exists(op):
        return
    os.makedirs(os.path.dirname(op), exist_ok=True)
    feedback = ""
    prev_lesson = None
    for attempt in range(MAX_ATTEMPTS):
        model = MODELS[attempt % len(MODELS)]
        t0 = time.time()
        if prev_lesson is not None and attempt >= 2:
            user = essay_expand_user(task, prev_lesson, feedback)
        elif feedback:
            short = _short_sections(prev_lesson) if prev_lesson else None
            user = essay_feedback_user(task, feedback.split("; "), short)
        else:
            user = essay_user(task)
        try:
            content, meta = chat(ESSAY_SYSTEM, user, model=model, max_tokens=8192, retries=6)
        except Exception as e:
            _log(tid, attempt + 1, False, ["api: %s" % str(e)[:120]], 0, time.time() - t0, model)
            time.sleep(4)
            continue
        ctok = meta.get("usage", {}).get("completion_tokens", 0)
        with lock:
            stats["attempts"] += 1
            stats["tokens"] += ctok
        try:
            lesson = build_lesson(content, task["unit"])
        except Exception as e:
            _dump(op, content)
            _log(tid, attempt + 1, False, ["parse: %s" % str(e)[:120]], ctok, time.time() - t0, model)
            feedback = "the essay could not be parsed into 10 === sections"
            continue
        lesson = normalize(lesson)
        prev_lesson = lesson
        ok, errs = validate(lesson)
        if ok:
            lesson["model"] = model
            lesson["generated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
            tmp = op + ".tmp"
            with open(tmp, "w") as f:
                json.dump(lesson, f, ensure_ascii=False)
            os.replace(tmp, op)
            _log(tid, attempt + 1, True, [], ctok, time.time() - t0, model)
            with lock:
                stats["done"] += 1
            return
        _dump(op, content)
        _log(tid, attempt + 1, False, errs[:10], ctok, time.time() - t0, model)
        feedback = "; ".join(errs[:10])

    # rescue pass: micro-expand only the failing notes via a JSON call
    if prev_lesson is not None and _rescueable(prev_lesson):
        lesson = _rescue(task, prev_lesson, op, tid)
        if lesson is not None:
            with lock:
                stats["done"] += 1
            return
    with lock:
        stats["fail"] += 1


def _rescueable(lesson):
    """Rescue when most notes are fine and the bad ones are near the band or
    only carry character-level issues (things a targeted rewrite can fix)."""
    notes = lesson.get("notes", [])
    if len(notes) != 10:
        return False
    bad = 0
    for n in notes:
        w = len(n["body"].split())
        if not 250 <= w <= 400 and not 200 <= w <= 470:
            return False
        if not 250 <= w <= 400:
            bad += 1
    return 0 < bad <= 6


def _rescue(task, prev, op, tid):
    notes = prev["notes"]
    payload = []
    for i, n in enumerate(notes, 1):
        payload.append({"index": i, "heading": n["heading"], "words": len(n["body"].split()),
                        "body": n["body"].replace("\n", " ")})
    user = """You wrote a 10-note lesson on "%s" (%s). Some note bodies fail the length rule (each must be 250 to 400 words). Here is the lesson with word counts:

%s

Rewrite ONLY the failing note bodies so every note lands between 280 and 380 words: keep every good sentence, expand thin notes with more mechanism, concrete values and worked steps, trim any note over 400 words. Keep headings and any {S} placeholders exactly as they are.

Return ONLY a JSON object: {"notes": [{"index": 1, "heading": "unchanged", "body": "full rewritten body"}, ...]} containing EVERY note whose body you changed (unchanged notes can be omitted). ASCII only, no "--", no "<" before a letter, no exam or marks talk.""" % (
        task["unit"], task["discipline"], json.dumps({"notes": payload}, ensure_ascii=False, indent=1))
    t0 = time.time()
    try:
        content, meta = chat(ESSAY_SYSTEM, user, model="glm-4-plus", max_tokens=8192, retries=6)
    except Exception as e:
        _log(tid, 99, False, ["rescue api: %s" % str(e)[:100]], 0, time.time() - t0, "glm-4-plus")
        return None
    ctok = meta.get("usage", {}).get("completion_tokens", 0)
    with lock:
        stats["attempts"] += 1
        stats["tokens"] += ctok
    try:
        fixed = loads_lenient(content)
    except Exception as e:
        _log(tid, 99, False, ["rescue json: %s" % str(e)[:100]], ctok, time.time() - t0, "glm-4-plus")
        return None
    merged = {"summary": prev["summary"], "notes": [dict(n) for n in notes],
              "key_points": list(prev["key_points"])}
    changed = 0
    for fn in fixed.get("notes", []):
        try:
            i = int(fn.get("index", 0)) - 1
        except Exception:
            continue
        if not 0 <= i < 10 or not fn.get("body"):
            continue
        b = to_ascii(str(fn["body"]))
        b = dedupe_s(b)
        merged["notes"][i] = {"heading": (fn.get("heading") or notes[i]["heading"]).strip(),
                              "body": b.strip()}
        changed += 1
    if not changed:
        _log(tid, 99, False, ["rescue changed nothing"], ctok, time.time() - t0, "glm-4-plus")
        return None
    merged = normalize(merged)
    ok, errs = validate(merged)
    if ok:
        merged["model"] = "glm-4-plus+rescue"
        merged["generated_at"] = time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
        tmp = op + ".tmp"
        with open(tmp, "w") as fo:
            json.dump(merged, fo, ensure_ascii=False)
        os.replace(tmp, op)
        _log(tid, 99, True, ["rescue"], ctok, time.time() - t0, "glm-4-plus")
        return merged
    _log(tid, 99, False, ["rescue still failing: " + "; ".join(errs[:5])], ctok,
         time.time() - t0, "glm-4-plus")
    return None


def _short_sections(lesson):
    if not lesson:
        return None
    return [i + 1 for i, n in enumerate(lesson.get("notes", []))
            if len(n["body"].split()) < 250]


def _dump(op, content):
    try:
        with open(op + ".rawfail", "w") as f:
            f.write(content)
    except Exception:
        pass


def essay_expand_user(task, prev, errs):
    import json as _json
    secs = []
    for i, n in enumerate(prev.get("notes", []), 1):
        secs.append("SECTION %d (%d words): %s\n%s" % (
            i, len(n["body"].split()), n["heading"], n["body"].replace("\n", " ")))
    return """You previously wrote this lesson on the unit topic "%s" (discipline: %s), but it was rejected:

%s

The previous lesson:

%s

Rewrite the COMPLETE lesson as 10 sections in the === format (HEADING line, then 4 paragraphs). Keep the good content, but fix every rejected section: sections under 250 words must be expanded with more mechanism, concrete values and worked steps; sections over 400 words trimmed; any banned characters removed. Every section: 4 paragraphs, 4 to 6 sentences each, 260 to 390 words. Keep {S} in 3 to 6 sections, once per section. All 10 sections required.""" % (
        task["unit"], task["discipline"], "; ".join(errs[:10]) if isinstance(errs, str) else "; ".join(errs),
        "\n\n".join(secs))


def progress_line():
    el = time.time() - stats["start"]
    done = stats["done"]
    rate = done / (el / 60) if el > 60 else 0
    return ("done=%d fail=%d attempts=%d tokens=%dk elapsed=%.0fm rate=%.1f/min" % (
        done, stats["fail"], stats["attempts"], stats["tokens"] // 1000, el / 60, rate))


def main():
    argv = sys.argv[1:]
    if "--status" in argv:
        tasks = json.load(open(TASKS))
        done = sum(1 for t in tasks if os.path.exists(out_path(t)))
        print("tasks=%d done=%d remaining=%d" % (len(tasks), done, len(tasks) - done))
        by_pack = {}
        for t in tasks:
            d = by_pack.setdefault(t["pack"], [0, 0])
            d[1] += 1
            if os.path.exists(out_path(t)):
                d[0] += 1
        for pk, (dn, tt) in sorted(by_pack.items(), key=lambda kv: -kv[1][1]):
            print("  %-20s %3d/%3d" % (pk, dn, tt))
        return

    workers, limit, only, max_fail = 3, 0, None, 400
    if "--workers" in argv:
        workers = int(argv[argv.index("--workers") + 1])
    if "--limit" in argv:
        limit = int(argv[argv.index("--limit") + 1])
    if "--only-pack" in argv:
        only = argv[argv.index("--only-pack") + 1]
    if "--max-fail" in argv:
        max_fail = int(argv[argv.index("--max-fail") + 1])

    tasks = json.load(open(TASKS))
    if only:
        tasks = [t for t in tasks if t["pack"] == only]
    pending = [t for t in tasks if not os.path.exists(out_path(t))]
    if limit:
        pending = pending[:limit]
    print("farm start: %d pending (%d total), workers=%d" % (len(pending), len(tasks), workers))
    sys.stdout.flush()

    stop = threading.Event()

    def watcher():
        while not stop.wait(300):
            with lock:
                line = progress_line()
                fails = stats["fail"]
            print("  [%s] %s" % (time.strftime("%H:%M:%S"), line))
            sys.stdout.flush()
            if fails >= max_fail:
                print("  too many failures, stopping")
                os._exit(3)

    th = threading.Thread(target=watcher, daemon=True)
    th.start()
    t0 = time.time()
    with ThreadPoolExecutor(workers) as ex:
        list(ex.map(run_task, pending))
    stop.set()
    print("farm finished: %s in %.0f min" % (progress_line(), (time.time() - t0) / 60))
    sys.stdout.flush()


if __name__ == "__main__":
    main()
