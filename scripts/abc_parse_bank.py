#!/usr/bin/env python3
"""Parse abstechconnect past-question papers into Renance MCQ banks.

Handles the dominant layout:  `N. stem`  `A. opt` ... `D. opt`  `ANSWER: X`

- Text source: prefers <stem>.ocr.txt (OCR) when it has more content than
  pdftotext output; retries raw (no -layout) extraction when the layout pass
  looks vertically scrambled.
- Validation: stem >= 8 chars, >= 3 non-empty options, answer letter in A-D.
- Dedup: by normalized stem within a paper, and against existing Renance
  bank questions for the same school+course.

Usage (library mode):
    python3 abc_parse_bank.py <libraryId>            # prints JSON stats + preview
    python3 abc_parse_bank.py --all                  # parse every text/ocr paper
"""
import json
import re
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from abc_pdf_reconstruct import extract_pdf as reconstruct_pdf  # noqa: E402

SRC = Path("/home/z/my-project/renance/data/src/abstechconnect")
PDF_DIR = SRC / "pdfs"
REPO = SRC.parents[2]

OPT_RE = re.compile(r"^\s*\(?([A-Da-d])[\.\)]\s*(.+)$")
Q_RE = re.compile(r"^\s*(\d{1,3})[\.\)]\s*(.+)$")
ANS_RE = re.compile(r"ans{1,2}wer\s*[:\-]?\s*\(?([A-Da-d])\)?\s*$", re.I)
ANS_INLINE_RE = re.compile(r"ans{1,2}wer\s*[:\-]?\s*\(?([A-Da-d])\)?\s*[\.\)]?$", re.I)
# answer embedded at the end of an option/stem line:  "D. U - B Answer: B"
ANS_TAIL_RE = re.compile(r"^(.*?)\s*ans{1,2}wer\s*[:\-]?\s*\(?([A-Da-d])\)?\s*[\.]?$", re.I)
# bare "ANSWER:" or "ANSWER" line -> letter comes on the next line
ANS_BARE_RE = re.compile(r"^ans{1,2}wer\s*[:\-]?$", re.I)
NEXT_LETTER_RE = re.compile(r"^\(?\s*([A-Da-d])\s*[\.)]?\s*$")


def load_text(stem: str) -> tuple[str, str]:
    """Return (text, mode) choosing the best extraction for a pdf stem."""
    pdf = PDF_DIR / (stem + ".pdf")
    ocr = PDF_DIR / (stem + ".ocr.txt")
    lay = PDF_DIR / (stem + ".txt")

    ocr_txt = ocr.read_text(errors="ignore") if ocr.exists() else ""
    lay_txt = lay.read_text(errors="ignore") if lay.exists() else ""

    # raw extraction (no -layout) — often fixes column scrambling
    raw_txt = ""
    try:
        r = subprocess.run(["pdftotext", str(pdf), "-"], capture_output=True,
                           text=True, timeout=120)
        raw_txt = r.stdout
    except Exception:  # noqa: BLE001
        pass

    # coordinate reconstruction — fixes bogus-metric PDFs
    rec_txt = ""
    try:
        rec_txt = reconstruct_pdf(str(pdf))
    except Exception:  # noqa: BLE001
        pass

    def score(t: str) -> int:
        # more answer markers + balanced option letters = better
        opts = sum(len(re.findall(rf"^\s*{c}[\.\)]", t, re.M)) for c in "ABCD")
        ans = len(re.findall(r"ans{1,2}wer", t, re.I))
        return opts + 3 * ans

    cands = {"ocr": ocr_txt, "layout": lay_txt, "raw": raw_txt, "recon": rec_txt}
    best = max(cands, key=lambda k: score(cands[k]))
    return cands[best], best


