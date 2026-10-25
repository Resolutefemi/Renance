#!/usr/bin/env python3
"""bench_push.py — measure real R2 GET+merge+PUT throughput at N workers."""
import json
import sys
import threading
import time

import boto3
import botocore

ACC = "ff1e18e32afe87e8e07b3c35595fdd0e"
BUCKET = "renance"
ENDPOINT = "https://%s.r2.cloudflarestorage.com" % ACC
WORKERS = int(sys.argv[1]) if len(sys.argv) > 1 else 24
N = int(sys.argv[2]) if len(sys.argv) > 2 else 60

s3 = boto3.client("s3", endpoint_url=ENDPOINT,
                  aws_access_key_id="78b8e71ffccaf0bdf12b95a6b108000f",
                  aws_secret_access_key="38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2",
                  region_name="auto",
                  config=botocore.config.Config(max_pool_connections=WORKERS + 4,
                                                retries={"max_attempts": 2},
                                                signature_version="s3v4"))
lock = threading.Lock()
stats = {"ok": 0, "fresh": 0, "err": 0, "bytes": 0}
t0 = time.time()


def one(i):
    key = "packs/p-%05d.json" % (30000 + i)
    try:
        try:
            resp = s3.get_object(Bucket=BUCKET, Key=key)
            lessons = json.loads(resp["Body"].read()).get("lessons", {})
            with lock:
                stats["ok"] += 1
        except s3.exceptions.NoSuchKey:
            lessons = {}
            with lock:
                stats["fresh"] += 1
        lessons["BENCH-%04d" % i] = {"topic_id": "BENCH", "title": "bench", "summary": "x",
                                     "notes": [], "key_points": [], "quiz": [], "drawings": []}
        payload = json.dumps({"v": 1, "lessons": lessons}, ensure_ascii=False,
                             separators=(",", ":")).encode()
        s3.put_object(Bucket=BUCKET, Key=key, Body=payload, ContentType="application/json")
        with lock:
            stats["bytes"] += len(payload)
    except Exception as e:
        with lock:
            stats["err"] += 1


from concurrent.futures import ThreadPoolExecutor
with ThreadPoolExecutor(WORKERS) as ex:
    list(ex.map(one, range(N)))
el = time.time() - t0
print("workers=%d n=%d elapsed=%.1fs => %.0f shards/min (ok=%d fresh=%d err=%d)" % (
    WORKERS, N, el, N / el * 60, stats["ok"], stats["fresh"], stats["err"]))
