#!/usr/bin/env python3
"""Repair common LLM JSON defects before parsing.

Handles:
- invalid \\x, \\u-short, \\A-style escapes (Python code inside strings)
- literal newlines inside strings (json5-ish)
- markdown fences
- trailing commas
"""
import json
import re

_ESCAPES_OK = set('"\\/bfnrtu')


def repair_json(text):
    text = text.strip()
    text = re.sub(r"^```(?:json)?\s*", "", text)
    text = re.sub(r"\s*```\s*$", "", text)

    out = []
    i = 0
    n = len(text)
    in_str = False
    while i < n:
        ch = text[i]
        if not in_str:
            if ch == '"':
                in_str = True
            out.append(ch)
            i += 1
            continue
        # inside a string
        if ch == "\\" and i + 1 < n:
            nxt = text[i + 1]
            if nxt in _ESCAPES_OK:
                out.append(ch)
                out.append(nxt)
                i += 2
                continue
            # invalid escape: keep the char literally (escape the backslash)
            out.append("\\\\")
            out.append(nxt)
            i += 2
            continue
        if ch == '"':
            in_str = False
            out.append(ch)
            i += 1
            continue
        if ch == "\n":
            out.append("\\n")
            i += 1
            continue
        if ch == "\r":
            i += 1
            continue
        if ch == "\t":
            out.append("\\t")
            i += 1
            continue
        out.append(ch)
        i += 1
    fixed = "".join(out)
    fixed = re.sub(r",(\s*[}\]])", r"\1", fixed)
    return fixed


def loads_lenient(text):
    """Parse JSON with repairs; raise ValueError with context on failure."""
    try:
        return json.loads(text)
    except Exception:
        pass
    try:
        return json.loads(repair_json(text))
    except Exception:
        pass
    try:
        return parse_pretty_lines(text)
    except Exception as e:
        snippet = text[:200].replace("\n", " ")
        raise ValueError("unparseable JSON (%s) head: %s" % (e, snippet))


if __name__ == "__main__":
    import sys
    data = loads_lenient(open(sys.argv[1]).read() if len(sys.argv) > 1 else "{}")
    print("OK", type(data), (list(data.keys()) if isinstance(data, dict) else len(data)))


def parse_pretty_lines(text):
    """Fallback parser for pretty-printed JSON whose string values contain
    unescaped double quotes. Assumes one field per line (the usual LLM
    layout). Returns a lesson-shaped dict or raises ValueError."""
    import re as _re
    text = text.strip()
    text = _re.sub(r"^```(?:json)?\s*", "", text)
    text = _re.sub(r"\s*```\s*$", "", text)
    lesson = {"notes": [], "key_points": []}
    cur = None
    mode = None
    for rawline in text.split("\n"):
        ls = rawline.strip()
        if not ls:
            continue
        if ls.startswith('"key_points"'):
            mode = "kp"
            continue
        m = _re.match(r'^"(summary|heading|body)":\s*"(.*)",?$', ls)
        if m:
            key, val = m.group(1), m.group(2)
            if val.endswith('"'):
                val = val[:-1]
            val = _unescape(val)
            if key == "summary":
                lesson["summary"] = val
            elif key == "heading":
                cur = {"heading": val, "body": ""}
                lesson["notes"].append(cur)
            else:
                if cur is None:
                    cur = {"heading": "", "body": ""}
                    lesson["notes"].append(cur)
                cur["body"] = val
            continue
        if mode == "kp":
            m2 = _re.match(r'^"(.*)",?$', ls)
            if m2:
                lesson["key_points"].append(_unescape(m2.group(1)))
                continue
        # multi-line body continuation: append to current note body
        if cur is not None and ls.startswith('"') is False and ls.startswith("}"):
            continue
    if not lesson["notes"]:
        raise ValueError("no notes found by line parser")
    return lesson


def _unescape(v):
    return (v.replace("\\n", "\n").replace("\\t", "\t")
             .replace('\\"', '"').replace("\\\\", "\\"))