def normalize_math_unicode(text: str) -> str:
    """Map Mathematical Alphanumeric Symbols (U+1D400-U+1D7FF) to ASCII."""
    out = []
    for ch in text:
        cp = ord(ch)
        if 0x1D400 <= cp <= 0x1D7FF:
            base = None
            if 0x1D400 <= cp <= 0x1D419:      # bold caps
                base = cp - 0x1D400 + ord('A')
            elif 0x1D434 <= cp <= 0x1D44D:    # italic caps
                base = cp - 0x1D434 + ord('A')
            elif 0x1D44E <= cp <= 0x1D467:    # italic small (hole at 0x1D455)
                if cp == 0x1D455:
                    base = ord('h')
                else:
                    off = cp - 0x1D44E
                    base = ord('a') + (off if off < 7 else off)
            elif 0x1D468 <= cp <= 0x1D481:    # bold italic caps
                base = cp - 0x1D468 + ord('A')
            elif 0x1D482 <= cp <= 0x1D49B:    # bold italic small
                base = cp - 0x1D482 + ord('a')
            elif 0x1D49C <= cp <= 0x1D4B5:    # script caps
                base = cp - 0x1D49C + ord('A')
            elif 0x1D4B6 <= cp <= 0x1D4CF:    # script small
                base = cp - 0x1D4B6 + ord('a')
            elif 0x1D4D0 <= cp <= 0x1D4E9:    # bold script caps
                base = cp - 0x1D4D0 + ord('A')
            elif 0x1D4EA <= cp <= 0x1D503:    # bold script small
                base = cp - 0x1D4EA + ord('a')
            elif 0x1D504 <= cp <= 0x1D51D:    # fraktur caps
                base = cp - 0x1D504 + ord('A')
            elif 0x1D51E <= cp <= 0x1D537:    # fraktur small
                base = cp - 0x1D51E + ord('a')
            elif 0x1D538 <= cp <= 0x1D551:    # double-struck caps
                base = cp - 0x1D538 + ord('A')
            elif 0x1D552 <= cp <= 0x1D56B:    # double-struck small
                base = cp - 0x1D552 + ord('a')
            elif 0x1D56C <= cp <= 0x1D585:    # bold fraktur caps
                base = cp - 0x1D56C + ord('A')
            elif 0x1D586 <= cp <= 0x1D59F:    # bold fraktur small
                base = cp - 0x1D586 + ord('a')
            elif 0x1D5A0 <= cp <= 0x1D5B9:    # sans-serif caps
                base = cp - 0x1D5A0 + ord('A')
            elif 0x1D5BA <= cp <= 0x1D5D3:    # sans-serif small
                base = cp - 0x1D5BA + ord('a')
            elif 0x1D5D4 <= cp <= 0x1D5ED:    # sans bold caps
                base = cp - 0x1D5D4 + ord('A')
            elif 0x1D5EE <= cp <= 0x1D607:    # sans bold small
                base = cp - 0x1D5EE + ord('a')
            elif 0x1D608 <= cp <= 0x1D621:    # sans italic caps
                base = cp - 0x1D608 + ord('A')
            elif 0x1D622 <= cp <= 0x1D63B:    # sans italic small
                base = cp - 0x1D622 + ord('a')
            elif 0x1D63C <= cp <= 0x1D655:    # sans bold italic caps
                base = cp - 0x1D63C + ord('A')
            elif 0x1D656 <= cp <= 0x1D66F:    # sans bold italic small
                base = cp - 0x1D656 + ord('a')
            elif 0x1D670 <= cp <= 0x1D689:    # monospace caps
                base = cp - 0x1D670 + ord('A')
            elif 0x1D68A <= cp <= 0x1D6A3:    # monospace small
                base = cp - 0x1D68A + ord('a')
            elif 0x1D6A8 <= cp <= 0x1D6C1:    # bold math caps
                base = cp - 0x1D6A8 + ord('A')
            elif 0x1D6C2 <= cp <= 0x1D6DB:    # bold math italic small
                base = cp - 0x1D6C2 + ord('a')
            elif 0x1D6DC <= cp <= 0x1D6F5:    # bold sans caps
                base = cp - 0x1D6DC + ord('A')
            elif 0x1D6F6 <= cp <= 0x1D70F:    # bold sans italic small
                base = cp - 0x1D6F6 + ord('a')
            elif 0x1D710 <= cp <= 0x1D729:    # sans bold italic caps
                base = cp - 0x1D710 + ord('A')
            elif 0x1D72A <= cp <= 0x1D743:    # sans bold italic small
                base = cp - 0x1D72A + ord('a')
            elif 0x1D744 <= cp <= 0x1D75D:    # sans bold italic caps (greek)
                base = cp - 0x1D744 + ord('A')
            elif 0x1D75E <= cp <= 0x1D777:
                base = cp - 0x1D75E + ord('a')
            elif 0x1D778 <= cp <= 0x1D791:
                base = cp - 0x1D778 + ord('A')
            elif 0x1D792 <= cp <= 0x1D7AB:
                base = cp - 0x1D792 + ord('a')
            elif 0x1D7CE <= cp <= 0x1D7E7:    # digits
                base = cp - 0x1D7CE + ord('0')
            elif 0x1D7EC <= cp <= 0x1D7F5:    # sans digits
                base = cp - 0x1D7EC + ord('0')
            elif 0x1D7F6 <= cp <= 0x1D7FF:
                base = cp - 0x1D7F6 + ord('0')
            out.append(chr(base) if base else '?')
        else:
            out.append(ch)
    return ''.join(out)


