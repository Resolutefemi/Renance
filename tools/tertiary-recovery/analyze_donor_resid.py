#!/usr/bin/env python3
"""analyze_donor_resid.py - local scan of ALL donor files:
find every non-whitelisted occurrence of the donor's own subject phrase,
cluster by field + (prev1, next1) context, and print patterns to design tier-2 rules.
"""
import json, gzip, glob, collections, re

R = "/home/z/my-project/content/tertiary/recover"
sig_ctx = json.load(open(f"{R}/sig_contexts.json"))
WHITE = set(tuple(k.split("|", 1)) for k, v in sig_ctx.items() if v >= 20)
subjects = json.load(open(f"{R}/course_subjects.json"))
import sqlite3
ldb = sqlite3.connect(f"{R}/corpus.sqlite")
ldb.row_factory = sqlite3.Row

def donor_subject(d, fn):
    if "subject" in d and d.get("subject"):
        return d["subject"]
    uid = d["uid"]
    r = ldb.execute("select course_id from units where unit_id=?", (uid,)).fetchone()
    return subjects.get(r["course_id"]) if r else None

def fields(blob):
    out = []
    for i, nt in enumerate(blob.get("notes") or []):
        out.append((f"note{i+1}-h", nt.get("heading", "") or ""))
        out.append((f"note{i+1}-b", nt.get("body", "") or ""))
    for i, kp in enumerate(blob.get("key_points") or []):
        out.append((f"kp{i+1}", kp))
    for i, q in enumerate(blob.get("quiz") or []):
        out.append((f"q{i+1}-stem", q.get("stem", "") or ""))
        out.append((f"q{i+1}-expl", q.get("explanation", "") or ""))
        for k, v in (q.get("options") or {}).items():
            if isinstance(v, str):
                out.append((f"q{i+1}-opt{k}", v))
    return out

pat = collections.Counter()   # (field_kind, prev1, next1) -> count
examples = collections.defaultdict(list)
donors_with_resid = 0
total_donors = 0
resid_by_subject = collections.Counter()

for fn in sorted(glob.glob(f"{R}/donors/*.json.gz")):
    if "hand_" in fn:
        continue
    try:
        d = json.load(gzip.open(fn))
    except Exception:
        continue
    total_donors += 1
    sd = donor_subject(d, fn)
    if not sd:
        continue
    sw = sd.lower().split()
    lw = len(sw)
    has = False
    for fld, text in fields(d["blob"]):
        words = text.split()
        low = [w.lower() for w in words]
        n = len(low)
        for i in range(0, n - lw + 1):
            if low[i:i + lw] == sw:
                p2 = " ".join(low[max(0, i - 2):i])
                p1 = low[i - 1] if i else "<START>"
                nx = low[i + lw] if (i + lw) < n else "<END>"
                if (p2, nx) not in WHITE:
                    has = True
                    kind = fld.split("-")[-1] if "-" in fld else fld
                    key = (kind, p1, nx)
                    pat[key] += 1
                    if len(examples[key]) < 2:
                        a = max(0, i - 7)
                        b = min(n, i + lw + 5)
                        examples[key].append((sd, " ".join(words[a:b])))
                    resid_by_subject[sd] += 1
    if has:
        donors_with_resid += 1

print(f"donors scanned: {total_donors} | with residual non-whitelisted occurrence: {donors_with_resid}")
print(f"\ndistinct residual patterns: {len(pat)}")
for (kind, p1, nx), c in sorted(pat.items(), key=lambda x: -x[1]):
    print(f"\n[{c}x] field-kind={kind} | prev1={p1!r} | next1={nx!r}")
    for sd, ctx in examples[(kind, p1, nx)]:
        print(f"      subj={sd[:35]!r} | ...{ctx}...")
