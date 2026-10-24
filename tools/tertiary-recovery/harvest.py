#!/usr/bin/env python3
"""harvest.py [start_idx end_idx] - streaming pass over landed R2 shards.
Chunked: state saved to disk after each run, resumed via start/end indices.
State: course_subjects.json, sig_contexts.json, donor_index.json (+ donors/*.gz),
harvest_stats.json. All state merges across runs.
"""
import sqlite3, json, gzip, os, re, collections, threading, time, sys
import boto3
from botocore.config import Config
from concurrent.futures import ThreadPoolExecutor, as_completed

R = "/home/z/my-project/content/tertiary/recover"
ACC = "ff1e18e32afe87e8e07b3c35595fdd0e"
KID = "78b8e71ffccaf0bdf12b95a6b108000f"
SEC_ = "38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2"
N_DONORS = 8
SUMMARY_TAIL = ": what it is, how it works, and where the marks are."
THREADS = 16

start_i = int(sys.argv[1]) if len(sys.argv) > 1 else 0
end_i = int(sys.argv[2]) if len(sys.argv) > 2 else 10 ** 9

os.makedirs(f"{R}/donors", exist_ok=True)

# ---------- corpus ----------
print("loading corpus...", flush=True)
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
print(f"units: {len(unit_meta)} | needed keys: {len(needed_keys)}", flush=True)

# ---------- resumed state ----------
subjects = {}
sig_counts = collections.Counter()
donors = collections.defaultdict(list)
stats = collections.Counter()
if os.path.exists(f"{R}/course_subjects.json"):
    subjects = json.load(open(f"{R}/course_subjects.json"))
if os.path.exists(f"{R}/sig_contexts.json"):
    for k, v in json.load(open(f"{R}/sig_contexts.json")).items():
        p, n = k.split("|", 1)
        sig_counts[(p, n)] = v
if os.path.exists(f"{R}/donor_index.json"):
    for k, v in json.load(open(f"{R}/donor_index.json")).items():
        a, b, c = k.split("_", 2)
        donors[(int(a), int(b), int(c))] = v
if os.path.exists(f"{R}/harvest_stats.json"):
    try:
        stats.update({k: v for k, v in json.load(open(f"{R}/harvest_stats.json")).items()})
    except Exception:
        pass
print(f"resumed: {len(subjects)} subjects, {len(sig_counts)} signatures, {len(donors)} donor keys", flush=True)

lock = threading.Lock()
word_re = re.compile(r"[A-Za-z0-9']+")
local = threading.local()

def process_lesson(uid, blob):
    meta = unit_meta.get(uid)
    if meta is None:
        local.st["non_corpus_uid"] += 1
        return
    cid, sec, pos, db_title = meta
    if blob.get("title") != db_title:
        local.st["title_mismatch"] += 1
    notes = blob.get("notes") or []
    quiz = blob.get("quiz") or []
    local.st["lessons"] += 1
    if len(notes) != 10:
        local.st["notes_ne_10"] += 1
    over300 = dash2 = 0
    for nt in notes:
        body = nt.get("body", "") or ""
        wc = len(word_re.findall(body))
        if wc > 300:
            over300 += 1
        if "--" in body or "--" in (nt.get("heading") or ""):
            dash2 += 1
    if over300:
        local.st["notes_over300_lessons"] += 1
        local.st["notes_over300"] += over300
    if dash2:
        local.st["dash2_lessons"] += 1
    if len(quiz) != 20:
        local.st["quiz_ne_20"] += 1
    for q in quiz:
        if "--" in (q.get("stem", "") or ""):
            local.st["dash2_quiz"] += 1
        local.st[f"qtype_{q.get('type')}"] += 1
        if q.get("type") == "mcq" and len(q.get("options") or {}) != 4:
            local.st["mcq_opts_ne4"] += 1
        if not (q.get("id", "") or "").startswith(uid + "-q"):
            local.st["quiz_id_prefix_bad"] += 1

    summary = blob.get("summary", "") or ""
    subj = None
    if summary.startswith(db_title + " in ") and summary.endswith(SUMMARY_TAIL):
        subj = summary[len(db_title) + 4: len(summary) - len(SUMMARY_TAIL)]
        local.st["summary_formula_ok"] += 1
    else:
        local.st["summary_formula_bad"] += 1
    if subj is not None:
        with lock:
            prev = subjects.get(cid)
            if prev is None:
                subjects[cid] = subj
            elif prev != subj:
                local.st["subj_conflict"] += 1
        sjw = subj.lower().split()
        lw = len(sjw)
        texts = [summary]
        for nt in notes:
            texts.append(nt.get("heading", "") or "")
            texts.append(nt.get("body", "") or "")
        texts.extend(blob.get("key_points") or [])
        for q in quiz:
            texts.append(q.get("stem", "") or "")
            texts.append(q.get("explanation", "") or "")
        for text in texts:
            words = text.split()
            low = [w.lower() for w in words]
            n = len(low)
            for i in range(0, n - lw + 1):
                if low[i:i + lw] == sjw:
                    p2 = " ".join(low[max(0, i - 2):i])
                    nx = low[i + lw] if (i + lw) < n else "<END>"
                    local.sig[(p2, nx)] += 1
    sigh = course_meta[cid]["sigh"]
    key = (sigh, sec, pos)
    if key in needed_keys:
        with lock:
            lst = donors[key]
            if len(lst) < N_DONORS and uid not in lst:
                lst.append(uid)
                fn = f"{R}/donors/{key[0]}_{key[1]}_{key[2]}_{len(lst)-1}.json.gz"
                with gzip.open(fn, "wt") as f:
                    json.dump({"uid": uid, "blob": blob}, f)

