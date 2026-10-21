#!/usr/bin/env python3
"""Parse the Google-Drive-harvested FUTA past-question PDFs into banks.

Handles the three gdrive formats beyond the standard parser:
  1. "A) text" options with a lone ✅ line marking the correct option
  2. "Question N : stem" + bare-letter options + "Answer to question N is X"
  3. broken-metrics PDFs -> routed through abc_pdf_reconstruct

Banks into data/questions/All_tertiary_Q/futa/<COURSE>.json with stem
dedup against the existing uni-futa-* banks.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from abc_parse_bank import parse_mcqs, dedup, normalize_math_unicode  # noqa: E402
from abc_pdf_reconstruct import extract_pdf as reconstruct_pdf  # noqa: E402

REPO = Path(__file__).resolve().parents[1]
GD = REPO / "data" / "src" / "gdrive"
ALL_TERT = REPO / "data" / "questions" / "All_tertiary_Q"

Q2_RE = re.compile(r"^Question\s+(\d+)\s*[:.\)]\s*(.+)$", re.I)
OPT_PAREN_RE = re.compile(r"^\(?([A-Da-d])[\)\].:]\s*(.*)$")
OPT_BARE_RE = re.compile(r"^([A-D])\s+(\S.*)$")
ANS_Q_RE = re.compile(r"^Answer\s+to\s+question\s*(\d+)\s+is\s*\(?([A-Da-d])", re.I)
ANS_PLAIN_RE = re.compile(r"^(?:Ans(?:wer)?\s*[:.\-=]|\*)\s*\(?([A-Da-d])\)?\b", re.I)
CHECK_RE = re.compile(r"^\W*(✅|✔|√|\[correct\]|\*correct\*|correct)\W*$", re.I)
COURSE_RE = re.compile(r"(?<![A-Za-z])([A-Z]{2,4})\s?[-/]?(\d{3})(?![0-9])")

CANON = {"MTS": "MTS", "GNS": "GNS", "GST": "GST", "CSC": "CSC", "CHE": "CHE",
         "BIO": "BIO", "PHY": "PHY", "MEE": "MEE", "STA": "STA", "ECO": "ECO",
         "ANT": "ANT", "MCB": "MCB", "BCH": "BCH", "AME": "AME", "FSN": "FSN"}


def best_text(pdf: Path) -> str:
    """layout -> raw -> coordinate reconstruction, best-scored."""
    cands = []
    txt = pdf.with_suffix("").with_suffix(".txt")
    if txt.exists():
        cands.append(txt.read_text(errors="ignore"))
    else:
        t2 = pdf.with_suffix(".txt")
        if t2.exists():
            cands.append(t2.read_text(errors="ignore"))
    try:
        r = subprocess.run(["pdftotext", "-layout", str(pdf), "-"],
                           capture_output=True, text=True, timeout=120)
        cands.append(r.stdout)
    except Exception:  # noqa: BLE001
        pass
    try:
        cands.append(reconstruct_pdf(str(pdf)))
    except Exception:  # noqa: BLE001
        pass
    if not cands:
        return ""

    def score(t: str) -> int:
        opts = sum(len(re.findall(rf"^\s*\(?{c}[\).\s]", t, re.M)) for c in "ABCD")
        ans = len(re.findall(r"answer|✅|Ans\b", t, re.I))
        # penalise vertical scrambling (words joined without spaces)
        joined = len(re.findall(r"[a-z]{15,}", t))
        return opts + 3 * ans - 2 * joined

    return max(cands, key=score)


def parse_gdrive(text: str) -> list[dict]:
    text = normalize_math_unicode(text)
    lines = [ln for ln in text.splitlines()]
    questions: list[dict] = []
    cur = None
    answers_by_num: dict[int, str] = {}

    def flush():
        nonlocal cur
        if cur is None:
            return
        ans = cur.get("answer") or answers_by_num.get(cur["num"])
        opts = {k: " ".join(v).strip() for k, v in cur["opts"].items()}
        stem = " ".join(cur["stem"]).strip()
        if (len(stem) >= 10 and isinstance(ans, str) and ans in "ABCD" and all(opts.get(c) for c in "ABCD")
                and len(opts) == 4):
            questions.append({"num": cur["num"], "stem": stem,
                              "options": opts, "answer": ans})
        cur = None

    pending_answer = False
    for raw in lines:
        line = raw.strip()
        if not line:
            continue
        if CHECK_RE.match(line):
            # marks the last option line seen
            if cur is not None:
                for c in "DCBA":
                    if cur["opts"][c]:
                        cur["answer"] = cur.get("answer") or c
                        break
            continue
        aqm = ANS_Q_RE.match(line)
        if aqm:
            answers_by_num[int(aqm.group(1))] = aqm.group(2).upper()
            flush()
            continue
        apm = ANS_PLAIN_RE.match(line)
        if apm and cur is not None:
            cur["answer"] = apm.group(1).upper()
            flush()
            continue
        if re.match(r"^ans{1,2}wer\s*:?\s*$", line, re.I):
            pending_answer = True
            continue
        if pending_answer:
            pending_answer = False
            m = re.match(r"^\(?([A-Da-d])\)?\s*$", line)
            if m and cur is not None:
                cur["answer"] = m.group(1).upper()
                flush()
                continue

        q2 = Q2_RE.match(line)
        om = OPT_PAREN_RE.match(line) or OPT_BARE_RE.match(line)
        if q2:
            flush()
            cur = {"num": int(q2.group(1)), "stem": [q2.group(2)],
                   "opts": {c: [] for c in "ABCD"}, "answer": None}
            continue
        # numeric question marker
        qm = re.match(r"^(\d{1,3})[\.\)]\s*(.+)$", line)
        if qm and (cur is None or int(qm.group(1)) > (cur["num"] if cur else 0)):
            flush()
            cur = {"num": int(qm.group(1)), "stem": [qm.group(2)],
                   "opts": {c: [] for c in "ABCD"}, "answer": None}
            # inline "A) ..." on the stem line
            im = re.search(r"\s\(?A\)\s*(.+)$", cur["stem"][0])
            if im:
                cur["stem"][0] = cur["stem"][0][: im.start()]
                cur["opts"]["A"].append(im.group(1))
            continue
        if cur is not None and om and om.group(2):
            letter = om.group(1).upper()
            cur["opts"][letter].append(om.group(2))
            continue
        if cur is not None:
            if any(cur["opts"][c] for c in "ABCD"):
                for c in "DCBA":
                    if cur["opts"][c]:
                        cur["opts"][c].append(line)
                        break
            else:
                cur["stem"].append(line)
    flush()

    # attach late answers
    for q in questions:
        if not q.get("answer") or q["answer"] not in "ABCD":
            q["answer"] = answers_by_num.get(q["num"], q.get("answer"))
    return [q for q in questions if q.get("answer") in "ABCD"]


def _build_listing_map() -> list[tuple[str, tuple[str, str]]]:
    """normalized(full/path/name) -> (code, display), longest-first."""
    out = []
    listing = GD / "listing.jsonl"
    if not listing.exists():
        return out
    for line in listing.open():
        try:
            e = json.loads(line)
        except Exception:  # noqa: BLE001
            continue
        parts = [p for p in e.get("path", "").split("/") if p]
        course = None
        for i, p in enumerate(parts):
            if "past question" in p.lower() and i > 0:
                m = COURSE_RE.search(parts[i - 1].upper())
                if m:
                    dept, num = m.group(1), m.group(2)
                    dept = CANON.get(dept, dept)
                    course = (f"{dept}{num}", f"{dept} {num}")
                break
        if not course:
            continue
        raw = e.get("path", "")
        if raw.lower().endswith(".pdf"):
            raw = raw[:-4]
        norm = re.sub(r"[^A-Za-z0-9]+", "", raw).lower()
        if len(norm) >= 10:
            out.append((norm, course))
    out.sort(key=lambda t: -len(t[0]))
    return out


_LISTING_MAP: list[tuple[str, tuple[str, str]]] | None = None


def course_from_listing(filename: str) -> tuple[str, str] | None:
    """Match a flattened download name against listing paths (normalized),
    longest listing path wins so short generic names can't steal matches."""
    global _LISTING_MAP
    if _LISTING_MAP is None:
        _LISTING_MAP = _build_listing_map()
    wanted = filename[:-8] if filename.endswith(".pdf.pdf") else filename[:-4] if filename.endswith(".pdf") else filename
    wanted_norm = re.sub(r"[^A-Za-z0-9]+", "", wanted).lower()
    for norm, course in _LISTING_MAP:
        if norm in wanted_norm:
            return course
    return None


