#!/usr/bin/env python3
"""Regenerate the Renance Material Symbols subset.

Keeps every icon ligature already inside the shipped subset and adds the
new icons used by the school portal + landing page. Output replaces
apps/web/public/fonts/material-symbols-outlined.subset.woff2.

Usage: python3 scripts/subset_material_symbols.py /tmp/msym.ttf
"""
import sys

from fontTools.ttLib import TTFont
from fontTools.subset import Subsetter, Options

REPO = "/home/z/my-project/renance"
OUT = f"{REPO}/apps/web/public/fonts/material-symbols-outlined.subset.woff2"
CURRENT = OUT  # read the old subset's inventory before replacing it

# New icons introduced by the school portal work (safe to re-run: icons
# already present are simply kept).
NEW_ICONS = [
    "co_present", "groups", "table_view",
    "account_balance", "school", "touch_app", "picture_as_pdf",
    # Arena duel mark: was missing from the shipped subset (rendered as
    # raw text and burst out of its chip).
    "swords",
    # Pacing forensics on the exam review sheet (PR #1 follow-up).
    "alarm_off", "avg_time",
]


def ligature_names(font):
    names = set()
    gsub = font["GSUB"].table
    for lk in gsub.LookupList.Lookup:
        for st in lk.SubTable:
            t = st
            if lk.LookupType == 7:
                t = st.ExtSubTable
            lt = t.LookupType if hasattr(t, "LookupType") else lk.LookupType
            if lt == 4 and getattr(t, "ligatures", None):
                for _first, ligs in t.ligatures.items():
                    for lig in ligs:
                        names.add(lig.LigGlyph)
    return names


def prune_ligatures(font, keep):
    gsub = font["GSUB"].table
    for lk in gsub.LookupList.Lookup:
        for st in lk.SubTable:
            t = st
            if lk.LookupType == 7:
                t = st.ExtSubTable
            lt = t.LookupType if hasattr(t, "LookupType") else lk.LookupType
            if lt == 4 and getattr(t, "ligatures", None):
                for first, ligs in list(t.ligatures.items()):
                    kept = [lig for lig in ligs if lig.LigGlyph in keep]
                    if kept:
                        t.ligatures[first] = kept
                    else:
                        del t.ligatures[first]


def main():
    src_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/msym.ttf"

    old = TTFont(CURRENT)
    have = ligature_names(old)
    print(f"existing subset icons: {len(have)}")

    want = set(have) | set(NEW_ICONS)

    src = TTFont(src_path)
    all_names = ligature_names(src)
    missing = want - all_names
    if missing:
        print("NOT FOUND upstream (left out):", sorted(missing))
        want -= missing
    print(f"target subset icons: {len(want)}")

    # Drop every ligature we do not want, then subset to the surviving
    # glyph closure (letters + ligature glyphs + their components).
    prune_ligatures(src, want)

    opts = Options()
    opts.layout_features = ["*"]
    opts.glyph_names = True  # keep real names: ligature identity depends on them
    opts.name_IDs = [1, 2, 3, 4, 6]
    opts.notdef_outline = True
    opts.recalc_bounds = False
    opts.drop_tables += ["DSIG"]
    # Feed the letters every ligature is built from so cmap keeps them.
    letters = set()
    for name in want:
        letters.update(name)
    text = "".join(sorted(letters))

    ss = Subsetter(options=opts)
    ss.populate(text=text)
    ss.subset(src)

    src.flavor = "woff2"
    src.save(OUT)
    print("saved", OUT)

    check = TTFont(OUT)
    got = ligature_names(check)
    still = want - got
    print(f"verify: {len(got)} ligatures, missing after subset: {sorted(still)[:8]}")


if __name__ == "__main__":
    main()
