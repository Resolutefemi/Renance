#!/usr/bin/env python3
"""fill_gaps.py - for each unit in lesson_gaps.json:
1. GET its (landed) shard, double-check the lesson is truly absent
2. build the lesson from the donor rotation (same engine as assemble.py)
3. merge into the shard's lessons and PUT back (one Class A PUT per shard)
Output: gaps_filled.txt ledger; prints summary.
"""
import sqlite3, json, gzip, os, re, time, collections, datetime, sys
import boto3
from botocore.config import Config

R = "/home/z/my-project/content/tertiary/recover"
ACC = "ff1e18e32afe87e8e07b3c35595fdd0e"
KID = "78b8e71ffccaf0bdf12b95a6b108000f"
SEC_ = "38a5c0c95e93a6adb6bbb41a6c1297242d07c48ad23c0405bb631830083852d2"
TAIL = ": what it is, how it works, and where the marks are."
STRIP = re.compile(r"^[^\w]+|[^\w]+$")
def norm(w):
    return STRIP.sub("", w)

s3 = boto3.client("s3", endpoint_url=f"https://{ACC}.r2.cloudflarestorage.com",
                  aws_access_key_id=KID, aws_secret_access_key=SEC_,
                  config=Config(connect_timeout=15, read_timeout=120, retries={"max_attempts": 3}),
                  region_name="auto")

def fnv1a32(s):
    h = 0x811C9DC5
    for b in s.encode():
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h

# ---- corpus + state (same as assemble.py) ----
ldb = sqlite3.connect(f"{R}/corpus.sqlite")
ldb.row_factory = sqlite3.Row
subjects = json.load(open(f"{R}/course_subjects2.json"))
course_meta = json.load(open(f"{R}/course_meta.json"))
donor_index = json.load(open(f"{R}/donor_index.json"))
sig2_raw = json.load(open(f"{R}/sig_ctx2.json"))
T1 = set(); T2 = set()
for k, (c, ss) in sig2_raw.items():
    p, n = k.split("|", 1)
    if c >= 20:
        T1.add((p, n))
    elif 3 <= c < 20 and len(ss) >= 2:
        T2.add((p, n))
CLOSERS = re.compile(
    r"^\s*\.\s*(One small worked case|Keep the worked|Anything still fuzzy|"
    r"The plan is direct|The quiz that follows|Compare your own|"
    r"Note the exact wording|The unit builds|When you can rebuild)")
PY_NEXT = {"programs", "functions", "bugs", "teams", "course", "projects", "project", "work"}
PY_PREV = {"growing", "robust", "own", "most", "how", "serious", "plain", "real", "a", "in", "of"}
word_re = re.compile(r"[A-Za-z0-9']+", re.ASCII)

def sig_of(nn, i, lw, n):
    p2 = " ".join(nn[max(0, i - 2):i])
    nx = nn[i + lw] if (i + lw) < n else "<END>"
    return (p2, nx)

def splice_punct(words, i, lw, tw):
    first = words[i]; last = words[i + lw - 1]
    lead = ""; trail = ""
    m = re.match(r"^[^\w]+", first)
    if m and not m.group(0).endswith('"'):
        lead = m.group(0)
    m2 = re.search(r"[^\w]+$", last)
    if m2:
        trail = m2.group(0)
    new_tw = list(tw)
    if lead:
        new_tw[0] = lead + new_tw[0]
    if trail:
        new_tw[-1] = new_tw[-1] + trail
    return new_tw

def replace_text(text, sd, st, is_heading):
    sjw = [norm(w).lower() for w in sd.split()]
    tw = st.split()
    lw = len(sjw)
    if not text:
        return text, 0
    words = text.split()
    nn = [norm(w).lower() for w in words]
    n = len(words)
    pos = []
    for i in range(0, n - lw + 1):
        if nn[i:i + lw] == sjw:
            pos.append(i)
    if not pos:
        return text, 0
    replaced = []
    for i in pos:
        p2, nx = sig_of(nn, i, lw, n)
        p1 = nn[i - 1] if i else "<START>"
        rep = False
        if (p2, nx) in T1 or (p2, nx) in T2:
            rep = True
        elif is_heading and words[0].lower() == "inside" and i == 1 \
                and (words[i + lw - 1].endswith(":") or (i + lw < n and nn[i + lw] == ":")):
            rep = True
        elif CLOSERS.match(" ".join(words[i + lw:i + lw + 8])):
            rep = True
        elif p1 == "building" and nx == "work":
            rep = True
        elif p1 in PY_PREV and nx in PY_NEXT and len(sjw) >= 2:
            rep = True
        if rep:
            replaced.append(i)
    if not replaced:
        return text, 0
    out = []
    prev = 0
    for i in replaced:
        out.extend(words[prev:i])
        out.extend(splice_punct(words, i, lw, tw))
        prev = i + lw
    out.extend(words[prev:])
    return " ".join(out), len(replaced)

