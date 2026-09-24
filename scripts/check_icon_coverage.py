#!/usr/bin/env python3
"""Verify every Material Symbols ligature the web app uses ships in the subset.

The subset font only renders the ligatures it was built with; anything
missing falls back to raw text ("auto_stories" spelled out), which bursts
out of its icon chip and looks off-center / broken. This audit scans the
tsx/ts sources for every ligature (literal children and `icon:` data
fields), reads the shipped woff2, and exits non-zero on any gap.

Usage:  python3 scripts/check_icon_coverage.py
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
WEB = REPO / "apps" / "web"
FONT = WEB / "public" / "fonts" / "material-symbols-outlined.subset.woff2"

# Tokens that match the ligature shape but are never icon names.
IGNORE = {
    "icon", "icons", "the", "and", "for", "with", "none", "fill_current",
}


def used_ligatures():
    """Every lowercase_snake token plausibly ligated in app/components."""
    used = set()
    for pattern in ("app/**/*.tsx", "app/**/*.ts", "components/**/*.tsx",
                    "components/**/*.ts", "lib/**/*.tsx", "lib/**/*.ts"):
        for p in WEB.glob(pattern):
            if "node_modules" in str(p) or "out" in p.parts:
                continue
            t = p.read_text(errors="ignore")
            # literal children: >name</span> after a material-symbols class
            for m in re.finditer(
                r"material-symbols-outlined[^>]*>\s*([a-z][a-z_]+)\s*<", t
            ):
                used.add(m.group(1))
            # dynamic data fields:  icon: 'auto_stories'
            for m in re.finditer(r"icon:\s*'([a-z][a-z_]+)'", t):
                used.add(m.group(1))
    return {u for u in used if u not in IGNORE and len(u) > 2}


def shipped_ligatures():
    from fontTools.ttLib import TTFont

    font = TTFont(FONT)
    names = set()
    gsub = font["GSUB"].table
    for lk in gsub.LookupList.Lookup:
        for st in lk.SubTable:
            t = st.ExtSubTable if lk.LookupType == 7 else st
            lt = t.LookupType if hasattr(t, "LookupType") else lk.LookupType
            if lt == 4 and getattr(t, "ligatures", None):
                for _first, ligs in t.ligatures.items():
                    for lig in ligs:
                        names.add(lig.LigGlyph)
    return names


def main():
    used = used_ligatures()
    shipped = shipped_ligatures()
    missing = sorted(used - shipped)
    print(f"icon audit: {len(used)} ligatures used, {len(shipped)} shipped")
    if missing:
        print("MISSING from the subset font (they render as raw text):")
        for m in missing:
            print("  ", m)
        print("\nFix: add real Material Symbols names to NEW_ICONS in")
        print("scripts/subset_material_symbols.py, download the upstream")
        print("variable TTF, re-run it, or correct the ligature name above.")
        return 1
    print("coverage ok")
    return 0


if __name__ == "__main__":
    sys.exit(main())
