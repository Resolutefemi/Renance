#!/usr/bin/env python3
"""Inspect a raw z-ai chat output file: strip fences, parse JSON, report compliance."""
import json
import re
import sys


def extract_content(path):
    d = json.load(open(path))
    if isinstance(d, dict) and "choices" in d:
        return d["choices"][0]["message"]["content"]
    if isinstance(d, dict) and "content" in d:
        return d["content"]
    return d


def strip_fences(c):
    c = c.strip()
    c = re.sub(r"^```(?:json)?\s*", "", c)
    c = re.sub(r"\s*```\s*$", "", c)
    return c.strip()


def main():
    path = sys.argv[1]
    show = int(sys.argv[2]) if len(sys.argv) > 2 else -1
    c = strip_fences(extract_content(path))
    try:
        body = json.loads(c)
    except Exception as e:
        print("PARSE FAIL:", e)
        print(c[:800])
        sys.exit(1)
    notes = body.get("notes", [])
    print("notes:", len(notes), "| key_points:", len(body.get("key_points", [])))
    total = 0
    for i, n in enumerate(notes):
        w = len(n["body"].split())
        total += w
        flag = "SHORT" if w < 250 else ("LONG" if w > 400 else "ok")
        print("%2d | %4d words | %-8s | %s" % (i + 1, w, flag, n["heading"]))
    print("total words:", total)
    joined = " ".join(n["body"] for n in notes)
    print("has --:", "--" in c, "| non-ascii:", any(ord(ch) > 127 for ch in c))
    print("{S} count:", c.count("{S}"), "| {t} count:", c.count("{t}"))
    banned = ["exam", "mark", "revision", "pass", "WAEC", "JAMB", "study"]
    hits = [b for b in banned if b.lower() in joined.lower()]
    print("banned-word hits:", hits)
    if show >= 0 and show < len(notes):
        print("\nNOTE %d FULL:\n%s" % (show + 1, notes[show]["body"]))
    print("\nkey_points:", json.dumps(body.get("key_points", []), indent=1)[:600])


if __name__ == "__main__":
    main()
