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
import json
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parents[1]
WEB = REPO / "apps" / "web"
DATA = REPO / "data"
FONT = WEB / "public" / "fonts" / "material-symbols-outlined.subset.woff2"

ICON_VALUE = re.compile(r"^[a-z][a-z_]+$")
ICON_KEY = re.compile(r"icon", re.IGNORECASE)
# Const blocks whose name carries ICON (FIELD_ICONS, CAT_ICONS, ...):
# their quoted snake_case values are icon names even though the object
# keys are category words ("Tech: 'computer'").
ICON_MAP_BLOCK = re.compile(r"\b\w*ICON\w*\b[^={]*=\s*\{(.*?)\}", re.DOTALL)
QUOTED_SNAKE = re.compile(r"[\"']([a-z][a-z_]+)[\"']")

# Tokens that match the ligature shape but are never icon names.
IGNORE = {
    "icon", "icons", "the", "and", "for", "with", "none", "fill_current",
    # landing-duo.tsx types 'flame' as the ID of a hand-drawn SVG
    # (FlameDoodle/FlameGlyph) - it never rides the icon font, and
    # Material Symbols has no 'flame' ligature at all (the flame glyph
    # is 'local_fire_department', which the subset does carry).
    "flame",
}


def _walk_json(node, used):
    """Collect icon-name strings under any *icon* key, at any depth."""
    if isinstance(node, dict):
        for k, v in node.items():
            if ICON_KEY.search(str(k)) and isinstance(v, str) and ICON_VALUE.match(v):
                used.add(v)
            else:
                _walk_json(v, used)
    elif isinstance(node, list):
        for item in node:
            _walk_json(item, used)


def data_icons():
    """Icons referenced by the committed data/ JSON payloads.

    The school course catalogs (data/university/courses/*.json) drive the
    course cards' icons - 'computer', 'engineering', 'translate', ... were
    used on 40 school desks and missing from the subset, spelling
    "MPUTER" / "NEERING" raw over every card while the code-scan audit
    stayed green (it never looked at data files)."""
    used = set()
    if not DATA.is_dir():
        return used
    for p in DATA.glob("**/*.json"):
        try:
            parsed = json.loads(p.read_text(encoding="utf-8", errors="ignore"))
        except (json.JSONDecodeError, OSError):
            continue
        _walk_json(parsed, used)
    return used


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
            # QUOTED values only: JSX props (icon="assignment") and
            # double-quoted object fields (icon: "assignment").  The old
            # single-quote-only scan was exactly how the dashboard's
            # <LauncherTile icon="assignment"> leaked "IGNMENT" over the
            # Study grid while every audit stayed green - the University
            # Study tiles are the ONLY place that ligature appears.
            for m in re.finditer(r"\bicon\s*[:=]\s*[\"']([a-z][a-z_]+)[\"']", t):
                used.add(m.group(1))
            # Category-keyed icon maps (Record<string, string>): values
            # like FIELD_ICONS = { Tech: 'computer' } - the key is a
            # category word, so the icon: patterns above never saw them
            # and the career desk leaked "MPUTER" the same way.
            for block in ICON_MAP_BLOCK.finditer(t):
                for m in QUOTED_SNAKE.finditer(block.group(1)):
                    used.add(m.group(1))
    # Data-driven icons: the school catalogs' "icon" fields.
    used |= data_icons()
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
    print(f"sources: {len(used)} candidate ligatures "
          f"(code + *_ICONS maps + data/university JSONs)")
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
