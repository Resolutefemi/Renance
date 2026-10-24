#!/usr/bin/env python3
"""harvest2.py [start] [end] - normalized-token signature harvest over landed shards.
Changes vs harvest.py:
- tokens normalized (edge punctuation stripped) for phrase matching AND signatures
- per-signature: total count + distinct subject count (weaves repeat across many
  subjects; organic mentions stick to one subject)
- also detects subjects with punctuation-adjacent weaves the old pass missed
State: sig_ctx2.json (sig|count|nsubj), course_subjects2.json (should equal v1)
"""
import sqlite3, json, gzip, os, re, collections, threading, time, sys
import boto3
from botocore.config import Config
from concurrent.futures import ThreadPoolExecutor, as_completed

R = "/home/z/my-project/content/tertiary/recover"
ACC = "ff1e18e32afe87e8e07b3c35595fdd0e"
KID = "78b8e71ffccaf0bdf12b95a6b108000f"
SEC_ = "38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2"
THREADS = 16
SUMMARY_TAIL = ": what it is, how it works, and where the marks are."

start_i = int(sys.argv[1]) if len(sys.argv) > 1 else 0
end_i = int(sys.argv[2]) if len(sys.argv) > 2 else 10 ** 9

STRIP = re.compile(r"^[^\w]+|[^\w]+$")

def norm(w):
    return STRIP.sub("", w)

ldb = sqlite3.connect(f"{R}/corpus.sqlite")
ldb.row_factory = sqlite3.Row
unit_meta = {}
for r in ldb.execute("select unit_id, course_id, sec, pos, title from units"):
    unit_meta[r["unit_id"]] = (r["course_id"], r["sec"], r["pos"], r["title"])
course_meta = json.load(open(f"{R}/course_meta.json"))

sig_n = {}           # (p2, nx) -> [count, set(subjects)]
lock = threading.Lock()
local = threading.local()
stats = collections.Counter()
subjects2 = {}

def merge():
    with lock:
        for k, (c, ss) in local.sig.items():
            if k not in sig_n:
                sig_n[k] = [c, set(ss)]
            else:
                sig_n[k][0] += c
                sig_n[k][1].update(ss)
        local.sig.clear()
        stats.update(local.st)
        local.st.clear()

def process(uid, blob):
    meta = unit_meta.get(uid)
    if not meta:
        return
    cid, sec, pos, db_title = meta
    summary = blob.get("summary", "") or ""
    subj = None
    if summary.startswith(db_title + " in ") and summary.endswith(SUMMARY_TAIL):
        subj = summary[len(db_title) + 4: len(summary) - len(SUMMARY_TAIL)]
        local.st["formula_ok"] += 1
    else:
        local.st["formula_bad"] += 1
    if not subj:
        return
    with lock:
        if cid not in subjects2:
            subjects2[cid] = subj
    sjw = [norm(w).lower() for w in subj.split()]
    lw = len(sjw)
    texts = []
    for nt in (blob.get("notes") or []):
        texts.append(nt.get("heading", "") or "")
        texts.append(nt.get("body", "") or "")
    texts.extend(blob.get("key_points") or [])
    for text in texts:
        words = text.split()
        nn = [norm(w).lower() for w in words]
        n = len(words)
        for i in range(0, n - lw + 1):
            if nn[i:i + lw] == sjw:
                p2 = " ".join(nn[max(0, i - 2):i])
                nx = nn[i + lw] if (i + lw) < n else "<END>"
                key = (p2, nx)
                if key not in local.sig:
                    local.sig[key] = [0, set()]
                local.sig[key][0] += 1
                local.sig[key][1].add(subj)
    # quiz texts too
    for q in (blob.get("quiz") or []):
        for f in ("stem", "explanation"):
            text = q.get(f, "") or ""
            words = text.split()
            nn = [norm(w).lower() for w in words]
            n = len(words)
            for i in range(0, n - lw + 1):
                if nn[i:i + lw] == sjw:
                    p2 = " ".join(nn[max(0, i - 2):i])
                    nx = nn[i + lw] if (i + lw) < n else "<END>"
                    key = (p2, nx)
                    if key not in local.sig:
                        local.sig[key] = [0, set()]
                    local.sig[key][0] += 1
                    local.sig[key][1].add(subj)

def make_client():
    return boto3.client("s3", endpoint_url=f"https://{ACC}.r2.cloudflarestorage.com",
                        aws_access_key_id=KID, aws_secret_access_key=SEC_,
                        config=Config(connect_timeout=15, read_timeout=90,
                                      retries={"max_attempts": 3}),
                        region_name="auto")

def fetch_process(shard):
    if not hasattr(local, "sig"):
        local.sig = {}
        local.st = collections.Counter()
        local.c = make_client()
    try:
        obj = local.c.get_object(Bucket="renance", Key=f"packs/p-{shard:05d}.json")
        pack = json.loads(obj["Body"].read())
        for uid, blob in pack.get("lessons", {}).items():
            process(uid, blob)
    except Exception:
        local.st[f"fail_{shard}"] = 1
    merge()
    return shard

landed = sorted(int(x) for x in open(f"{R}/landed_shards.txt"))
work = landed[start_i:end_i]
print(f"CHUNK [{start_i}:{end_i}] -> {len(work)} shards", flush=True)
t0 = time.time()
done = 0
with ThreadPoolExecutor(max_workers=THREADS) as ex:
    for fut in as_completed([ex.submit(fetch_process, s) for s in work]):
        fut.result()
        done += 1
        if done % 4000 == 0:
            print(f"  {done}/{len(work)} | {time.time()-t0:.0f}s | sigs {len(sig_n)}", flush=True)

# merge with saved state
if os.path.exists(f"{R}/sig_ctx2.json") and start_i > 0:
    old = json.load(open(f"{R}/sig_ctx2.json"))
    for k, (c, ss) in old.items():
        p, n = k.split("|", 1)
        key = (p, n)
        if key not in sig_n:
            sig_n[key] = [c, set(ss)]
        else:
            sig_n[key][0] += c
            sig_n[key][1].update(ss)
if subjects2:
    old_subj = {}
    if os.path.exists(f"{R}/course_subjects2.json"):
        old_subj = json.load(open(f"{R}/course_subjects2.json"))
    old_subj.update(subjects2)
    json.dump(old_subj, open(f"{R}/course_subjects2.json", "w"))
json.dump({f"{p}|{n}": [c, sorted(ss)] for (p, n), (c, ss) in sig_n.items()},
          open(f"{R}/sig_ctx2.json", "w"))
fails = [k for k in stats if k.startswith("fail_")]
print(f"chunk done {(time.time()-t0)/60:.1f} min | sigs {len(sig_n)} | formula ok {stats['formula_ok']} bad {stats['formula_bad']} | fails {len(fails)}", flush=True)
tot = sum(c for c, _ in sig_n.values())
cov = sum(c for c, ss in sig_n.values() if c >= 20)
print(f"total occurrences {tot} | >=20 coverage {100*cov/tot:.2f}%", flush=True)
