#!/usr/bin/env python3
"""analyze_tail.py - measure the non-whitelisted (count<20) signature tail:
- per-lesson residual counts (how many lessons have residual donor-subject occurrences)
- sample contexts to see whether tail = rare builder framings or organic mentions
Streams a subset of shards (every 7th shard = ~4,700 shards, ~47k lessons) for speed.
"""
import sqlite3, json, gzip, os, re, collections, threading, random, time
import boto3
from botocore.config import Config
from concurrent.futures import ThreadPoolExecutor, as_completed

R = "/home/z/my-project/content/tertiary/recover"
ACC = "ff1e18e32afe87e8e07b3c35595fdd0e"
KID = "78b8e71ffccaf0bdf12b95a6b108000f"
SEC_ = "38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2"

ldb = sqlite3.connect(f"{R}/corpus.sqlite")
ldb.row_factory = sqlite3.Row
unit_meta = {}
for r in ldb.execute("select unit_id, course_id, sec, pos, title from units"):
    unit_meta[r["unit_id"]] = (r["course_id"], r["sec"], r["pos"], r["title"])
subjects = json.load(open(f"{R}/course_subjects.json"))
sig_ctx = json.load(open(f"{R}/sig_contexts.json"))
WHITE = set(tuple(k.split("|", 1)) for k, v in sig_ctx.items() if v >= 20)
TAIL_SIG = collections.Counter(tuple(k.split("|", 1)) for k, v in sig_ctx.items() if v < 20)

lock = threading.Lock()
resid_per_lesson = collections.Counter()
examples = []
ex_by_sig = collections.Counter()
stats = collections.Counter()
local = threading.local()

def texts_of(blob):
    out = []
    for nt in (blob.get("notes") or []):
        out.append(nt.get("heading", "") or "")
        out.append(nt.get("body", "") or "")
    out.extend(blob.get("key_points") or [])
    return out

def full_texts(blob):
    out = texts_of(blob)
    for q in blob.get("quiz") or []:
        out.append(q.get("stem", "") or "")
        out.append(q.get("explanation", "") or "")
        for v in (q.get("options") or {}).values():
            if isinstance(v, str):
                out.append(v)
    return out

def process(uid, blob):
    meta = unit_meta.get(uid)
    if not meta:
        return
    cid = meta[0]
    subj = subjects.get(cid)
    if not subj:
        return
    sw = subj.lower().split()
    lw = len(sw)
    resid = 0
    for text in full_texts(blob):
        words = text.split()
        low = [w.lower() for w in words]
        n = len(low)
        for i in range(0, n - lw + 1):
            if low[i:i + lw] == sw:
                p2 = " ".join(low[max(0, i - 2):i])
                nx = low[i + lw] if (i + lw) < n else "<END>"
                if (p2, nx) not in WHITE:
                    resid += 1
                    with lock:
                        if len(examples) < 4000 and ex_by_sig[(p2, nx)] < 3:
                            ex_by_sig[(p2, nx)] += 1
                            a = max(0, i - 8)
                            b = min(n, i + lw + 6)
                            examples.append(((p2, nx), " ".join(words[a:b]), subj, uid))
    with lock:
        resid_per_lesson[resid] += 1
        stats["lessons"] += 1
        stats["resid_occ"] += resid

def make_client():
    return boto3.client("s3", endpoint_url=f"https://{ACC}.r2.cloudflarestorage.com",
                        aws_access_key_id=KID, aws_secret_access_key=SEC_,
                        config=Config(connect_timeout=15, read_timeout=90,
                                      retries={"max_attempts": 3}),
                        region_name="auto")

def fetch_process(shard):
    if not hasattr(local, "c"):
        local.c = make_client()
    try:
        obj = local.c.get_object(Bucket="renance", Key=f"packs/p-{shard:05d}.json")
        pack = json.loads(obj["Body"].read())
        for uid, blob in pack.get("lessons", {}).items():
            process(uid, blob)
    except Exception:
        pass
    return shard

landed = sorted(int(x) for x in open(f"{R}/landed_shards.txt"))[::7]
print(f"scanning {len(landed)} shards (every 7th)...", flush=True)
t0 = time.time()
with ThreadPoolExecutor(max_workers=16) as ex:
    for f in as_completed([ex.submit(fetch_process, s) for s in landed]):
        f.result()
print(f"done {time.time()-t0:.0f}s", flush=True)
tot_lessons = stats["lessons"]
print(f"\nlessons scanned: {tot_lessons} | residual occurrences: {stats['resid_occ']}")
print("residual per lesson distribution (resid -> lessons):")
for k in sorted(resid_per_lesson)[:15]:
    print(f"   {k}: {resid_per_lesson[k]} ({100*resid_per_lesson[k]/tot_lessons:.2f}%)")
print(f"\nexamples ({len(examples)}):")
for (sig, ctx, subj, uid) in examples[:60]:
    print(f"  sig={sig} | subj={subj[:30]} | ...{ctx}...")
print("\ntail signature counts (top 30):")
for s, c in TAIL_SIG.most_common(30):
    print(f"  {c:4d}  ...{s[0]} >>> <<< {s[1]}...")
