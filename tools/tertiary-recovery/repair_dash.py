#!/usr/bin/env python3
"""repair_dash.py - rewrite the 4 argparse-flag fragments (which contain '--')
in the 22 affected live lessons, PUT the repaired shards back, and refresh the
donor files that hold those lessons. Resumable: repaired_shards.txt ledger.
Class A cost: one PUT per affected shard (~22).
"""
import json, gzip, os, collections, sys
import boto3
from botocore.config import Config

R = "/home/z/my-project/content/tertiary/recover"
ACC = "ff1e18e32afe87e8e07b3c35595fdd0e"
KID = "78b8e71ffccaf0bdf12b95a6b108000f"
SEC_ = "38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2"

REPL = [
    # (old fragment, new fragment)
    ("argparse in ten lines: parser = argparse.ArgumentParser(description='Monthly sales report'); parser.add_argument('--month', required=True); parser.add_argument('--state', default='ALL'); args = parser.parse_args().",
     "argparse in ten lines: parser = argparse.ArgumentParser(description='Monthly sales report'); parser.add_argument('month'); parser.add_argument('state', nargs='?', default='ALL'); args = parser.parse_args()."),
    ("Now python main.py --month Oct --state Lagos works, and --help prints documentation nobody had to write twice.",
     "Now python main.py Oct Lagos works, and a call with missing or unknown arguments prints usage and an error nobody had to write twice."),
    ("A report script that takes --month and --state arguments serves every month and state without edits, which is the difference between a toy and a tool.",
     "A report script that takes the month and state as arguments serves every month and state without edits, which is the difference between a toy and a tool."),
    ("named flags, defaults and automatic --help",
     "named arguments, defaults and automatic help"),
]

s3 = boto3.client("s3", endpoint_url=f"https://{ACC}.r2.cloudflarestorage.com",
                  aws_access_key_id=KID, aws_secret_access_key=SEC_,
                  config=Config(connect_timeout=15, read_timeout=120,
                                retries={"max_attempts": 3}),
                  region_name="auto")

def fnv1a32(s):
    h = 0x811C9DC5
    for b in s.encode():
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h

dash = json.load(open(f"{R}/dash_lessons.json"))
done = set()
if os.path.exists(f"{R}/repaired_shards.txt"):
    done = set(int(x) for x in open(f"{R}/repaired_shards.txt") if x.strip())

by_shard = collections.defaultdict(list)
for uid in dash:
    by_shard[fnv1a32(uid) % 60000].append(uid)
todo = {s: u for s, u in by_shard.items() if s not in done}
print(f"dash lessons: {len(dash)} | affected shards: {len(by_shard)} | to repair: {len(todo)}", flush=True)

# donor index for donor refresh
donor_index = json.load(open(f"{R}/donor_index.json"))
slot_of = {}
for k, uids in donor_index.items():
    for i, u in enumerate(uids):
        slot_of[u] = (k, i)

def fix_text(t):
    if "--" not in t:
        return t, 0
    n = 0
    for old, new in REPL:
        if old in t:
            t = t.replace(old, new)
            n += 1
    return t, n

def fix_blob(blob):
    changed = 0
    for nt in (blob.get("notes") or []):
        for f in ("heading", "body"):
            nt[f], n = fix_text(nt.get(f) or "")
            changed += n
    for kp in blob.get("key_points") or []:
        pass  # key_points handled via list rebuild below if needed
    new_kp = []
    for kp in blob.get("key_points") or []:
        kp2, n = fix_text(kp)
        new_kp.append(kp2)
        changed += n
    blob["key_points"] = new_kp
    for q in blob.get("quiz") or []:
        q["stem"], n = fix_text(q.get("stem") or "")
        changed += n
        q["explanation"], n = fix_text(q.get("explanation") or "")
        changed += n
        opts = q.get("options") or {}
        for k, v in opts.items():
            if isinstance(v, str):
                opts[k], n = fix_text(v)
                changed += n
    blob["summary"], n = fix_text(blob.get("summary") or "")
    changed += n
    return changed

ledger = open(f"{R}/repaired_shards.txt", "a")
for shard, uids in sorted(todo.items()):
    key_obj = f"packs/p-{shard:05d}.json"
    data = s3.get_object(Bucket="renance", Key=key_obj)["Body"].read()
    pack = json.loads(data)
    lessons = pack["lessons"]
    fixed_total = 0
    for uid in uids:
        blob = lessons.get(uid)
        if blob is None:
            print(f"  !! {uid} not in shard {shard}?!", flush=True)
            continue
        n = fix_blob(blob)
        # verify clean
        txts = [blob.get("summary", "")]
        for nt in blob.get("notes") or []:
            txts.append(nt.get("heading", "") or "")
            txts.append(nt.get("body", "") or "")
        for q in blob.get("quiz") or []:
            txts.append(q.get("stem", "") or "")
            txts.append(q.get("explanation", "") or "")
            for v in (q.get("options") or {}).values():
                if isinstance(v, str):
                    txts.append(v)
        txts.extend(blob.get("key_points") or [])
        if any("--" in t for t in txts):
            print(f"  !! {uid} still has '--' after fix", flush=True)
            sys.exit(1)
        fixed_total += n
        # refresh donor file if this uid is in rotation
        if uid in slot_of:
            k, i = slot_of[uid]
            fn = f"{R}/donors/{k}_{i}.json.gz"
            with gzip.open(fn, "wt") as f:
                json.dump({"uid": uid, "blob": blob}, f)
    payload = json.dumps(pack, ensure_ascii=False, separators=(",", ":")).encode()
    s3.put_object(Bucket="renance", Key=key_obj, Body=payload, ContentType="application/json")
    ledger.write(f"{shard}\n")
    ledger.flush()
    print(f"  shard {shard}: repaired {len(uids)} lessons, {fixed_total} fragments -> PUT ok", flush=True)
ledger.close()
print("ALL DASH REPAIRS LANDED")