def merge_local():
    with lock:
        sig_counts.update(local.sig)
        local.sig.clear()
        stats.update(local.st)
        local.st.clear()

def make_client():
    return boto3.client("s3", endpoint_url=f"https://{ACC}.r2.cloudflarestorage.com",
                        aws_access_key_id=KID, aws_secret_access_key=SEC_,
                        config=Config(connect_timeout=15, read_timeout=90,
                                      retries={"max_attempts": 3}),
                        region_name="auto")

def fetch_and_process(shard):
    if not hasattr(local, "sig"):
        local.sig = collections.Counter()
        local.st = collections.Counter()
        local.c = make_client()
    try:
        obj = local.c.get_object(Bucket="renance", Key=f"packs/p-{shard:05d}.json")
        data = obj["Body"].read()
        pack = json.loads(data)
        for uid, blob in pack.get("lessons", {}).items():
            process_lesson(uid, blob)
    except Exception as e:
        with lock:
            stats[f"fail_shard_{shard}"] = 1
    merge_local()
    return shard

landed = sorted(int(x) for x in open(f"{R}/landed_shards.txt"))
work = landed[start_i:end_i]
print(f"CHUNK [{start_i}:{end_i}] -> {len(work)} shards", flush=True)
t0 = time.time()
done = 0
with ThreadPoolExecutor(max_workers=THREADS) as ex:
    futs = [ex.submit(fetch_and_process, s) for s in work]
    for fut in as_completed(futs):
        fut.result()
        done += 1
        if done % 2000 == 0:
            el = time.time() - t0
            print(f"  {done}/{len(work)} | {stats['lessons']} lessons total | {el/60:.1f} min", flush=True)
print(f"chunk done in {(time.time()-t0)/60:.1f} min", flush=True)

# ---------- save state ----------
with open(f"{R}/course_subjects.json", "w") as f:
    json.dump(subjects, f)
with open(f"{R}/sig_contexts.json", "w") as f:
    json.dump({f"{p}|{n}": c for (p, n), c in sig_counts.items()}, f)
with open(f"{R}/donor_index.json", "w") as f:
    json.dump({f"{k[0]}_{k[1]}_{k[2]}": v for k, v in donors.items()}, f)
fails = [k for k in list(stats) if k.startswith("fail_shard_")]
json.dump({k: v for k, v in stats.items() if not k.startswith("fail_shard_")},
          open(f"{R}/harvest_stats.json", "w"))
print(f"state saved: {len(subjects)} subjects | {len(sig_counts)} sigs | {len(donors)} donor keys | fails: {len(fails)}", flush=True)
if fails:
    open(f"{R}/failed_shards.txt", "a").write("\n".join(f[10:] for f in fails) + "\n")
