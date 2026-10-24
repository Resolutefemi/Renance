#!/usr/bin/env python3
"""find_lesson_gaps.py [start] [end] - rescan landed shards collecting the set of
tertiary unit_ids that HAVE lessons. Diff vs corpus to find units in landed
shards with NO lesson blob. Output: lesson_gaps.json
"""
import sqlite3, json, gzip, os, threading, time, sys
import boto3
from botocore.config import Config
from concurrent.futures import ThreadPoolExecutor, as_completed

R = "/home/z/my-project/content/tertiary/recover"
ACC = "ff1e18e32afe87e8e07b3c35595fdd0e"
KID = "78b8e71ffccaf0bdf12b95a6b108000f"
SEC_ = "38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2"
start_i = int(sys.argv[1]) if len(sys.argv) > 1 else 0
end_i = int(sys.argv[2]) if len(sys.argv) > 2 else 10 ** 9

ldb = sqlite3.connect(f"{R}/corpus.sqlite")
ldb.row_factory = sqlite3.Row
unit_meta = {}
for r in ldb.execute("select unit_id, course_id, sec, pos, title from units"):
    unit_meta[r["unit_id"]] = (r["course_id"], r["sec"], r["pos"], r["title"])
landed = set(int(x) for x in open(f"{R}/landed_shards.txt"))

# expected: units whose shard landed
def fnv1a32(s):
    h = 0x811C9DC5
    for b in s.encode():
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h
expected = {}
for uid, meta in unit_meta.items():
    if fnv1a32(uid) % 60000 in landed:
        expected[uid] = meta
print(f"expected in landed shards: {len(expected)}", flush=True)

seen_file = f"{R}/seen_uids.json.gz"
seen = set()
if os.path.exists(seen_file):
    with gzip.open(seen_file, "rt") as f:
        seen = set(x.strip() for x in f if x.strip())
print(f"seen so far: {len(seen)}", flush=True)
lock = threading.Lock()
new_seen = []
_tls = threading.local()

def scan(shard):
    if not hasattr(_tls, "c"):
        _tls.c = boto3.client("s3", endpoint_url=f"https://{ACC}.r2.cloudflarestorage.com",
                              aws_access_key_id=KID, aws_secret_access_key=SEC_,
                              config=Config(connect_timeout=15, read_timeout=90,
                                            retries={"max_attempts": 3}),
                              region_name="auto")
    try:
        obj = _tls.c.get_object(Bucket="renance", Key=f"packs/p-{shard:05d}.json")
        pack = json.loads(obj["Body"].read())
        uids = [u for u in pack.get("lessons", {}) if u in expected]
        with lock:
            new_seen.extend(uids)
    except Exception:
        pass
    return shard

work = sorted(landed)[start_i:end_i]
print(f"scanning {len(work)} shards...", flush=True)
t0 = time.time()
with ThreadPoolExecutor(max_workers=16) as ex:
    for f in as_completed([ex.submit(scan, s) for s in work]):
        f.result()
seen.update(new_seen)
# persist
if seen:
    with gzip.open(seen_file, "wt") as f:
        f.write("\n".join(sorted(seen)))
print(f"seen total: {len(seen)} | new: {len(new_seen)} | {time.time()-t0:.0f}s", flush=True)
gaps = sorted(set(expected) - seen)
print(f"UNITS WITH LANDED SHARD BUT NO LESSON: {len(gaps)}")
json.dump(gaps, open(f"{R}/lesson_gaps.json", "w"))
for u in gaps[:20]:
    print("  ", u, unit_meta[u])