def replace_all(blob, sd, st):
    inj = 0
    for nt in blob.get("notes") or []:
        h, n1 = replace_text(nt.get("heading", "") or "", sd, st, True)
        b, n2 = replace_text(nt.get("body", "") or "", sd, st, False)
        nt["heading"], nt["body"] = h, b
        inj += n1 + n2
    new_kp = []
    for kp in blob.get("key_points") or []:
        k2, n3 = replace_text(kp, sd, st, False)
        new_kp.append(k2)
        inj += n3
    blob["key_points"] = new_kp
    for q in blob.get("quiz") or []:
        s, n4 = replace_text(q.get("stem", "") or "", sd, st, False)
        e, n5 = replace_text(q.get("explanation", "") or "", sd, st, False)
        q["stem"], q["explanation"] = s, e
        inj += n4 + n5
        for ok, ov in list((q.get("options") or {}).items()):
            if isinstance(ov, str):
                o2, n6 = replace_text(ov, sd, st, False)
                q["options"][ok] = o2
                inj += n6
    return inj

def unit_course(uid):
    r = ldb.execute("select course_id from units where unit_id=?", (uid,)).fetchone()
    return r["course_id"] if r else None

def donor_load(key):
    k = f"{key[0]}_{key[1]}_{key[2]}"
    uids = donor_index.get(k) or []
    out = []
    for slot, uid in enumerate(uids):
        fn = f"{R}/donors/hand_{k}.json.gz" if uid.startswith("HAND") else f"{R}/donors/{k}_{slot}.json.gz"
        try:
            d = json.load(gzip.open(fn))
        except Exception:
            continue
        subj = d.get("subject") or subjects.get(unit_course(d["uid"]))
        if subj:
            out.append({"subject": subj, "blob": d["blob"]})
    return out

def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def build_lesson(uid):
    r = ldb.execute("select course_id, sec, pos, title from units where unit_id=?", (uid,)).fetchone()
    cid, sec, pos, title = r["course_id"], r["sec"], r["pos"], r["title"]
    sigh = course_meta[cid]["sigh"]
    key = (sigh, sec, pos)
    donors = donor_load(key)
    if not donors:
        return None, "no donors"
    # rotation by shard-independent counter: use existing count of same-key missing units
    # simple: hash of uid for spread
    donor = donors[hash(uid) % len(donors)]
    sd, st = donor["subject"], subjects[cid]
    blob = json.loads(json.dumps(donor["blob"]))
    inj = replace_all(blob, sd, st)
    blob["topic_id"] = uid
    blob["title"] = title
    blob["summary"] = f"{title} in {st}{TAIL}"
    for qi, q in enumerate(blob["quiz"]):
        q["id"] = f"{uid}-q{qi+1:02d}"
    blob["generated_at"] = now_iso()
    # validations
    errs = []
    if len(blob.get("notes") or []) != 10:
        errs.append("notes")
    for nt in blob["notes"]:
        if len(word_re.findall(nt.get("body", ""))) > 300:
            errs.append("word300")
            break
    all_t = [blob["summary"]] + [x["heading"] + " " + x["body"] for x in blob["notes"]]
    all_t += blob.get("key_points") or []
    for q in blob["quiz"]:
        all_t.append(q["stem"] + " " + q["explanation"])
    if any("--" in t for t in all_t):
        errs.append("dash")
    if inj < 1:
        errs.append("inj0")
    if errs:
        return None, ",".join(errs)
    return blob, None

gaps = json.load(open(f"{R}/lesson_gaps.json"))
print(f"gap units: {len(gaps)}", flush=True)

# group by shard, verify absence, build, merge, PUT
by_shard = collections.defaultdict(list)
for uid in gaps:
    by_shard[fnv1a32(uid) % 60000].append(uid)
print(f"distinct shards: {len(by_shard)}", flush=True)

filled = 0
failures = []
for shard, uids in sorted(by_shard.items()):
    key_obj = f"packs/p-{shard:05d}.json"
    data = s3.get_object(Bucket="renance", Key=key_obj)["Body"].read()
    pack = json.loads(data)
    lessons = pack["lessons"]
    add = {}
    for uid in uids:
        if uid in lessons:
            continue  # actually present
        blob, err = build_lesson(uid)
        if blob is None:
            failures.append((uid, err))
            continue
        add[uid] = blob
    if not add:
        continue
    lessons.update(add)
    payload = json.dumps({"v": 1, "lessons": lessons}, ensure_ascii=False, separators=(",", ":")).encode()
    s3.put_object(Bucket="renance", Key=key_obj, Body=payload, ContentType="application/json")
    filled += len(add)
    print(f"  shard {shard}: +{len(add)} lessons PUT ok", flush=True)

print(f"\nGAPS FILLED: {filled} | failures: {len(failures)}")
for f in failures:
    print("   ", f)
print(f"Class A total now: 33098 + 22 + 26899 + {len([s for s,_ in by_shard.items()])} gap-PUTs "
      f"= {33098 + 22 + 26899 + len(by_shard)}")