def clean_line(s: str) -> str:
    s = s.replace("\u00ad", "")
    s = re.sub(r"\s+", " ", s).strip()
    return s


def parse_mcqs(text: str) -> list[dict]:
    """Parse MCQ blocks from exam text."""
    text = normalize_math_unicode(text)
    lines = text.splitlines()
    questions: list[dict] = []
    cur = None  # {"num", "stem": [], "opts": {A: [...]}, "answer": None}
    seen = set()

    def flush():
        nonlocal cur
        if cur is None:
            return
        stem = clean_line(" ".join(cur["stem"]))
        opts = {k: clean_line(" ".join(v)) for k, v in cur["opts"].items() if v}
        ok_opts = {k: v for k, v in opts.items() if len(v) >= 1}
        if (
            len(stem) >= 8
            and len(ok_opts) >= 3
            and isinstance(cur["answer"], str)
            and cur["answer"] in "ABCD"
            and all(opts.get(c) for c in "ABC")
            and cur["num"] not in seen
            and "www." not in stem
        ):
            seen.add(cur["num"])
            questions.append({
                "num": cur["num"], "stem": stem, "options": opts,
                "answer": cur["answer"],
            })
        cur = None

    pending_answer = False
    pending_stem: list[str] = []
    for raw in lines:
        line = raw.rstrip()
        if not line.strip():
            continue
        stripped = line.strip()

        # bare "ANSWER:" -> letter on the next line
        if pending_answer:
            pending_answer = False
            lm = NEXT_LETTER_RE.match(stripped)
            if lm and cur:
                cur["answer"] = lm.group(1).upper()
                flush()
                continue
            # not a letter line -> fall through to normal handling

        am = ANS_RE.match(stripped) or ANS_INLINE_RE.search(stripped)
        qm = Q_RE.match(stripped)
        om = OPT_RE.match(stripped)

        if cur and am:
            # the answer marker might sit at the end of an option line
            # ("C. x D. y Answer: C") — harvest the options first
            if om:
                rest = stripped[: am.start()].strip()
                # split into option letter/text pairs
                pieces = re.split(r"(?<![\w])([A-Da-d])[\.\)]\s*", rest)
                if len(pieces) >= 3 and pieces[0] == "":
                    for i in range(1, len(pieces) - 1, 2):
                        cur["opts"][pieces[i].upper()].append(pieces[i + 1].strip())
            cur["answer"] = am.group(1).upper()
            flush()
            continue

        if cur and ANS_BARE_RE.match(stripped):
            pending_answer = True
            continue

        # unnumbered papers: "A." after accumulated stem text starts a new question
        if cur is None and om and om.group(1).upper() == "A" and pending_stem:
            stem_txt = " ".join(pending_stem)
            pending_stem = []
            cur = {"num": len(questions) + 1, "stem": [stem_txt],
                   "opts": {c: [] for c in "ABCD"}, "answer": None}

        if qm and (cur is not None or not questions or True):
            # question number boundary
            n = int(qm.group(1))
            if cur is not None:
                # only treat as new question if number progresses
                if n == (cur["num"] % 10000) + 1 or n == 1 or n > cur["num"]:
                    flush()
                else:
                    # continuation line starting with a number (math exprs)
                    if not om:
                        cur["stem"].append(stripped)
                        continue
            cur = {"num": n, "stem": [qm.group(2)], "opts": {c: [] for c in "ABCD"}, "answer": None}
            # stem line ending with an inline option marker: "... are A."
            sm = re.search(r"\s\(?(A)\s*[\.\)]\s*$", cur["stem"][0])
            if sm:
                cur["stem"][0] = cur["stem"][0][: sm.start()]
                cur["opts"]["A"].append("")
            continue

        if cur and om:
            letter = om.group(1).upper()
            rest = om.group(2)
            # 1) strip trailing "... Answer: X"
            ans_letter = None
            tail_m = ANS_TAIL_RE.match(rest.strip())
            if tail_m and tail_m.group(2).upper() in "ABCD":
                rest = tail_m.group(1)
                ans_letter = tail_m.group(2).upper()
            else:
                # bare "... Answer:" with letter on the NEXT line
                bare_m = re.search(r"\s*ans{1,2}wer\s*[:]?\s*$", rest, re.I)
                if bare_m:
                    rest = rest[: bare_m.start()]
                    pending_answer = True
            # 2) split multi-option lines "A. 6 B. 2"
            pieces = re.split(r"(?<![\w])([B-Db-d])[\.\)]\s+", rest)
            cur["opts"][letter].append(pieces[0].strip())
            for i in range(1, len(pieces) - 1, 2):
                cur["opts"][pieces[i].upper()].append(pieces[i + 1].strip())
            if ans_letter:
                cur["answer"] = ans_letter
                flush()
            continue

        if cur and cur["answer"] is None and not om:
            # stem/option continuation ending with "... Answer: C"
            tail_m = ANS_TAIL_RE.match(stripped)
            if tail_m and tail_m.group(2).upper() in "ABCD":
                if tail_m.group(1):
                    if any(cur["opts"][c] for c in "ABCD"):
                        for c in "DCBA":
                            if cur["opts"][c]:
                                cur["opts"][c].append(tail_m.group(1))
                                break
                    else:
                        cur["stem"].append(tail_m.group(1))
                cur["answer"] = tail_m.group(2).upper()
                flush()
                continue

        if cur is not None:
            # continuation: attach to last open field
            if any(cur["opts"][c] for c in "ABCD"):
                # append to last letter that has content
                for c in "DCBA":
                    if cur["opts"][c]:
                        cur["opts"][c].append(stripped)
                        break
            else:
                cur["stem"].append(stripped)
        else:
            # no open question: remember as stem candidate for unnumbered papers
            if len(stripped) >= 12 or pending_stem:
                pending_stem.append(stripped)

    flush()
    return questions


