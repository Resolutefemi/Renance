#!/usr/bin/env python3
"""push_r2_wave.py — incremental wave push for fully generated packs.

Same GET-merge-PUT as push_r2.py but with its OWN ledger, so a wave never
conflicts with the final full push. Usage:
  python3 push_r2_wave.py <pack> [<pack> ...]
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
SHARD_DIR = os.path.join(BUILD, "shards_wave")
DONE = os.path.join(BUILD, "wave_done.txt")
WORKERS = 8

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
stats = {"shards": 0, "lessons": 0, "bytes": 0, "errs": 0}


def shard_key(shard):
    return "packs/p-%05d.json" % shard


def push_shard(shard, path):
    import gzip as _gz
    with _gz.open(path, "rt") as fh:
        entries = []
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
    except Exception:
        pass
    for uid, raw in entries:
        lessons[uid] = json.loads(raw)
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
        os.remove(path)


def main():
    sys.path.insert(0, "/home/z/my-project/scripts")
    sys.path.insert(0, "/home/z/my-project/scripts/tert")
    packs = sys.argv[1:]
    assert packs, "usage: push_r2_wave.py <pack> [...]"
    from tert.router import route
    from tert import build_lesson

    corpus = json.load(open("/home/z/my-project/content/tertiary/corpus.json"))
    want = set()
    for c in corpus:
        pk = route(c)
        if pk in packs:
            if not build_lesson.gen_ready(pk):
                print("SKIP %s (pack not fully generated)" % pk)
                continue
            want.add(c["id"])
    print("courses to build: %d" % len(want))
    if not want:
        return
    os.makedirs(SHARD_DIR, exist_ok=True)

    from tert.build_all import build_one, make_blob, shard_of
    n = 0
    for c in corpus:
        if c["id"] not in want:
            continue
        built = build_one(c)
        if not built:
            continue
        ladder, blobs = built
        for uid, title, notes, quiz, S, kps, summary in blobs:
            b = make_blob(uid, title, notes, quiz, S, kps, summary)
            shard = shard_of(uid)
            import gzip as _gz
            with _gz.open(os.path.join(SHARD_DIR, "%05d.gz" % shard), "at") as h:
                h.write("%s\t%s\n" % (uid, json.dumps(b, ensure_ascii=False,
                                                       separators=(",", ":"))))
            n += 1
    print("built %d lessons into wave shards" % n)

    files = sorted(os.listdir(SHARD_DIR))
    print("wave shards to push:", len(files))
    t0 = time.time()
    with ThreadPoolExecutor(WORKERS) as ex:
        futs = [ex.submit(push_shard, int(f[:-3]), os.path.join(SHARD_DIR, f))
                for f in files]
        for f in futs:
            f.result()
    print("WAVE DONE: %d shards (%d lessons, %.2f GB), errors %d, in %.1f min" % (
        stats["shards"], stats["lessons"], stats["bytes"] / 1e9, stats["errs"],
        (time.time() - t0) / 60))


if __name__ == "__main__":
    main()
