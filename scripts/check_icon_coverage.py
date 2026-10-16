#!/usr/bin/env python3
"""Verify every Material Symbols ligature the web app actually SHAPES.

The audit shapes each icon name with HarfBuzz against the shipped
subset (decompressed to its TTF payload first - some HarfBuzz builds
read a woff2's cmap but never apply its GSUB, and browsers decompress
before shaping anyway). An icon that shapes to ONE glyph renders as the
icon; anything that stays N letter glyphs falls back to raw text
("auto_stories" spelled out), which bursts out of its icon chip.

History: the first audit compared ligature GLYPH NAMES, which the
Google-served subset renames to uniExxx - it reported every icon
missing while the font was fine. Shaping is the ground truth.

Usage:  python3 scripts/check_icon_coverage.py
"""
import io
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


def shaping_font() -> bytes:
    """The subset's TTF payload (what a browser shapes after decode)."""
    from fontTools.ttLib import TTFont

    raw = TTFont(FONT)
    raw.flavor = None
    out = io.BytesIO()
    raw.save(out)
    return out.getvalue()


def main():
    try:
        import uharfbuzz as hb
    except ImportError:
        print("uharfbuzz is required:  pip install uharfbuzz")
        return 2

    used = used_ligatures()
    data = shaping_font()
    face = hb.Face(data)
    font = hb.Font(face)

    def glyph_count(text: str) -> int:
        buf = hb.Buffer()
        buf.add_str(text)
        buf.guess_segment_properties()
        hb.shape(font, buf)
        return len(buf.glyph_infos)

    broken = sorted(n for n in used if glyph_count(n) != 1)
    print(f"icon audit: {len(used)} ligatures used, "
          f"{FONT.stat().st_size / 1024:.0f} KB subset")
    if broken:
        print("MISSING from the subset font (they render as raw text):")
        for m in broken:
            print("  ", m)
        print("\nFix: rebuild the subset - download the upstream variable")
        print("TTF and run scripts/rebuild_icon_subset.py /tmp/msym.ttf,")
        print("or correct the ligature name above.")
        return 1
    print("coverage ok - every used icon shapes to one glyph")
    return 0


if __name__ == "__main__":
    sys.exit(main())
