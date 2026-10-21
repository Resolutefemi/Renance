#!/usr/bin/env python3
"""
Remove long dashes from Renance content (founder sweeps 2026-09 + 2026-10-02:
"remove any long hyphen from all Renance content").

Policy (unchanged since the first sweep):
  - UI copy / docs / comments (' — ' style): ' — ' -> ', ', stray em/en
    dashes -> '-'. Em/en dashes never appear in TS/Dart/Go syntax, so a
    raw text sweep is safe; comments get cleaned too.
  - Question banks (data/questions/*.json): em/en/minus dashes map to
    ASCII '-' because in stems they are fill-in-the-blank markers
    ("I find the —") or chemical bonds (H–CO2CH3), never prose commas.
  - School notes + schemes (data/school-notes, data/school-schemes):
    the same data policy - the corpus serves them verbatim to students.

Scope of this sweep (2026-10-02): question banks, school notes/schemes,
web UI + CSS, and every textual file repo-wide (docs, render.yaml,
.env.example, Dockerfile, migrations, scripts, tools, tests, mobile
README/pubspec/gradle comments). Binary assets, fonts, .git,
node_modules, legacy/ and this tool itself are never touched.

Refresh data/manifest.json afterwards (scripts/refresh_manifest.py) —
byte changes invalidate the sha256 fingerprints the API boots on. This
script runs it automatically when any question byte changed.
"""
from __future__ import annotations

import json
import subprocess
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]

EM = "\u2014"  # —
EN = "\u2013"  # –
MINUS = "\u2212"  # −
FIGURE = "\u2012"  # ‒
HORIZONTAL = "\u2015"  # ―
NBHYPHEN = "\u2011"  # ‑ non-breaking hyphen
SMALLHYPHEN = "\uFE63"  # ﹣ small hyphen-minus
FULLWIDTH = "\uFF0D"  # － fullwidth hyphen-minus


def clean_ui(text: str) -> str:
    text = text.replace(f" {EM} ", ", ").replace(f"{EM} ", ", ").replace(f" {EM}", ",")
    text = text.replace(EM, "-")
    text = text.replace(EN, "-").replace(MINUS, "-")
    text = text.replace(FIGURE, "-").replace(HORIZONTAL, "-")
    # every unicode hyphen variant renders as a dash: ASCII '-' everywhere
    text = text.replace(NBHYPHEN, "-").replace(SMALLHYPHEN, "-")
    text = text.replace(FULLWIDTH, "-").replace("\u2010", "-")
    return text


def clean_data(text: str) -> str:
    return clean_ui(text)  # identical mapping: any long dash -> ASCII '-'


# Textual file suffixes swept repo-wide, plus bare filenames like Dockerfile.
TEXT_SUFFIXES = {
    ".ts", ".tsx", ".js", ".mjs", ".mts", ".css", ".scss",
    ".dart", ".go", ".py", ".sh", ".sql", ".json",
    ".md", ".txt", ".html", ".htm", ".yaml", ".yml", ".kts", ".gradle",
    ".toml", ".cfg", ".env", ".gitignore", ".xml", ".svg",
}
TEXT_NAMES = {"Dockerfile", ".env.example", ".env.api.example", ".gitignore", "render.yaml"}

SKIP_DIRS = {
    ".git", "node_modules", ".next", "build", "dist", ".dart_tool",
    ".turbo", "legacy", "qimages", "fonts", "pdfs", "__pycache__",
}
SKIP_FILES = {
    # this tool + its sibling sweep must keep their policy characters
    Path("scripts/dash_cleanup.py"),
    Path("tools/cbt-build/sweep_hyphens.py"),
    # machine-generated fingerprints: refreshed separately
    Path("data/manifest.json"),
}
BINARY_SUFFIXES = {
    ".jpg", ".jpeg", ".png", ".webp", ".gif", ".ico", ".bmp",
    ".ttf", ".otf", ".woff", ".woff2", ".apk", ".aab", ".pdf", ".zip",
    ".keystore", ".jks", ".db", ".sqlite", ".so", ".dylib", ".bin",
}


def sweep_repo_text() -> int:
    """One pass over every textual file outside the data/ tree."""
    changed = 0
    for p in sorted(REPO.rglob("*")):
        if not p.is_file():
            continue
        rel = p.relative_to(REPO)
        if any(part in SKIP_DIRS for part in rel.parts):
            continue
        if rel in SKIP_FILES or rel.name in SKIP_FILES:
            continue
        if p.suffix.lower() in BINARY_SUFFIXES:
            continue
        # data/ JSONs are handled by the dedicated data sweep below
        if rel.parts and rel.parts[0] == "data":
            continue
        if p.suffix not in TEXT_SUFFIXES and rel.name not in TEXT_NAMES:
            continue
        try:
            raw = p.read_text(encoding="utf-8")
        except (UnicodeDecodeError, PermissionError):
            continue
        fixed = clean_ui(raw)
        if fixed != raw:
            if p.suffix == ".json":
                json.loads(fixed)  # never write JSON we cannot parse back
            p.write_text(fixed, encoding="utf-8")
            changed += 1
    return changed


def sweep_data() -> int:
    """Question banks + school notes + schemes (student-visible data)."""
    changed = 0
    for sub in ("questions", "school-notes", "school-schemes"):
        root = REPO / "data" / sub
        if not root.is_dir():
            continue
        for p in sorted(root.rglob("*.json")):
            raw = p.read_text(encoding="utf-8")
            fixed = clean_data(raw)
            if fixed != raw:
                json.loads(fixed)  # never write JSON we cannot parse back
                p.write_text(fixed, encoding="utf-8")
                changed += 1
    return changed


def main() -> int:
    data_changed = sweep_data()
    print(f"data files changed: {data_changed}")
    text_changed = sweep_repo_text()
    print(f"repo text files changed: {text_changed}")
    if data_changed:
        # sha256 fingerprints must follow the byte changes or the API
        # refuses to boot on the next deploy.
        r = subprocess.run(
            [sys.executable, str(REPO / "scripts" / "refresh_manifest.py")],
            check=False,
        )
        if r.returncode != 0:
            print("manifest refresh FAILED", file=sys.stderr)
            return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
