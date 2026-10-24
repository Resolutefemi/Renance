#!/usr/bin/env python3
"""plan_recovery.py - analyze corpus + landed shards:
- distinct course titles (proxy for subject phrases)
- pack signatures from section titles (sections 2..15)
- missing units per course / (sig,sec,pos)
- donor feasibility: for each (sig,sec,pos), landed variant must exist
Writes recover/missing_units.jsonl.gz and recover/plan_stats.txt
"""
import sqlite3, gzip, json, collections, os

R = "/home/z/my-project/content/tertiary/recover"
ldb = sqlite3.connect(f"{R}/corpus.sqlite")
ldb.row_factory = sqlite3.Row

# subject-phrase rule: lowercase course title, '&' -> 'and', strip parentheses
def norm_subject(title):
    t = title.strip().lower()
    # strip parenthetical suffixes e.g. "(university)" — verify later
    import re
    t = re.sub(r"\s*\([^)]*\)\s*", " ", t)
    t = t.replace("&", "and").replace("  ", " ").strip()
    return t

courses = {r["course_id"]: dict(r) for r in ldb.execute("select * from courses")}
secs = collections.defaultdict(dict)
for r in ldb.execute("select course_id, sec, title from sections"):
    secs[r["course_id"]][r["sec"]] = r["title"]

sig_of = {}
sig_count = collections.Counter()
for cid, c in courses.items():
    sig = tuple(secs[cid].get(s, "") for s in range(2, 16))
    sig_of[cid] = sig
    sig_count[sig] += 1
print(f"distinct pack signatures (sections 2-15 titles): {len(sig_count)}")
for sig, n in sig_count.most_common(30):
    print(f"  {n:5d} courses | S2: {sig[0][:60]}")

# distinct normalized subjects
subs = {cid: norm_subject(c["title"]) for cid, c in courses.items()}
distinct_subj = collections.Counter(subs.values())
print(f"\ncourses: {len(courses)} | distinct subject phrases: {len(distinct_subj)}")
print("duplicates example:", distinct_subj.most_common(5))

# landed shards
landed = set(int(x) for x in open(f"{R}/landed_shards.txt"))
print(f"\nlanded shards: {len(landed)}")

def fnv1a32(s):
    h = 0x811C9DC5
    for b in s.encode():
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h

missing = []  # (unit_id, course_id, sec, pos, title, sig_hash, subject)
miss_by_course = collections.Counter()
miss_by_sig = collections.Counter()
unit_shard_cache = {}
for r in ldb.execute("select unit_id, course_id, sec, pos, title from units"):
    uid, cid, sec, pos, title = r
    shard = fnv1a32(uid) % 60000
    if shard in landed:
        continue
    sig = sig_of[cid]
    missing.append((uid, cid, sec, pos, title, hash(sig) & 0xFFFFFFFFFFFFFFFF, subs[cid]))
    miss_by_course[cid] += 1
    miss_by_sig[sig] += 1

print(f"\nMISSING units (shard not landed): {len(missing)}")
print(f"missing per course: min {min(miss_by_course.values())} max {max(miss_by_course.values())} mean {sum(miss_by_course.values())/len(miss_by_course):.1f}")
print(f"courses with 0 missing units: {sum(1 for c in courses if c not in miss_by_course)}")

# needed template keys: (sig_hash, sec, pos, subject)
needed = collections.Counter()
for uid, cid, sec, pos, title, sigh, subj in missing:
    needed[(sigh, sec, pos, subj)] += 1
print(f"needed (sig,sec,pos,subject) template keys: {len(needed)}")

# donor feasibility WITHOUT subject match: for each needed (sigh,sec,pos),
# how many LANDED units exist anywhere in that sig?
# landed units per (sigh, sec, pos):
landed_units_by_key = collections.Counter()
for r in ldb.execute("select unit_id, course_id, sec, pos from units"):
    uid, cid, sec, pos = r
    shard = fnv1a32(uid) % 60000
    if shard in landed:
        landed_units_by_key[(hash(sig_of[cid]) & 0xFFFFFFFFFFFFFFFF, sec, pos)] += 1
no_donor = 0
for (sigh, sec, pos, subj), n in needed.items():
    if landed_units_by_key.get((sigh, sec, pos), 0) == 0:
        no_donor += 1
print(f"needed keys whose (sig,sec,pos) has ZERO landed units anywhere: {no_donor}")

# needed keys with NO same-subject landed donor?
landed_units_by_key_subj = collections.Counter()
for r in ldb.execute("select unit_id, course_id, sec, pos from units"):
    uid, cid, sec, pos = r
    shard = fnv1a32(uid) % 60000
    if shard in landed:
        landed_units_by_key_subj[(hash(sig_of[cid]) & 0xFFFFFFFFFFFFFFFF, sec, pos, subs[cid])] += 1
no_exact = sum(1 for k in needed if landed_units_by_key_subj.get(k, 0) == 0)
print(f"needed keys with NO same-(sig,sec,pos,subject) landed donor: {no_exact} (need cross-subject phrase swap)")

with gzip.open(f"{R}/missing_units.jsonl.gz", "wt") as f:
    for m in missing:
        f.write(json.dumps({"uid": m[0], "cid": m[1], "sec": m[2], "pos": m[3],
                            "title": m[4], "sigh": m[5], "subj": m[6]}) + "\n")
print(f"\nwrote {R}/missing_units.jsonl.gz ({os.path.getsize(f'{R}/missing_units.jsonl.gz')/1e6:.1f} MB)")

# save sig map (sig_hash -> sig titles) for later
with open(f"{R}/sig_map.json", "w") as f:
    json.dump({str(hash(s) & 0xFFFFFFFFFFFFFFFF): list(s) for s in sig_count}, f)
# save course -> (sigh, subject)
with open(f"{R}/course_meta.json", "w") as f:
    json.dump({cid: [sig_of and 0 or 0] for cid in []}, f)  # placeholder, filled below
meta = {cid: {"sigh": hash(sig_of[cid]) & 0xFFFFFFFFFFFFFFFF, "subj": subs[cid], "title": courses[cid]["title"]} for cid in courses}
with open(f"{R}/course_meta.json", "w") as f:
    json.dump(meta, f)
print(f"wrote course_meta.json, sig_map.json")
