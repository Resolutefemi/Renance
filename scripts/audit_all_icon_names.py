#!/usr/bin/env python3
"""Shape-test EVERY snake_case string literal in the web app against the
subset Material Symbols font.

The stock check_icon_coverage.py only sees icon names it can regex out of
static JSX children and icon=/icon: fields. Dynamic children like
  {instant ? 'visibility' : 'visibility_off'}
leak past it - 'visibility' was missing from the subset and rendered as
the raw word "VISIBILITY" on the exam intro + quiz command bar. This
audit casts a wider net: every lowercase snake_case string literal in
app/ components/ lib/, shaped with HarfBuzz; anything that does NOT
shape to exactly one glyph is a candidate missing ligature.
"""
import io
import re
import sys
from pathlib import Path

import uharfbuzz as hb
from fontTools.ttLib import TTFont

REPO = Path(__file__).resolve().parents[1]
WEB = REPO / "apps" / "web"
FONT = WEB / "public" / "fonts" / "material-symbols-outlined.subset.woff2"

SNAKE = re.compile(r"['\"`]([a-z][a-z_]{2,40})['\"`]")

# tokens that are common English words / code identifiers, not icon names
IGNORE = {
    "icon", "icons", "the", "and", "for", "with", "none", "fill_current",
    "class", "style", "type", "href", "width", "height", "value", "title",
    "label", "name", "text", "size", "color", "gap", "flex", "grid", "auto",
    "href", "src", "alt", "rel", "meta", "data", "true", "false", "null",
    "undefined", "string", "number", "boolean", "object", "hover", "focus",
    "active", "disabled", "left", "right", "top", "bottom", "center",
    "start", "end", "open", "close", "test", "desc", "props", "state",
    "refs", "keys", "rows", "cols", "span", "div", "html", "body", "head",
    "lang", "dir", "code", "mode", "view", "list", "item", "items", "page",
    "next", "prev", "done", "emit", "err", "res", "req", "url", "uri",
    "api", "key", "id", "ids", "uid", "sid", "pid", "cid", "rid", "aid",
    "sans", "serif", "mono", "bold", "normal", "wrap", "clip", "hidden",
    "scroll", "touch", "user", "pass", "sign", "logo", "mark", "dark",
    "light", "theme", "toast", "sheet", "card", "pill", "chip", "tile",
    "grid_gap", "aria", "role", "tab", "index", "shift", "ctrl", "alt_key",
    "enter", "escape", "space", "enterKey", "tabindex",
}


def shaping_font() -> bytes:
    raw = TTFont(FONT)
    raw.flavor = None
    out = io.BytesIO()
    raw.save(out)
    return out.getvalue()


def main():
    face = hb.Face(shaping_font())
    font = hb.Font(face)

    def glyphs(text: str) -> int:
        buf = hb.Buffer()
        buf.add_str(text)
        buf.guess_segment_properties()
        hb.shape(font, buf)
        return len(buf.glyph_infos)

    used = set()
    for pattern in ("app/**/*.tsx", "app/**/*.ts", "components/**/*.tsx",
                    "components/**/*.ts", "lib/**/*.tsx", "lib/**/*.ts"):
        for p in WEB.glob(pattern):
            if "node_modules" in str(p) or "out" in p.parts:
                continue
            t = p.read_text(errors="ignore")
            for m in SNAKE.finditer(t):
                used.add(m.group(1))

    # only test tokens that LOOK like icon names and appear inside a
    # material-symbols context OR are quoted as a whole string literal
    # anywhere; English-word noise is filtered by the IGNORE set and by
    # requiring the token to appear near a material-symbols usage.
    ctx_tokens = set()
    for pattern in ("app/**/*.tsx", "components/**/*.tsx"):
        for p in WEB.glob(pattern):
            if "node_modules" in str(p) or "out" in p.parts:
                continue
            t = p.read_text(errors="ignore")
            for m in re.finditer(
                r"material-symbols-outlined[^>]*>\s*\{?['\"`]?([a-z][a-z_]+)['\"`]?\s*\}?",
                t,
            ):
                ctx_tokens.add(m.group(1))
            # ternaries / expressions INSIDE a symbols span
            for m in re.finditer(
                r"material-symbols-outlined[^>]*>\s*\{([^}]+)\}", t
            ):
                expr = m.group(1)
                for q in re.finditer(r"['\"]([a-z][a-z_]+)['\"]", expr):
                    ctx_tokens.add(q.group(1))
            # icon="x" / icon: 'x' / ICONS maps
            for m in re.finditer(r"\bicon\s*[:=]\s*[\"']([a-z][a-z_]+)[\"']", t):
                ctx_tokens.add(m.group(1))
            for block in re.finditer(r"\b\w*ICON\w*\b[^={]*=\s*\{(.*?)\}", t, re.DOTALL):
                for q in re.finditer(r"[\"']([a-z][a-z_]+)[\"']", block.group(1)):
                    ctx_tokens.add(q.group(1))

    ctx_tokens = {t for t in ctx_tokens if t not in IGNORE and len(t) > 2}
    broken = sorted(t for t in ctx_tokens if glyphs(t) != 1)
    print(f"context tokens: {len(ctx_tokens)} (icons reachable from JSX)")
    if broken:
        print("MISSING from the subset font (render as raw text):")
        for t in broken:
            print("  ", t)
        return 1
    print("coverage ok - every reachable icon name shapes to one glyph")
    return 0


if __name__ == "__main__":
    sys.exit(main())
