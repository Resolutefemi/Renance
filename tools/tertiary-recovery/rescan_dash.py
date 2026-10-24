#!/usr/bin/env python3
"""rescan_dash.py [start] [end] - pass over landed shards to:
1. find unit_ids of lessons containing '--' (notes or quiz text) -> dash_lessons.json
2. retry the 2 failed shards and merge their lessons into donor store if needed
3. capture the non-corpus uids for inspection
Chunked like harvest.py.
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
start_i = int(sys.argv[1]) if len(sys.argv) > 1 else 0
end_i = int(sys.argv[2]) if len(sys.argv) > 2 else 10 ** 9

ldb = sqlite3.connect(f"{R}/corpus.sqlite")
ldb.row_factory = sqlite3.Row
unit_meta = {}
for r in ldb.execute("select unit_id, course_id, sec, pos, title from units"):
    unit_meta[r["unit_id"]] = (r["course_id"], r["sec"], r["pos"], r["title"])
course_meta = json.load(open(f"{R}/course_meta.json"))
needed_keys = set()
with gzip.open(f"{R}/missing_units.jsonl.gz", "rt") as f:
    for line in f:
        m = json.loads(line)
        needed_keys.add((m["sigh"], m["sec"], m["pos"]))

# resume dash set
dash_uids = set()
if os.path.exists(f"{R}/dash_lessons.json"):
    dash_uids = set(json.load(open(f"{R}/dash_lessons.json")))
non_corpus = collections.Counter()
if os.path.exists(f"{R}/non_corpus_uids.json"):
    non_corpus.update(json.load(open(f"{R}/non_corpus_uids.json")))
donors = collections.defaultdict(list)
N_DONORS = 8
if os.path.exists(f"{R}/donor_index.json"):
    for k, v in json.load(open(f"{R}/donor_index.json")).items():
        a, b, c = k.split("_", 2)
        donors[(int(a), int(b), int(c))] = v

lock = threading.Lock()
stats = collections.Counter()
local = threading.local()

def process(uid, blob):
    meta = unit_meta.get(uid)
    if meta is None:
        non_corpus[uid] += 1
        return
    has_dash = False
    texts = []
    for nt in (blob.get("notes") or []):
        texts.append(nt.get("heading", "") or "")
        texts.append(nt.get("body", "") or "")
    for q in (blob.get("quiz") or []):
        texts.append(q.get("stem", "") or "")
        texts.append(q.get("explanation", "") or "")
        for v in (q.get("options") or {}).values():
            if isinstance(v, str):
                texts.append(v)
    for t in texts:
        if "--" in t:
            has_dash = True
            break
    if has_dash:
        with lock:
            dash_uids.add(uid)
    # donor fill from this shard (donors only get added; never dups)
    cid, sec, pos, _ = meta
    sigh = course_meta[cid]["sigh"]
    key = (sigh, sec, pos)
    if key in needed_keys and not has_dash:
        with lock:
            lst = donors[key]
            if len(lst) < N_DONORS and uid not in lst:
                lst.append(uid)
                fn = f"{R}/donors/{key[0]}_{key[1]}_{key[2]}_{len(lst)-1}.json.gz"
                with gzip.open(fn, "wt") as f:
                    json.dump({"uid": uid, "blob": blob}, f)

def make_client():
    return boto3.client("s3", endpoint_url=f"https://{ACC}.r2.cloudflarestorage.com",
                        aws_access_key_id=KID, aws_secret_access_key=SEC_,
                        config=Config(connect_timeout=15, read_timeout=90,
                                      retries={"max_attempts": 4}),
                        region_name="auto")

def fetch_and_process(shard):
    if not hasattr(local, "c"):
        local.c = make_client()
    try:
        obj = local.c.get_object(Bucket="renance", Key=f"packs/p-{shard:05d}.json")
        pack = json.loads(obj["Body"].read())
        for uid, blob in pack.get("lessons", {}).items():
            process(uid, blob)
        with lock:
            stats["ok"] += 1
    except Exception:
        with lock:
            stats[f"fail_{shard}"] = 1
    return shard

landed = sorted(int(x) for x in open(f"{R}/landed_shards.txt"))
work = landed[start_i:end_i]
print(f"CHUNK [{start_i}:{end_i}] -> {len(work)} shards", flush=True)
t0 = time.time()
done = 0
with ThreadPoolExecutor(max_workers=THREADS) as ex:
    for fut in as_completed([ex.submit(fetch_and_process, s) for s in work]):
        fut.result()
        done += 1
        if done % 4000 == 0:
            print(f"  {done}/{len(work)} | {time.time()-t0:.0f}s | dash lessons so far: {len(dash_uids)}", flush=True)
fails = [k for k in stats if k.startswith("fail_")]
json.dump(sorted(dash_uids), open(f"{R}/dash_lessons.json", "w"))
json.dump(dict(non_corpus), open(f"{R}/non_corpus_uids.json", "w"))
with open(f"{R}/donor_index.json", "w") as f:
    json.dump({f"{k[0]}_{k[1]}_{k[2]}": v for k, v in donors.items()}, f)
print(f"done in {(time.time()-t0)/60:.1f} min | ok={stats['ok']} fails={len(fails)} {fails}")
print(f"dash lessons: {len(dash_uids)} | non_corpus: {dict(list(non_corpus.items())[:12])}")
print(f"donor keys now: {len(donors)}")
