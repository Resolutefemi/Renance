#!/usr/bin/env python3
"""
Renance CBT content pipeline (ERA-2) — ports the ERA-1 adapter contract.

DOCTRINE (ADR-0003): one bank in `data/src/` → TWO artifacts.
  bundle   data/questions/<code>.json     student-visible, NEVER answer material
  key      data/answer-keys/<sub>/<code>.json   server-only (subdir gitignored
           except mock/); explanations live ONLY here
  manifest data/manifest.json             sha256 fingerprint of every bundle

Ingested source shapes (evidence-based, from the founder's real banks):
  1. bare array of questions                      (jamb biology.json)
  2. {course,title,total,questions[]}             (sen101_questions.json)
  3. options as record {a..d | A..D}              (both repos)
  4. options as [{letter,text,correct}]           (COS102_500.json)
  5. bare string options array                    (AMS101, MTH101, STA111...)
  6. answer: "c" | correct_letter: "B"            (COS102, GST112)
  7. answer given as full option TEXT             (matched back to a letter)
  8. text questions: answers: ["Science", ...]    (CVE105)
Plus UTF-8 BOM stripping (english.json), missing ids, duplicate ids.

Usage:
  python3 tools/cbt-build/build.py                 # build every src bank
  python3 tools/cbt-build/build.py --only jamb     # banks whose code contains str
Exit code 0 only if every bank produced at least one kept question.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
SRC_DIRS = [REPO / "data" / "src" / "mock", REPO / "data" / "src" / "real"]
QUESTIONS_DIR = REPO / "data" / "questions"
KEYS_DIR = REPO / "data" / "answer-keys"
LETTERS = "ABCDEFGH"
FORBIDDEN_IN_BUNDLE = {"answer", "answers", "correct", "correct_letter",
                       "correctletter", "correctoption", "explanation", "is_correct"}


def strip_bom(text: str) -> str:
    return text[1:] if text[:1] == "﻿" else text


def norm_text(s: str) -> str:
    return re.sub(r"\s+", " ", str(s).strip().lower())


def code_from_filename(path: Path) -> str:
    stem = re.sub(r"\.json$", "", path.name, flags=re.I)
    stem = re.sub(r"_(questions|500|objectives)$", "", stem, flags=re.I)
    code = re.sub(r"[^a-z0-9]+", "-", stem.lower()).strip("-")
    return code or "bank"


def extract_options(q: dict) -> tuple[str, dict[str, str]]:
    """Returns (style, options{letter:text}) — ports ERA-1 extractOptions."""
    rec = q.get("options", q.get("option"))
    out: dict[str, str] = {}
    if isinstance(rec, dict):
        for k, v in rec.items():
            if isinstance(v, str) and v.strip():
                out[k.strip().upper()] = v.strip()
        return ("record", out) if len(out) >= 2 else ("none", {})
    if isinstance(rec, list):
        string_items = 0
        for item in rec:
            if isinstance(item, str):
                if string_items < len(LETTERS) and item.strip():
                    out[LETTERS[string_items]] = item.strip()
                string_items += 1
            elif isinstance(item, dict):
                letter = str(item.get("letter", "")).strip().upper()
                text = str(item.get("text", "")).strip()
                if re.fullmatch(r"[A-H]", letter) and text:
                    out[letter] = text
        return ("array", out) if len(out) >= 2 else ("none", {})
    return ("none", {})


def extract_answer(q: dict, options: dict[str, str]) -> tuple[str | None, list[str] | None, str | None]:
    """Returns (letter, accepted_text_list, error)."""
    raw = q.get("answer", q.get("correct", q.get("correct_letter")))
    if raw is None and isinstance(q.get("answers"), list):
        return (None, [str(a) for a in q["answers"] if str(a).strip()], None)
    if raw is None:
        # variant 4: correct=true inside options array
        if isinstance(q.get("options"), list):
            for item in q["options"]:
                if isinstance(item, dict) and item.get("correct") is True:
                    letter = str(item.get("letter", "")).strip().upper()
                    if letter and letter in options:
                        return (letter, None, None)
        return (None, None, "no answer field found")
    if isinstance(raw, str) and raw.strip():
        up = raw.strip().upper()
        if re.fullmatch(r"[A-H]", up):
            if up not in options:
                return (None, None, f"answer {up} has no matching option")
            return (up, None, None)
        # full-text answer → resolve to letter
        for letter, text in options.items():
            if norm_text(text) == norm_text(raw):
                return (letter, None, None)
        return (None, None, f"answer text {raw[:40]!r} matches no option")
    return (None, None, "unsupported answer type")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", default="", help="substring filter on source filename")
    ap.add_argument("--version", default="era2-g1", help="manifest version label")
    args = ap.parse_args()

    QUESTIONS_DIR.mkdir(parents=True, exist_ok=True)
    banks_built: list[str] = []
    report: list[dict] = []

    for src_dir in SRC_DIRS:
        if not src_dir.is_dir():
            continue
        for path in sorted(src_dir.glob("*.json")):
            if args.only and args.only.lower() not in path.name.lower():
                continue
            entry = {"file": str(path.relative_to(REPO)), "kept": 0, "mcq": 0,
                     "text": 0, "dropped": [], "fixes": []}
            try:
                raw_text = path.read_text(encoding="utf-8")
                data = json.loads(strip_bom(raw_text))
            except Exception as exc:  # noqa: BLE001
                entry["dropped"].append({"index": -1, "reason": f"unparseable: {exc}"})
                report.append(entry)
                continue

            questions = data if isinstance(data, list) else data.get("questions", [])
            code = str(data.get("code")) if isinstance(data, dict) and data.get("code") else code_from_filename(path)
            title = (data.get("title") or data.get("course") or code) if isinstance(data, dict) else code
            duration = data.get("durationMinutes") if isinstance(data, dict) else None
            if isinstance(data, dict) and data.get("duration_minutes") and not duration:
                duration = data["duration_minutes"]

            bundle_questions: list[dict] = []
            key_answers: dict[str, dict] = {}
            seen_ids: set[str] = set()

            for i, q in enumerate(questions if isinstance(questions, list) else []):
                if not isinstance(q, dict):
                    entry["dropped"].append({"index": i, "reason": "not an object"})
                    continue
                stem = str(q.get("question") or q.get("stem") or q.get("text") or "").strip()
                if not stem:
                    entry["dropped"].append({"index": i, "reason": "no stem"})
                    continue
                style, options = extract_options(q)
                letter, accepted, err = extract_answer(q, options)
                if err and accepted is None:
                    entry["dropped"].append({"index": i, "reason": err})
                    continue

                qtype = "mcq" if options else "text"
                if qtype == "text" and not accepted:
                    entry["dropped"].append({"index": i, "reason": "text question without accepted answers"})
                    continue

                qid = str(q.get("id") or f"{code}-{i + 1:04d}")
                if qid in seen_ids:
                    entry["fixes"].append(f"duplicate id {qid} renumbered")
                    qid = f"{code}-{i + 1:04d}"
                seen_ids.add(qid)

                if style == "array":
                    entry["fixes"].append(f"q{i + 1}: options array normalized")
                if letter is None and accepted:
                    entry["fixes"].append(f"q{i + 1}: text question ({len(accepted)} accepted forms)")

                bundle_questions.append({
                    "id": qid,
                    "type": qtype,
                    "stem": stem,
                    **({"options": options} if qtype == "mcq" else {}),
                    "marks": int(q.get("marks") or 1),
                    **({"topic": str(q["topic"])} if q.get("topic") else {}),
                    **({"difficulty": str(q["difficulty"])} if q.get("difficulty") else {}),
                })
                if qtype == "mcq":
                    key_answers[qid] = {"type": "mcq", "letter": letter,
                                        **({"explanation": str(q["explanation"])} if q.get("explanation") else {})}
                    entry["mcq"] += 1
                else:
                    key_answers[qid] = {"type": "text", "accepted": accepted}
                    entry["text"] += 1
                entry["kept"] += 1

            if entry["kept"] == 0:
                report.append(entry)
                continue

            total_marks = sum(q["marks"] for q in bundle_questions)
            bundle = {
                "code": code,
                "title": title,
                "version": int(data.get("version") or 1) if isinstance(data, dict) else 1,
                "questionCount": len(bundle_questions),
                "totalMarks": total_marks,
                "questions": bundle_questions,
                **({"durationMinutes": int(duration)} if duration else {}),
                **({"category": str(data["category"])} if isinstance(data, dict) and data.get("category") else {}),
                **({"body": str(data["body"])} if isinstance(data, dict) and data.get("body") else {}),
            }
            # doctrine guard: never emit forbidden keys into a bundle
            def check(node, where="bundle"):
                if isinstance(node, dict):
                    for k, v in node.items():
                        if k.lower().replace("-", "_") in FORBIDDEN_IN_BUNDLE:
                            raise SystemExit(f"FATAL: forbidden key '{k}' in {code} {where}")
                        check(v, where)
                elif isinstance(node, list):
                    for v in node:
                        check(v, where)
            check(bundle)

            (QUESTIONS_DIR / f"{code}.json").write_text(
                json.dumps(bundle, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
            keys_sub = KEYS_DIR / "mock"
            keys_sub.mkdir(parents=True, exist_ok=True)
            (keys_sub / f"{code}.json").write_text(
                json.dumps({"code": code, "answers": key_answers}, ensure_ascii=False, indent=2) + "\n",
                encoding="utf-8")
            banks_built.append(code)
            report.append(entry)

    # Rebuild the manifest over EVERY bundle on disk (self-healing).
    exams = []
    for f in sorted(QUESTIONS_DIR.glob("*.json")):
        b = json.loads(f.read_text(encoding="utf-8"))
        raw = f.read_bytes()
        exams.append({
            "code": b["code"], "title": b.get("title", b["code"]),
            "questionCount": b["questionCount"], "totalMarks": b.get("totalMarks", 0),
            **({"durationMinutes": b["durationMinutes"]} if b.get("durationMinutes") else {}),
            **({"category": b["category"]} if b.get("category") else {}),
            **({"body": b["body"]} if b.get("body") else {}),
            "bundleSha256": hashlib.sha256(raw).hexdigest(),
            "sizeBytes": len(raw),
        })
    manifest = {
        "generatedAt": dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds"),
        "version": args.version,
        "exams": exams,
    }
    (REPO / "data" / "manifest.json").write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")

    for entry in report:
        status = "ok" if entry["kept"] else "EMPTY"
        print(f"{entry['file']}: kept={entry['kept']} mcq={entry['mcq']} text={entry['text']} "
              f"dropped={len(entry['dropped'])} [{status}]")
        for drop in entry["dropped"][:5]:
            print(f"   dropped #{drop['index']}: {drop['reason']}")
        if entry["fixes"][:3]:
            print(f"   fixes: {'; '.join(entry['fixes'][:3])}")
    print(f"manifest: {len(exams)} packs fingerprinted → data/manifest.json")
    return 0 if any(e["kept"] for e in report) else 1


if __name__ == "__main__":
    sys.exit(main())
