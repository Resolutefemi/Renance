#!/usr/bin/env python3
"""Char-coordinate PDF text reconstruction for badly-generated PDFs.

Some abstechconnect PDFs (TEAM ASSET style) report bogus per-char widths
(every glyph claims a 10pt box) and scrambled line order in pdftotext.
This module rebuilds text from raw char x0/x1 coordinates:

  1. cluster chars into visual lines by 'top' (+-2.5pt buckets)
  2. sort each line's chars by x0
  3. drop duplicated glyph runs (same x0, same char)
  4. insert a space whenever x0-diff exceeds the glyph's expected advance
     (Times/Helvetica metric tables) by > gap_tol
"""
import math

# Times-Roman advances (per 1000 units)
TR = {
    ' ': 250, '!': 333, '"': 408, '#': 500, '$': 500, '%': 833, '&': 778,
    "'": 180, '(': 333, ')': 333, '*': 500, '+': 564, ',': 250, '-': 333,
    '.': 250, '/': 278, '0': 500, '1': 500, '2': 500, '3': 500, '4': 500,
    '5': 500, '6': 500, '7': 500, '8': 500, '9': 500, ':': 278, ';': 278,
    '<': 564, '=': 564, '>': 564, '?': 444, '@': 921, 'A': 722, 'B': 667,
    'C': 667, 'D': 722, 'E': 611, 'F': 556, 'G': 722, 'H': 722, 'I': 333,
    'J': 389, 'K': 722, 'L': 611, 'M': 889, 'N': 722, 'O': 722, 'P': 556,
    'Q': 722, 'R': 667, 'S': 556, 'T': 611, 'U': 722, 'V': 722, 'W': 944,
    'X': 722, 'Y': 722, 'Z': 611, '[': 333, '\\': 278, ']': 333, '^': 469,
    '_': 500, '`': 333, 'a': 444, 'b': 500, 'c': 444, 'd': 500, 'e': 444,
    'f': 333, 'g': 500, 'h': 500, 'i': 278, 'j': 278, 'k': 500, 'l': 278,
    'm': 778, 'n': 500, 'o': 500, 'p': 500, 'q': 500, 'r': 333, 's': 389,
    't': 278, 'u': 500, 'v': 500, 'w': 722, 'x': 500, 'y': 500, 'z': 444,
    '{': 480, '|': 200, '}': 480, '~': 541,
}
DEFAULT_W = 500


def adv(ch: str, size: float) -> float:
    return TR.get(ch, DEFAULT_W) * size / 1000.0


def reconstruct(page, gap_tol: float = 1.6, line_tol: float = 3.0) -> str:
    """page: a pdfplumber Page. Returns reconstructed text."""
    chars = [c for c in page.chars if c.get("text") and not c["text"].isspace()]
    if not chars:
        return ""
    # bucket lines by top with tolerance, then merge buckets that overlap
    chars = sorted(chars, key=lambda c: (round(c["top"], 1), c["x0"]))
    lines = []  # list of [top, [chars]]
    for c in chars:
        if lines and abs(lines[-1][0] - c["top"]) <= line_tol:
            lines[-1][1].append(c)
        else:
            lines.append([c["top"], [c]])
    out_lines = []
    for _top, cs in lines:
        cs.sort(key=lambda c: c["x0"])
        # dedupe duplicated glyphs at the same position
        dedup = []
        for c in cs:
            if dedup and abs(c["x0"] - dedup[-1]["x0"]) < 0.4 and c["text"] == dedup[-1]["text"]:
                continue
            if dedup and c["x0"] < dedup[-1]["x0"] - 0.2:
                # fully overlapping run - keep the one already placed
                continue
            dedup.append(c)
        parts = []
        prev = None
        for c in dedup:
            if prev is not None:
                diff = c["x0"] - prev["x0"]
                expect = adv(prev["text"], max(prev.get("size", 10), 1))
                if diff - expect > gap_tol or diff > expect * 2.0:
                    parts.append(" ")
            parts.append(c["text"])
            prev = c
        line = "".join(parts).strip()
        if line:
            out_lines.append(line)
    return "\n".join(out_lines)


def extract_pdf(path: str, max_pages: int = 400) -> str:
    import pdfplumber
    chunks = []
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages[:max_pages]:
            chunks.append(reconstruct(page))
    return "\n".join(chunks)


if __name__ == "__main__":
    import sys
    t = extract_pdf(sys.argv[1])
    print(t[:2000])
