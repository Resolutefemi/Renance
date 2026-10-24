#!/usr/bin/env python3
"""verify_final.py - end-to-end verification of the completed archive:
1. sample N random units from the corpus (all 21 packs)
2. GET their pack shard from R2, extract the lesson
3. validate founder requirements: lesson present, 10 notes, every note <=300 words,
   no '--' anywhere, 20 quiz, mcq options A-D, quiz id matches unit, summary formula
4. report per-pack pass rates
"""
import sqlite3, json, gzip, random, re, collections, sys, time
import boto3
from botocore.config import Config
from concurrent.futures import ThreadPoolExecutor, as_completed

R = "/home/z/my-project/content/tertiary/recover"
ACC = "ff1e18e32afe87e8e07b3c35595fdd0e"
KID = "78b8e71ffccaf0bdf12b95a6b108000f"
SEC_ = "38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2"
N = 300
TAIL = ": what it is, how it works, and where the marks are."
word_re = re.compile(r"[A-Za-z0-9']+", re.ASCII)

def fnv1a32(s):
    h = 0x811C9DC5
    for b in s.encode():
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h

ldb = sqlite3.connect(f"{R}/corpus.sqlite")
ldb.row_factory = sqlite3.Row
units = ldb.execute("select unit_id, title from units order by random() limit ?", (N,)).fetchall()
course_meta = json.load(open(f"{R}/course_meta.json"))
rows = ldb.execute(
    "select u.unit_id, u.title, u.course_id from units u order by random() limit ?", (N,)).fetchall()
print(f"sampled {len(rows)} units", flush=True)

s3 = boto3.client("s3", endpoint_url=f"https://{ACC}.r2.cloudflarestorage.com",
                  aws_access_key_id=KID, aws_secret_access_key=SEC_,
                  config=Config(connect_timeout=15, read_timeout=90, retries={"max_attempts": 2}),
                  region_name="auto")

local = threading_local if False else None
import threading
_tls = threading.local()

def check_unit(uid, title, cid):
    if not hasattr(_tls, "c"):
        _tls.c = boto3.client("s3", endpoint_url=f"https://{ACC}.r2.cloudflarestorage.com",
                              aws_access_key_id=KID, aws_secret_access_key=SEC_,
                              config=Config(connect_timeout=15, read_timeout=90,
                                            retries={"max_attempts": 2}),
                              region_name="auto")
    shard = fnv1a32(uid) % 60000
    obj = _tls.c.get_object(Bucket="renance", Key=f"packs/p-{shard:05d}.json")
    pack = json.loads(obj["Body"].read())
    blob = pack.get("lessons", {}).get(uid)
    if blob is None:
        return (uid, "MISSING", [])
    errs = []
    if blob.get("title") != title:
        errs.append("title")
    if len(blob.get("notes") or []) != 10:
        errs.append("notes!=10")
    for nt in blob["notes"]:
        if len(word_re.findall(nt.get("body", ""))) > 300:
            errs.append("note>300")
            break
    if len(blob.get("quiz") or []) != 20:
        errs.append("quiz!=20")
    texts = [blob.get("summary", ""), blob.get("title", "")]
    for nt in blob["notes"]:
        texts.append(nt.get("heading", ""))
        texts.append(nt.get("body", ""))
    texts.extend(blob.get("key_points") or [])
    for q in blob["quiz"]:
        texts.append(q.get("stem", ""))
        texts.append(q.get("explanation", ""))
        for v in (q.get("options") or {}).values():
            if isinstance(v, str):
                texts.append(v)
        if q.get("type") == "mcq" and len(q.get("options") or {}) != 4:
            errs.append("mcqopts")
        if q.get("type") == "mcq" and q.get("answer") not in ("A", "B", "C", "D"):
            errs.append("anskey")
    for t in texts:
        if "--" in t:
            errs.append("dashdash")
            break
    if not (blob["summary"].endswith(TAIL) and blob["summary"].startswith(title + " in ")):
        errs.append("summary")
    for i, q in enumerate(blob["quiz"]):
        if not q.get("id", "").startswith(uid + "-q"):
            errs.append("qid")
            break
    return (uid, "ok" if not errs else "ERR", errs)

pack_of = {}
for cid, m in course_meta.items():
    pack_of[cid] = m["sigh"]

results = collections.Counter()
err_detail = []
per_pack = collections.Counter()
t0 = time.time()
with ThreadPoolExecutor(max_workers=12) as ex:
    futs = {ex.submit(check_unit, r["unit_id"], r["title"], r["course_id"]): r for r in rows}
    for fut in as_completed(futs):
        r = futs[fut]
        uid, status, errs = fut.result()
        results[status] += 1
        if status == "ERR":
            err_detail.append((uid, errs))
        per_pack[(pack_of[r["course_id"]], status)] += 1

print(f"done in {time.time()-t0:.0f}s")
print(f"OK: {results['ok']} | ERR: {results['ERR']} | MISSING: {results['MISSING']} / {len(rows)}")
for uid, errs in err_detail[:15]:
    print("   ", uid, errs)
print("\nper-pack sample (sigh -> ok/err):")
byp = collections.defaultdict(lambda: [0, 0])
for (sigh, st), n in per_pack.items():
    if st == "ok":
        byp[sigh][0] += n
    else:
        byp[sigh][1] += n
for sigh, (ok, err) in sorted(byp.items()):
    print(f"   sigh {sigh}: ok {ok} err {err}")
