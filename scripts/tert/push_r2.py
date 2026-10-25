#!/usr/bin/env python3
"""push_r2.py (v3) — disk- and memory-safe push for a 3 GB-RAM / 10 GB-disk box.

Phase 1: convert blobs_*.jsonl -> per-shard files content/tertiary/build/shards/<NNNNN>
         (append streaming; DELETE each blobs source after conversion to stay
          inside the disk budget)
Phase 2: for every shard file: GET existing pack (Class B free) -> merge -> ONE
         PUT (Class A) -> delete the shard file (frees disk as we go)
Resume: build/pack_done.txt + presence of shard files. Hard cap 140k PUTs.
"""
import glob
import json
import os
import sys
import threading
import time
from concurrent.futures import ThreadPoolExecutor

import boto3

BUILD = "/home/z/my-project/content/tertiary/build"
SHARD_DIR = os.path.join(BUILD, "shards")
DONE = os.path.join(BUILD, "pack_done.txt")
CAP = 140000
WORKERS = 12

R2_ENDPOINT = "https://ff1e18e32afe87e8e07b3c35595fdd0e.r2.cloudflarestorage.com"
R2_BUCKET = "renance"
R2_AK = "78b8e71ffccaf0bdf12b95a6b108000f"
R2_SK = "38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2"

s3 = boto3.client(
    "s3", endpoint_url=R2_ENDPOINT, aws_access_key_id=R2_AK,
    aws_secret_access_key=R2_SK,
    config=boto3.session.Config(max_pool_connections=WORKERS, retries={"max_attempts": 4}),
)

lock = threading.Lock()
stats = {"shards": 0, "lessons": 0, "bytes": 0, "merged": 0, "fresh": 0, "errs": 0}


def shard_key(shard):
    return "packs/p-%05d.json" % shard


def push_shard(shard, paths):
    """paths: list of part files (multi-member gzip) for one shard.
    GET existing pack (Class B free) -> merge -> ONE PUT (Class A)."""
    if stats["shards"] >= CAP:
        return
    import gzip as _gz
    entries = []
    for path in paths:
        with _gz.open(path, "rt") as fh:
            for line in fh:
                uid, raw = line.rstrip("\n").split("\t", 1)
                entries.append((uid, raw.encode("utf-8")))
    key = shard_key(shard)
    lessons = {}
    try:
        resp = s3.get_object(Bucket=R2_BUCKET, Key=key)
        existing = json.loads(resp["Body"].read())
        if isinstance(existing, dict) and isinstance(existing.get("lessons"), dict):
            lessons = existing["lessons"]
            with lock:
                stats["merged"] += 1
    except s3.exceptions.NoSuchKey:
        with lock:
            stats["fresh"] += 1
    except Exception:
        with lock:
            stats["fresh"] += 1
    for uid, raw in entries:
        lessons[uid] = json.loads(raw)  # values are objects, matching the Go reader
    payload = json.dumps({"v": 1, "lessons": lessons}, ensure_ascii=False,
                         separators=(",", ":")).encode("utf-8")
    ok = False
    for attempt in range(3):
        try:
            s3.put_object(Bucket=R2_BUCKET, Key=key, Body=payload,
                          ContentType="application/json")
            ok = True
            break
        except Exception as e:
            if attempt == 2:
                with lock:
                    stats["errs"] += 1
                sys.stderr.write("PUT %s failed: %s\n" % (key, e))
            time.sleep(1.5 * (attempt + 1))
    if ok:
        with lock:
            stats["shards"] += 1
            stats["lessons"] += len(entries)
            stats["bytes"] += len(payload)
        with open(DONE, "a") as f:
            f.write("%d\n" % shard)
        for path in paths:
            try:
                os.remove(path)
            except OSError:
                pass


def phase1():
    """Convert blobs jsonl -> per-shard files, deleting sources as we go."""
    os.makedirs(SHARD_DIR, exist_ok=True)
    done = set()
    if os.path.exists(DONE):
        done = {int(x) for x in open(DONE).read().split() if x.strip()}
    t0 = time.time()
    n = 0
    for f in sorted(glob.glob(BUILD + "/blobs_*.jsonl")):
        handles = {}
        with open(f) as fh:
            for line in fh:
                shard, uid, blob = json.loads(line)
                if shard in done:
                    continue
                raw = json.dumps(blob, ensure_ascii=False, separators=(",", ":"))
                h = handles.get(shard)
                if h is None:
                    if len(handles) > 256:
                        for hh in handles.values():
                            hh.close()
                        handles = {}
                    import gzip as _gz
                    h = _gz.open(os.path.join(SHARD_DIR, "%05d.gz" % shard), "at")
                    handles[shard] = h
                h.write("%s\t%s\n" % (uid, raw))
                n += 1
        for hh in handles.values():
            hh.close()
        os.remove(f)
        print("  converted %s (%.1f min elapsed)" % (os.path.basename(f), (time.time() - t0) / 60))
    print("phase1 done: %d lessons into per-shard files in %.1f min" % (n, (time.time() - t0) / 60))


def main():
    if "--phase1-only" not in sys.argv:
        pass
    phase1()
    if "--phase1-only" in sys.argv:
        return

    # group part files by shard number (supports <NNNNN>.gz and <NNNNN>.p<W>.gz)
    groups = {}
    for name in sorted(os.listdir(SHARD_DIR)):
        if not name.endswith(".gz"):
            continue
        base = name[:-3].split(".")[0]
        try:
            shard = int(base)
        except ValueError:
            continue
        groups.setdefault(shard, []).append(os.path.join(SHARD_DIR, name))
    print("shard groups to push:", len(groups))
    t0 = time.time()
    with ThreadPoolExecutor(WORKERS) as ex:
        futures = []
        for i, (shard, paths) in enumerate(sorted(groups.items())):
            futures.append(ex.submit(push_shard, shard, paths))
            if i and i % 4000 == 0:
                el = (time.time() - t0) / 60
                print("  queued %d | landed %d PUTs, %.0f MB, %.1f min" % (
                    i, stats["shards"], stats["bytes"] / 1e6, el))
                time.sleep(0.5)
        for fut in futures:
            fut.result()
    print("DONE: %d shard PUTs (%d lessons, %.2f GB), merged %d fresh %d, errors %d, in %.1f min" % (
        stats["shards"], stats["lessons"], stats["bytes"] / 1e9,
        stats["merged"], stats["fresh"], stats["errs"], (time.time() - t0) / 60))
    if stats["errs"]:
        print("re-run to retry failed shards")


if __name__ == "__main__":
    main()
