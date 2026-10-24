#!/usr/bin/env python3
"""test_diff_hypothesis.py - fetch two landed lessons with the same (sig, sec, pos)
but different course subjects; diff notes/quiz word-by-word to prove that the only
differences are the injected subject spans.
"""
import sqlite3, json, gzip, boto3, difflib, collections, sys
from botocore.config import Config

R = "/home/z/my-project/content/tertiary/recover"
ACC = "ff1e18e32afe87e8e07b3c35595fdd0e"
KID = "78b8e71ffccaf0bdf12b95a6b108000f"
SEC_ = "38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2"

s3 = boto3.client("s3", endpoint_url=f"https://{ACC}.r2.cloudflarestorage.com",
                  aws_access_key_id=KID, aws_secret_access_key=SEC_,
                  config=Config(connect_timeout=15, read_timeout=60), region_name="auto")

def fnv1a32(s):
    h = 0x811C9DC5
    for b in s.encode():
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h

ldb = sqlite3.connect(f"{R}/corpus.sqlite")
ldb.row_factory = sqlite3.Row
landed = set(int(x) for x in open(f"{R}/landed_shards.txt"))

# choose the big chem_phys sig at sec=2 pos=1... actually pick ANY sig with >=50 courses;
# then two courses whose EU(sec,pos) unit landed, with different titles.
target_sec, target_pos = 2, 1

cands = []  # (unit_id, course_id, course_title, shard)
for r in ldb.execute("""select u.unit_id, u.course_id, u.sec, u.pos, c.title
                         from units u join courses c on c.course_id=u.course_id
                         where u.sec=? and u.pos=?""", (target_sec, target_pos)):
    uid, cid, sec, pos, title = r["unit_id"], r["course_id"], r["sec"], r["pos"], r["title"]
    shard = fnv1a32(uid) % 60000
    if shard in landed:
        cands.append((uid, cid, title, shard))

print(f"landed candidates at (sec 2, pos 1): {len(cands)}")
# group by sig to ensure same pack
import collections
sig_of = {}
course_meta = json.load(open(f"{R}/course_meta.json"))
by_sig = collections.defaultdict(list)
for uid, cid, title, shard in cands:
    by_sig[course_meta[cid]["sigh"]].append((uid, cid, title, shard))
best_sig = max(by_sig, key=lambda s: len(by_sig[s]))
group = by_sig[best_sig]
print(f"biggest sig group: {len(group)} landed donors")

# pick two with clearly different titles
d1 = group[0]
d2 = None
for g in group:
    if course_meta[g[1]]["subj"] != course_meta[d1[1]]["subj"]:
        d2 = g
        break
print("donor A:", d1[1], d1[2], "->", d1[0], "shard", d1[3])
print("donor B:", d2[1], d2[2], "->", d2[0], "shard", d2[3])

def fetch(unit_id):
    shard = fnv1a32(unit_id) % 60000
    obj = s3.get_object(Bucket="renance", Key=f"packs/p-{shard:05d}.json")
    data = json.loads(obj["Body"].read())
    return data["lessons"][unit_id]

A = fetch(d1[0])
B = fetch(d2[0])
print("\nA title:", A["title"])
print("B title:", B["title"])
print("titles equal:", A["title"] == B["title"])
print("A summary:", A["summary"][:150])
print("B summary:", B["summary"][:150])
print("notes count:", len(A["notes"]), len(B["notes"]))

# word-level diff of note bodies
def words(t):
    return t.split()

total_diff_spans = 0
for i in (0, 1, 2, 9):
    a = words(A["notes"][i]["body"])
    b = words(B["notes"][i]["body"])
    sm = difflib.SequenceMatcher(None, a, b)
    diffs = [op for op in sm.get_opcodes() if op[0] != "equal"]
    total_diff_spans += len(diffs)
    print(f"\nnote {i+1} heading A: {A['notes'][i]['heading'][:90]}")
    print(f"note {i+1} heading B: {B['notes'][i]['heading'][:90]}")
    print(f"note {i+1}: {len(diffs)} diff spans")
    for tag, i1, i2, j1, j2 in diffs[:6]:
        print(f"   A: {' '.join(a[max(0,i1-3):i2+3])!r}")
        print(f"   B: {' '.join(b[max(0,j1-3):j2+3])!r}")

# quiz stems comparison: same stem set modulo subject?
sa = [q["stem"] for q in A["quiz"]]
sb = [q["stem"] for q in B["quiz"]]
print("\nquiz count:", len(sa), len(sb))
same_order = sum(1 for x, y in zip(sa, sb) if x == y)
print("identical stems (same order):", same_order, "/", len(sa))
# order-insensitive multiset equality after removing subject phrases
sA = course_meta[d1[1]]["subj"]; sB = course_meta[d2[1]]["subj"]
def strip(t, subj):
    out = t.lower().replace(subj, "«S»")
    return out
mA = sorted(strip(x, sA) for x in sa)
mB = sorted(strip(x, sB) for x in sb)
print("quiz stem multisets equal after subject strip:", mA == mB)
qa_same = sum(1 for q in A["quiz"] for k in ("answer","explanation") if True)
print("answers equal in order:", [q["answer"] for q in A["quiz"]] == [q["answer"] for q in B["quiz"]])
print("quiz ids A:", [q["id"] for q in A["quiz"]][:3])
print("quiz types A:", collections.Counter(q["type"] for q in A["quiz"]))
print("key_points A[0..1]:", A["key_points"][:2])
