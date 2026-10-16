#!/usr/bin/env python3
"""Rebuild apps/web/public/fonts/material-symbols-outlined.subset.woff2 -
string-based, so it works no matter how the sources name their glyphs.

WHY (founder bug 2026-10-16, CI icon-coverage failure): the shipped
subset came from the Google Fonts icon_names API, which renames ligature
glyphs to uniExxx - the old name-based tooling cannot see the icons it
ships, and the served woff2 also failed a HarfBuzz shaping probe (the
GSUB survives inside the TTF payload but never fired on the woff2). This
builder starts from the UPSTREAM variable font, prunes it to exactly the
icon names Renance uses, subsets, re-encodes with fontTools (a woff2
every shaping engine reads), and PROVES the result by shaping every used
ligature with HarfBuzz.

Usage: python3 scripts/rebuild_icon_subset.py [/tmp/msym.ttf]
  (the upstream Material Symbols Outlined variable TTF)
"""
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
WEB = REPO / "apps" / "web"
FONT = WEB / "public" / "fonts" / "material-symbols-outlined.subset.woff2"

# Tokens that match the ligature shape but are never icon names.
IGNORE = {"icon", "icons", "the", "and", "for", "with", "none", "fill_current"}

# Icons reachable only through computed returns (milestone cards, the
# arena opponent chip) - carried over from the earlier builders.
EXTRA_ICONS = {
    "local_fire_department", "school", "military_tech", "trophy",
    "smart_toy", "person", "touch_app", "check_circle",
}

from fontTools.ttLib import TTFont
from fontTools.subset import Subsetter, Options


def used_ligatures():
    """Every lowercase_snake token plausibly ligated in app/components."""
    used = set()
    for pattern in ("app/**/*.tsx", "app/**/*.ts", "components/**/*.tsx",
                    "components/**/*.ts", "lib/**/*.tsx", "lib/**/*.ts"):
        for p in WEB.glob(pattern):
            if "node_modules" in str(p) or "out" in p.parts:
                continue
            t = p.read_text(errors="ignore")
            for m in re.finditer(
                r"material-symbols-outlined[^>]*>\s*([a-z][a-z_]+)\s*<", t
            ):
                used.add(m.group(1))
            for m in re.finditer(r"icon:\s*'([a-z][a-z_]+)'", t):
                used.add(m.group(1))
    return {u for u in used if u not in IGNORE and len(u) > 2}


def current_font_strings():
    """The icon-name STRINGS the currently shipped subset can ligate,
    reconstructed from its ligature components (its glyph names are
    Google's uniExxx, so the components are the only truth left)."""
    cmap = FONT_TT.getBestCmap()
    rev = {}
    for cp, g in cmap.items():
        rev.setdefault(g, chr(cp))
    gsub = FONT_TT["GSUB"].table
    strings = set()
    for lk in gsub.LookupList.Lookup:
        for st in lk.SubTable:
            t = st.ExtSubTable if lk.LookupType == 7 else st
            lt = t.LookupType if hasattr(t, "LookupType") else lk.LookupType
            if lt == 4 and getattr(t, "ligatures", None):
                for first, entries in t.ligatures.items():
                    f0 = rev.get(first, first)
                    for lig in entries:
                        s = f0 + "".join(rev.get(c, "\x00") for c in lig.Component)
                        if "\x00" not in s:
                            strings.add(s)
    return strings


def upstream_names(font):
    """Upstream ligature glyph names ARE the icon names."""
    gsub = font["GSUB"].table
    names = set()
    for lk in gsub.LookupList.Lookup:
        for st in lk.SubTable:
            t = st.ExtSubTable if lk.LookupType == 7 else st
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


def shape_width(data, text):
    """HarfBuzz shape -> glyph count (1 means the ligature fired).

    The probe runs on the DECOMPRESSED TTF: HarfBuzz builds exist that
    read a woff2's cmap but never apply its GSUB (this sandbox shipped
    one, which is how the shipped Google woff2 got audited as broken).
    Browsers decompress woff2 before shaping, so the TTF payload is the
    ground truth the audit must judge."""
    import io

    import uharfbuzz as hb

    raw = TTFont(io.BytesIO(data))
    raw.flavor = None
    buf_out = io.BytesIO()
    raw.save(buf_out)
    face = hb.Face(buf_out.getvalue())
    font = hb.Font(face)
    buf = hb.Buffer()
    buf.add_str(text)
    buf.guess_segment_properties()
    hb.shape(font, buf)
    return len(buf.glyph_infos)


def main():
    src_path = sys.argv[1] if len(sys.argv) > 1 else "/tmp/msym.ttf"

    global FONT_TT
    FONT_TT = TTFont(FONT)
    have = current_font_strings()
    used = used_ligatures()
    try:
        sys.path.insert(0, str(REPO / "scripts"))
        from subset_material_symbols import NEW_ICONS
    except Exception:
        NEW_ICONS = []
    want = have | used | set(NEW_ICONS) | EXTRA_ICONS
    print(f"current subset strings: {len(have)}, used in code: {len(used)}, "
          f"NEW_ICONS: {len(NEW_ICONS)}, want: {len(want)}")

    src = TTFont(src_path)
    all_names = upstream_names(src)
    missing = want - all_names
    if missing:
        print("NOT FOUND upstream (left out):", sorted(missing))
        want -= missing
    print(f"target subset icons: {len(want)}")

    prune_ligatures(src, want)

    opts = Options()
    opts.layout_features = ["*"]
    opts.glyph_names = True  # keep real names: ligature identity depends on them
    opts.name_IDs = [1, 2, 3, 4, 6]
    opts.notdef_outline = True
    opts.recalc_bounds = False
    opts.drop_tables += ["DSIG"]
    letters = set()
    for name in want:
        letters.update(name)
    ss = Subsetter(options=opts)
    ss.populate(text="".join(sorted(letters)))
    ss.subset(src)

    src.flavor = "woff2"
    src.save(FONT)
    print(f"saved {FONT} ({FONT.stat().st_size / 1024:.1f} KB)")

    # ---------------------------------------------------------------- verify --
    data = FONT.read_bytes()
    check = TTFont(FONT)
    got = upstream_names(check)
    still = want - got
    if still:
        print("FAIL: lost ligatures after subset:", sorted(still)[:12])
        return 1
    axes = [a.axisTag for a in check["fvar"].axes] if "fvar" in check else []
    if "FILL" not in axes:
        print("FAIL: the FILL variable axis did not survive")
        return 1
    bad = [n for n in sorted(used) if shape_width(data, n) != 1]
    if bad:
        print("FAIL: these icons do NOT shape to one glyph:", bad)
        return 1
    print(f"OK: {len(got)} ligatures, axes {axes}, every used icon shapes to 1 glyph")
    json.dump(sorted(used), open(REPO / "scripts" / "icon_names.json", "w"), indent=1)
    return 0


if __name__ == "__main__":
    sys.exit(main())