def course_of(filename: str) -> tuple[str, str] | None:
    got = course_from_listing(filename)
    if got:
        return got
    m = COURSE_RE.search(filename.upper())
    if not m:
        return None
    dept, num = m.group(1), m.group(2)
    dept = CANON.get(dept, dept)
    return f"{dept}{num}", f"{dept} {num}"


def main() -> None:
    dry = "--dry" in sys.argv
    files = [p for p in sorted(GD.glob("*.pdf")) if "past question" in p.name.lower()]
    print(f"gdrive PQ pdfs: {len(files)}")

    by_course: dict[str, dict] = {}
    for pdf in files:
        txt = best_text(pdf)
        qs = dedup(parse_gdrive(txt))
        if not qs:
            qs = dedup(parse_mcqs(txt))  # fall back to the standard parser
        cc = course_of(pdf.name)
        if not qs or not cc:
            if qs and not cc:
                print(f"  [no course code] {pdf.name[:60]} ({len(qs)} mcqs)")
            continue
        code, display = cc
        g = by_course.setdefault(code, {"display": display, "qs": [], "files": 0})
        g["qs"].extend(qs)
        g["files"] += 1

    report = []
    total_banked = 0
    for code, g in sorted(by_course.items()):
        qs = dedup(g["qs"])
        if not qs:
            continue
        school = "futa"
        path = ALL_TERT / school / f"{code.upper()}.json"
        bank_code = f"uni-{school}-{code.lower()}-bank"
        existing = None
        if path.exists():
            existing = json.loads(path.read_text())
            if existing.get("code") != bank_code:
                print(f"  !! {path} has code {existing.get('code')}, expected {bank_code} - merging anyway")
        seen = set()
        if existing:
            for q in existing["questions"]:
                seen.add(re.sub(r"\W+", "", q["stem"].lower())[:120])
        fresh = [q for q in qs if re.sub(r"\W+", "", q["stem"].lower())[:120] not in seen]
        if not fresh:
            report.append((code, len(qs), 0))
            continue
        if existing:
            base = len(existing["questions"])
            for i, q in enumerate(fresh, 1):
                existing["questions"].append({
                    "id": f"{bank_code}-{base + i:04d}",
                    "type": "mcq",
                    "stem": q["stem"],
                    "options": {k: q["options"].get(k, "") for k in "ABCD"},
                    "marks": 1,
                    "answer": q["answer"],
                    "explanation": "",
                })
            existing["questionCount"] = len(existing["questions"])
            existing["totalMarks"] = len(existing["questions"])
            bank = existing
        else:
            bank = {
                "code": bank_code,
                "title": f"FUTA {g['display']} | Course Question Bank",
                "version": 1,
                "questionCount": len(fresh),
                "totalMarks": len(fresh),
                "questions": [
                    {
                        "id": f"{bank_code}-{i:04d}",
                        "type": "mcq",
                        "stem": q["stem"],
                        "options": {k: q["options"].get(k, "") for k in "ABCD"},
                        "marks": 1,
                        "answer": q["answer"],
                        "explanation": "",
                    }
                    for i, q in enumerate(fresh, 1)
                ],
                "category": "university",
                "body": "University Modules",
            }
        report.append((code, len(qs), len(fresh)))
        total_banked += len(fresh)
        if not dry:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(json.dumps(bank, indent=1, ensure_ascii=False), encoding="utf-8")

    print("\ncourse | parsed | new banked")
    for code, n, fresh in report:
        print(f"  {code:<8} {n:>5}  {fresh:>5}")
    print(f"\nTOTAL new banked: {total_banked} {'(DRY)' if dry else ''}")


if __name__ == "__main__":
    main()
