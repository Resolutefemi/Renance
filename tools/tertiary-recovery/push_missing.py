#!/usr/bin/env python3
"""push_missing.py [start] [end] - PUT the staged shards to R2.
For each shards_new/<NNNNN>.jsonl.gz: read uid\t{blob} lines, build the
{"v":1,"lessons":{...}} envelope, single PUT per shard (one Class A op each).
Resumable: pushed_shards.txt ledger. Retries 3x. Never deletes staging.
"""
import gzip, json, os, sys, time, threading, hashlib
import boto3
from botocore.config import Config
from concurrent.futures import ThreadPoolExecutor, as_completed

R = "/home/z/my-project/content/tertiary/recover"
STAGE = f"{R}/shards_new"
ACC = "ff1e18e32afe87e8e07b3c35595fdd0e"
KID = "78b8e71ffccaf0bdf12b95a6b108000f"
SEC_ = "38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2"
THREADS = 24

start_i = int(sys.argv[1]) if len(sys.argv) > 1 else 0
end_i = int(sys.argv[2]) if len(sys.argv) > 2 else 10 ** 9

done = set()
if os.path.exists(f"{R}/pushed_shards.txt"):
    done = set(int(x) for x in open(f"{R}/pushed_shards.txt") if x.strip())
all_shards = sorted(int(f.split(".")[0]) for f in os.listdir(STAGE) if f.endswith(".jsonl.gz"))
todo = [s for s in all_shards[start_i:end_i] if s not in done]
print(f"staging shards: {len(all_shards)} | done: {len(done)} | todo: {len(todo)}", flush=True)

ledger_lock = threading.Lock()
ledger = open(f"{R}/pushed_shards.txt", "a")
stats = {"ok": 0, "fail": 0, "lessons": 0, "bytes": 0}
lock = threading.Lock()
local = threading.local()

def make_client():
    return boto3.client("s3", endpoint_url=f"https://{ACC}.r2.cloudflarestorage.com",
                        aws_access_key_id=KID, aws_secret_access_key=SEC_,
                        config=Config(connect_timeout=15, read_timeout=120,
                                      retries={"max_attempts": 2}),
                        region_name="auto")

def push_shard(shard):
    if not hasattr(local, "c"):
        local.c = make_client()
    fn = f"{STAGE}/{shard:05d}.jsonl.gz"
    lessons = {}
    n = 0
    # read possibly multi-member gzip
    with gzip.open(fn, "rt") as fh:
        for line in fh:
            if not line.strip():
                continue
            tab = line.find("\t")
            uid = line[:tab]
            blob = json.loads(line[tab + 1:])
            # final safety: topic_id must equal uid
            if blob.get("topic_id") != uid:
                blob["topic_id"] = uid
            lessons[uid] = blob
            n += 1
    if not lessons:
        with lock:
            stats["fail"] += 1
        return f"EMPTY {shard}"
    payload = json.dumps({"v": 1, "lessons": lessons},
                         ensure_ascii=False, separators=(",", ":")).encode()
    key = f"packs/p-{shard:05d}.json"
    err = None
    for attempt in range(3):
        try:
            local.c.put_object(Bucket="renance", Key=key, Body=payload,
                               ContentType="application/json")
            err = None
            break
        except Exception as e:
            err = str(e)[:90]
            time.sleep(2 * (attempt + 1))
    with lock:
        if err is None:
            stats["ok"] += 1
            stats["lessons"] += n
            stats["bytes"] += len(payload)
            ledger.write(f"{shard}\n")
            ledger.flush()
        else:
            stats["fail"] += 1
    return f"{shard}: {'ok' if err is None else 'FAIL ' + err}"

t0 = time.time()
cnt = 0
with ThreadPoolExecutor(max_workers=THREADS) as ex:
    for res in as_completed([ex.submit(push_shard, s) for s in todo]):
        r = res.result()
        cnt += 1
        if cnt % 1000 == 0:
            el = time.time() - t0
            print(f"  {cnt}/{len(todo)} | ok {stats['ok']} fail {stats['fail']} | "
                  f"{stats['lessons']} lessons | {stats['bytes']/1e6:.0f} MB | {el/60:.1f} min", flush=True)
ledger.close()
print(f"\nPUSH DONE: ok={stats['ok']} fail={stats['fail']} lessons={stats['lessons']} "
      f"in {(time.time()-t0)/60:.1f} min", flush=True)
fails = stats["fail"]
print("Class A ledger: previous landed 33098 + dash repairs 22 + this push "
      f"{stats['ok']} = {33098 + 22 + stats['ok']} total (< 150000)")
