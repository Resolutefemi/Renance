#!/usr/bin/env python3
"""find_zero_donors.py - which (sig,sec,pos) keys have ZERO landed lessons anywhere?
Those lessons cannot be donor-recovered and need hand authoring."""
import sqlite3, json, gzip, collections

R = "/home/z/my-project/content/tertiary/recover"
ldb = sqlite3.connect(f"{R}/corpus.sqlite")
ldb.row_factory = sqlite3.Row
landed = set(int(x) for x in open(f"{R}/landed_shards.txt"))
course_meta = json.load(open(f"{R}/course_meta.json"))
sig_map = json.load(open(f"{R}/sig_map.json"))
# reverse: sigh -> first section titles (for display)
sigh_display = {}
for h, titles in sig_map.items():
    sigh_display[int(h)] = titles

def fnv1a32(s):
    h = 0x811C9DC5
    for b in s.encode():
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h

needed = set()
with gzip.open(f"{R}/missing_units.jsonl.gz", "rt") as f:
    for line in f:
        m = json.loads(line)
        needed.add((m["sigh"], m["sec"], m["pos"]))

landed_by_key = collections.Counter()
for r in ldb.execute("select unit_id, course_id, sec, pos from units"):
    shard = fnv1a32(r["unit_id"]) % 60000
    if shard in landed:
        landed_by_key[(course_meta[r["course_id"]]["sigh"], r["sec"], r["pos"])] += 1

zero = sorted(k for k in needed if landed_by_key.get(k, 0) == 0)
print(f"zero-donor keys: {len(zero)}")
for k in zero:
    sigh, sec, pos = k
    print(f"\nsig {sigh} sec {sec} pos {pos}")
    print("  S2:", sigh_display[sigh][0][:70])
    print("  S15:", sigh_display[sigh][-1][:70])
    # which courses/units are missing at this key?
    for r in ldb.execute("select unit_id, course_id, title from units where sec=? and pos=?", (sec, pos)):
        if course_meta[r["course_id"]]["sigh"] == sigh:
            shard = fnv1a32(r["unit_id"]) % 60000
            st = "LANDED" if shard in landed else "MISSING"
            if st == "MISSING":
                print(f"    {r['unit_id']} | {course_meta[r['course_id']]['title'][:40]} | {r['title'][:60]}")
