#!/usr/bin/env python3
"""
Content sweep — remove long hyphen runs ('--') from every student-visible
text field (founder directive 2026-09).

Two distinct cases live in the banks:
  1. PDF-scrape artifacts: '--- PAGE 2 ---' page-break markers that leaked
     into stems/explanations of the ingested course PDFs. Pure junk: cut.
  2. Exam blanks: '----' runs marking fill-in slots (English cloze,
     accounting tables). Hyphens render as a broken long dash; the exam
     convention is underscores, so every run becomes '_____'.

Single hyphens inside words (Al-Ahly, co-operate) are untouched, and
manifest shas/sizes are recomputed after the rewrite, then the library
is republished to apps/web/public/bundles/.

Usage:  python3 tools/cbt-build/sweep_hyphens.py
"""
from __future__ import annotations

import hashlib
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[2]
QDIR = REPO / "data" / "questions"
MANIFEST = REPO / "data" / "manifest.json"
WEB_PUBLIC_BUNDLES = REPO / "apps" / "web" / "public" / "bundles"

FIELDS = ("stem", "explanation", "passage")

PAGE_ARTIFACT = re.compile(r"\s*[-\u2010\u2011\u2012\u2013\u2014]{2,}\s*PAGE\s+\d+\s*[-\u2010\u2011\u2012\u2013\u2014]{0,}\s*", re.IGNORECASE)
HYPHEN_RUN = re.compile(r"[-\u2010]{2,}")
BLANK = "_____"


def clean(text: str) -> tuple[str, bool]:
    changed = False
    out = PAGE_ARTIFACT.sub(" ", text)
    if out != text:
        changed = True
    new = HYPHEN_RUN.sub(BLANK, out)
    if new != out:
        changed = True
    return new, changed


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    touched_files = 0
    touched_fields = 0

    for f in sorted(QDIR.rglob("*.json")):
        raw = f.read_text(encoding="utf-8")
        if "--" not in raw and "PAGE" not in raw:
            continue
        bundle = json.loads(raw)
        touched = False
        for q in bundle.get("questions", []):
            for field in FIELDS:
                v = q.get(field)
                if not v or "--" not in v:
                    continue
                nv, changed = clean(v)
                if changed:
                    q[field] = nv
                    touched = True
                    touched_fields += 1
            # option TEXT carries blanks too ("A) planula--hollow, ...")
            options = q.get("options")
            if isinstance(options, dict):
                for letter, text in options.items():
                    if isinstance(text, str) and "--" in text:
                        nv, changed = clean(text)
                        if changed:
                            options[letter] = nv
                            touched = True
                            touched_fields += 1
        if touched:
            f.write_text(json.dumps(bundle, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")
            touched_files += 1

    # code -> relative path (the founder's grouped layout), flat fallback
    index = {}
    idx_file = QDIR / "index.json"
    if idx_file.exists():
        index = json.loads(idx_file.read_text(encoding="utf-8"))

    def bundle_file(code: str) -> Path | None:
        rel = index.get(code)
        if rel:
            f = QDIR / rel
            if f.exists():
                return f
        f = QDIR / f"{code}.json"
        return f if f.exists() else None

    # refresh manifest fingerprints for every edited bundle
    for ex in manifest.get("exams", []):
        f = bundle_file(ex["code"])
        if f is not None:
            ex["bundleSha256"] = hashlib.sha256(f.read_bytes()).hexdigest()
            ex["sizeBytes"] = f.stat().st_size
    MANIFEST.write_text(json.dumps(manifest, ensure_ascii=False, indent=1) + "\n", encoding="utf-8")

    # republish the static library
    if WEB_PUBLIC_BUNDLES.exists():
        import shutil
        shutil.rmtree(WEB_PUBLIC_BUNDLES)
    WEB_PUBLIC_BUNDLES.mkdir(parents=True)
    for f in sorted(QDIR.rglob("*.json")):
        rel = f.relative_to(QDIR)
        dst = WEB_PUBLIC_BUNDLES / rel
        dst.parent.mkdir(parents=True, exist_ok=True)
        import shutil
        shutil.copy2(f, dst)
    shutil.copy2(MANIFEST, WEB_PUBLIC_BUNDLES / "manifest.json")

    print(f"cleaned {touched_fields} fields across {touched_files} bundles; manifest + static copy refreshed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