def dedup(questions: list[dict]) -> list[dict]:
    seen = set()
    out = []
    for q in questions:
        key = re.sub(r"\W+", "", q["stem"].lower())[:120]
        if key in seen:
            continue
        seen.add(key)
        out.append(q)
    return out


def main() -> None:
    if sys.argv[1] == "--all":
        # parse everything text/ocr available, report stats
        stats = []
        for txtf in sorted(PDF_DIR.glob("*.txt")) + sorted(PDF_DIR.glob("*.ocr.txt")):
            stem = txtf.stem
            if stem.endswith(".ocr"):
                continue  # handled via pdf stems
            if not (PDF_DIR / (stem + ".pdf")).exists():
                continue
            text, mode = load_text(stem)
            qs = dedup(parse_mcqs(text))
            if qs:
                stats.append({"stem": stem, "mode": mode, "mcqs": len(qs)})
        stats.sort(key=lambda s: -s["mcqs"])
        for s in stats:
            print(f"{s['mcqs']:>5}  {s['mode']:<7} {s['stem']}")
        print(f"\npapers with parseable MCQs: {len(stats)} | total MCQs: {sum(s['mcqs'] for s in stats)}")
        (SRC / "parse_survey.json").write_text(json.dumps(stats, indent=1))
        return

    lib_id = sys.argv[1]
    # find pdfs for this library
    stems = sorted(p.stem for p in PDF_DIR.glob(lib_id + "-*.pdf"))
    if not stems:
        print("no pdfs for", lib_id)
        sys.exit(1)
    all_qs = []
    for stem in stems:
        text, mode = load_text(stem)
        qs = dedup(parse_mcqs(text))
        print(f"{stem} [{mode}]: {len(qs)} mcqs")
        all_qs.extend(qs)
    all_qs = dedup(all_qs)
    print(f"TOTAL unique: {len(all_qs)}")
    for q in all_qs[:5]:
        print(json.dumps(q, indent=1)[:400])
    (SRC / f"parse_{lib_id}.json").write_text(json.dumps(all_qs, indent=1))


if __name__ == "__main__":
    main()
