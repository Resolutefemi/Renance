#!/usr/bin/env python3
"""
Remove long dashes from user-facing content.

The founder wants no long hyphens anywhere in the app or website copy:
  - UI source (apps/web app/components/lib): ' — ' -> ', ', stray em/en
    dashes -> '-'. Em/en dashes never appear in TS syntax, so a raw text
    sweep is safe; most hits are comments, which get cleaned too.
  - Question banks (data/questions/*.json): em/en/minus dashes map to
    ASCII '-' because in stems they are fill-in-the-blank markers
    ("I find the —") or chemical bonds (H–CO2CH3), never prose commas.

Refresh data/manifest.json afterwards (scripts/refresh_manifest.py) —
byte changes invalidate the sha256 fingerprints the API boots on.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
WEB = REPO / "apps" / "web"
WEB_DIRS = [WEB / "app", WEB / "components", WEB / "lib"]
QUESTIONS = REPO / "data" / "questions"

EM = "\u2014"  # —
EN = "\u2013"  # –
MINUS = "\u2212"  # −


def clean_ui(text: str) -> str:
    text = text.replace(f" {EM} ", ", ").replace(f"{EM} ", ", ").replace(f" {EM}", ",")
    text = text.replace(EM, "-")
    text = text.replace(EN, "-").replace(MINUS, "-")
    return text


def clean_data(text: str) -> str:
    return text.replace(EM, "-").replace(EN, "-").replace(MINUS, "-")


def main() -> int:
    ui_changed = 0
    for d in WEB_DIRS:
        for p in sorted(d.rglob("*")):
            if p.suffix not in {".ts", ".tsx"} or not p.is_file():
                continue
            raw = p.read_text(encoding="utf-8")
            fixed = clean_ui(raw)
            if fixed != raw:
                p.write_text(fixed, encoding="utf-8")
                ui_changed += 1
    print(f"ui files changed: {ui_changed}")

    q_changed = 0
    for p in sorted(QUESTIONS.rglob("*.json")):
        raw = p.read_text(encoding="utf-8")
        fixed = clean_data(raw)
        if fixed != raw:
            json.loads(fixed)  # never write JSON we cannot parse back
            p.write_text(fixed, encoding="utf-8")
            q_changed += 1
    print(f"question files changed: {q_changed}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
