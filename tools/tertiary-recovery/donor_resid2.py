#!/usr/bin/env python3
"""donor_resid2.py - enumerate ALL residual (non-tier1) donor subject occurrences
using normalized-token matching + the sig_ctx2 whitelist. Also applies the candidate
tier2 rule (3<=count<20 AND nsubj>=2) and prints final candidates for hand review.
Output: resid2.json (full list), and a compact pattern report.
"""
import json, gzip, glob, collections, re, sqlite3

R = "/home/z/my-project/content/tertiary/recover"
STRIP = re.compile(r"^[^\w]+|[^\w]+$")
def norm(w):
    return STRIP.sub("", w)

sig2 = json.load(open(f"{R}/sig_ctx2.json"))
T1 = set()
for k, (c, ss) in sig2.items():
    if c >= 20:
        p, n = k.split("|", 1)
        T1.add((p, n))
print(f"tier1 whitelist: {len(T1)}")

subjects = json.load(open(f"{R}/course_subjects2.json"))
ldb = sqlite3.connect(f"{R}/corpus.sqlite")
ldb.row_factory = sqlite3.Row

def donor_subject(d):
    if d.get("subject"):
        return d["subject"]
    r = ldb.execute("select course_id from units where unit_id=?", (d["uid"],)).fetchone()
    return subjects.get(r["course_id"]) if r else None

def fields(blob):
    out = []
    for i, nt in enumerate(blob.get("notes") or []):
        out.append((f"note{i+1}-h", nt.get("heading", "") or ""))
        out.append((f"note{i+1}-b", nt.get("body", "") or ""))
    for i, kp in enumerate(blob.get("key_points") or []):
        out.append((f"kp{i+1}", kp or ""))
    for i, q in enumerate(blob.get("quiz") or []):
        out.append((f"q{i+1}-stem", q.get("stem", "") or ""))
        out.append((f"q{i+1}-expl", q.get("explanation", "") or ""))
        for k, v in (q.get("options") or {}).items():
            if isinstance(v, str):
                out.append((f"q{i+1}-opt{k}", v))
    return out

sig_meta = {}
for k, (c, ss) in sig2.items():
    p, n = k.split("|", 1)
    sig_meta[(p, n)] = (c, len(ss))

pat = collections.defaultdict(lambda: [0, set()])  # (kind, p1, nx, p2) -> count, subjects
examples = {}
total_donors = 0
donors_hit = 0
res = []
for fn in sorted(glob.glob(f"{R}/donors/*.json.gz")):
    if "hand_" in fn:
        continue
    try:
        d = json.load(gzip.open(fn))
    except Exception:
        continue
    total_donors += 1
    sd = donor_subject(d)
    if not sd:
        continue
    sjw = [norm(w).lower() for w in sd.split()]
    lw = len(sjw)
    hit = False
    for fld, text in fields(d["blob"]):
        words = text.split()
        nn = [norm(w).lower() for w in words]
        n = len(words)
        for i in range(0, n - lw + 1):
            if nn[i:i + lw] == sjw:
                p2 = " ".join(nn[max(0, i - 2):i])
                p1 = nn[i - 1] if i else "<START>"
                nx = nn[i + lw] if (i + lw) < n else "<END>"
                if (p2, nx) in T1:
                    continue
                hit = True
                c, ns = sig_meta.get((p2, nx), (0, 0))
                kind = fld.split("-")[-1] if "-" in fld else fld
                pk = (kind, p1, nx, p2)
                pat[pk][0] += 1
                pat[pk][1].add(sd)
                if pk not in examples:
                    a = max(0, i - 8)
                    b = min(n, i + lw + 6)
                    examples[pk] = (sd, fld, " ".join(words[a:b]))
    if hit:
        donors_hit += 1

print(f"donors: {total_donors} | with residual: {donors_hit} | distinct patterns: {len(pat)}")
out = []
for pk, (c, subs) in sorted(pat.items(), key=lambda x: -x[1][0]):
    kind, p1, nx, p2 = pk
    sigc, nsubj = sig_meta.get((p2, nx), (0, 0))
    sd, fld, ctx = examples[pk]
    tier2_auto = (3 <= sigc < 20 and nsubj >= 2)
    out.append({"kind": kind, "p1": p1, "nx": nx, "p2": p2, "count": c,
                "sig_count": sigc, "sig_nsubj": nsubj, "auto2": tier2_auto,
                "subj": sd, "field": fld, "ctx": ctx})
json.dump(out, open(f"{R}/resid2.json", "w"), indent=1)
print("\n=== AUTO-TIER2 CANDIDATES (sig 3..19, nsubj>=2) ===")
for o in out:
    if o["auto2"]:
        print(f"  [{o['count']}x] kind={o['kind']} p1={o['p1']!r} nx={o['nx']!r} p2={o['p2']!r} | nsubj={o['sig_nsubj']} | subj={o['subj'][:28]!r}")
        print(f"        ...{o['ctx']}...")
print("\n=== OTHER PATTERNS (first 80, for hand review) ===")
for o in out:
    if not o["auto2"]:
        print(f"  [{o['count']}x] kind={o['kind']} p1={o['p1']!r} nx={o['nx']!r} | sigc={o['sig_count']} nsubj={o['sig_nsubj']} | subj={o['subj'][:28]!r} | ...{o['ctx'][:100]}...")
