#!/usr/bin/env python3
"""verify_samples.py — post-push R2 verification (GET only, Class B free).

Pulls 3 random shard packs listed in pack_done.txt, samples lessons and
checks the founder band: 10 notes, every note body 150-250 words,
20 quiz items. Writes build/v3_final_report.txt.
"""
import gzip
import json
import os
import random
import sys

import boto3
import botocore

ACC = "ff1e18e32afe87e8e07b3c35595fdd0e"
KEY = "78b8e71ffccaf0bdf12b95a6b108000f"
SECRET = "38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2"
BUCKET = "renance"
ENDPOINT = "https://%s.r2.cloudflarestorage.com" % ACC
BUILD = "/home/z/my-project/content/tertiary/build"

s3 = boto3.client("s3", endpoint_url=ENDPOINT, aws_access_key_id=KEY,
                  aws_secret_access_key=SECRET, region_name="auto",
                  config=botocore.config.Config(retries={"max_attempts": 2},
                                                signature_version="s3v4"))

lines = [x.strip() for x in open(os.path.join(BUILD, "pack_done.txt")) if x.strip()]
if not lines:
    print("no pack_done ledger; push did not run?")
    sys.exit(1)
picks = random.sample(lines, min(3, len(lines)))

out = []
allok = True
for shard in picks:
    key = "packs/p-%05d.json" % int(shard)
    resp = s3.get_object(Bucket=BUCKET, Key=key)
    data = json.loads(resp["Body"].read())
    lessons = data.get("lessons", {})
    uids = sorted(lessons.keys())
    sample = random.sample(uids, min(3, len(uids)))
    for uid in sample:
        b = lessons[uid]
        wc = [len(n["body"].split()) for n in b.get("notes", [])]
        n_notes = len(b.get("notes", []))
        n_quiz = len(b.get("quiz", []))
        ok_band = all(150 <= w <= 250 for w in wc)
        ok_shape = n_notes == 10 and n_quiz == 20
        if not (ok_band and ok_shape):
            allok = False
        out.append("%s %s notes=%d quiz=%d words=%s src=%s band_ok=%s" % (
            key, uid, n_notes, n_quiz, wc, b.get("source"), ok_band and ok_shape))

report = "\n".join(out) + "\nVERDICT: " + ("PASS" if allok else "FAIL") + "\n"
print(report)
with open(os.path.join(BUILD, "v3_final_report.txt"), "w") as f:
    f.write(report)
sys.exit(0 if allok else 2)
