#!/usr/bin/env python3
"""assemble.py [key_start] [key_end] - build all missing lessons from donors.

Replacement tiers for donor-subject occurrences (normalized tokens):
  T1: framing signature count >= 20 (sig_ctx2.json)
  T2: signature count 3..19 AND seen with >= 2 distinct subjects
  T3: note heading matching 'Inside <subj>:' prefix
  T4: explicit residual rules: closing-framing markers right after the
      occurrence, the building doubling pair, and the python modifier-noun family
  else: keep (organic mention)

Each built lesson is validated: 10 notes <=300 words, no '--', 20 quiz with
mcq 4 options, summary formula, quiz ids retagged, >=1 subject injection.
Staged to shards_new/<shard>.jsonl.gz as 'uid\t{blob}' lines (append gzip).
"""
import sqlite3, json, gzip, os, re, sys, time, collections, datetime

R = "/home/z/my-project/content/tertiary/recover"
STAGE = f"{R}/shards_new"
os.makedirs(STAGE, exist_ok=True)
TAIL = ": what it is, how it works, and where the marks are."
STRIP = re.compile(r"^[^\w]+|[^\w]+$")

def norm(w):
    return STRIP.sub("", w)

k0 = int(sys.argv[1]) if len(sys.argv) > 1 else 0
k1 = int(sys.argv[2]) if len(sys.argv) > 2 else 10 ** 9

# ---------- state ----------
print("loading corpus...", flush=True)
ldb = sqlite3.connect(f"{R}/corpus.sqlite")
ldb.row_factory = sqlite3.Row
subjects = json.load(open(f"{R}/course_subjects2.json"))
course_meta = json.load(open(f"{R}/course_meta.json"))
donor_index = json.load(open(f"{R}/donor_index.json"))
sig2_raw = json.load(open(f"{R}/sig_ctx2.json"))
T1 = set()
T2 = set()
for k, (c, ss) in sig2_raw.items():
    p, n = k.split("|", 1)
    if c >= 20:
        T1.add((p, n))
    elif 3 <= c < 20 and len(ss) >= 2:
        T2.add((p, n))
print(f"T1 sigs: {len(T1)} | T2 sigs: {len(T2)}", flush=True)

CLOSERS = re.compile(
    r"^\s*\.\s*(One small worked case|Keep the worked|Anything still fuzzy|"
    r"The plan is direct|The quiz that follows|Compare your own|"
    r"Note the exact wording|The unit builds|When you can rebuild)")
PY_NEXT = {"programs", "functions", "bugs", "teams", "course", "projects", "project", "work"}
PY_PREV = {"growing", "robust", "own", "most", "how", "serious", "plain", "real", "a", "in", "of"}

missing_by_key = collections.defaultdict(list)
with gzip.open(f"{R}/missing_units.jsonl.gz", "rt") as f:
    for line in f:
        m = json.loads(line)
        missing_by_key[(m["sigh"], m["sec"], m["pos"])].append((m["uid"], m["cid"], m["title"]))
keys = sorted(missing_by_key.keys())
print(f"keys: {len(keys)} | chunk [{k0}:{k1}] -> {len(keys[k0:k1])}", flush=True)

done_units = set()
if os.path.exists(f"{R}/assembled_ledger.jsonl.gz"):
    with gzip.open(f"{R}/assembled_ledger.jsonl.gz", "rt") as f:
        for line in f:
            done_units.add(line.split("\t", 1)[0])
print(f"already assembled: {len(done_units)}", flush=True)
ledger = gzip.open(f"{R}/assembled_ledger.jsonl.gz", "at")
failures = []
if os.path.exists(f"{R}/assemble_failures.json"):
    failures = json.load(open(f"{R}/assemble_failures.json"))

open_handles = collections.OrderedDict()
def stage_write(shard, uid, blob):
    if shard not in open_handles:
        open_handles[shard] = gzip.open(f"{STAGE}/{shard:05d}.jsonl.gz", "at")
        if len(open_handles) > 200:
            _, old = open_handles.popitem(last=False)
            old.close()
    open_handles[shard].write(f"{uid}\t{json.dumps(blob, ensure_ascii=False, separators=(',', ':'))}\n")

word_re = re.compile(r"[A-Za-z0-9']+", re.ASCII)

def wc(t):
    return len(word_re.findall(t or ""))

def sig_of(nn, i, lw, n):
    p2 = " ".join(nn[max(0, i - 2):i])
    nx = nn[i + lw] if (i + lw) < n else "<END>"
    return (p2, nx)

def find_positions(text, sjw):
    """returns (words, nn, [positions]) for ALL occurrences + sig info stored per pos"""
    if not text:
        return None, None, []
    words = text.split()
    nn = [norm(w).lower() for w in words]
    lw = len(sjw)
    n = len(words)
    pos = []
    for i in range(0, n - lw + 1):
        if nn[i:i + lw] == sjw:
            pos.append(i)
    return words, nn, pos

def splice_punct(words, i, lw, tw):
    """preserve leading punct of first occurrence word and trailing punct of last"""
    first = words[i]
    last = words[i + lw - 1]
    lead = ""
    trail = ""
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
    words, nn, pos = find_positions(text, sjw)
    if not pos:
        return text, 0
    n = len(words)
    keep = []
    replaced = []
    for i in pos:
        p2, nx = sig_of(nn, i, lw, n)
        p1 = nn[i - 1] if i else "<START>"
        rep = False
        if (p2, nx) in T1 or (p2, nx) in T2:
            rep = True
        elif is_heading and words[0].lower() == "inside" and i == 1 \
                and (words[i + lw - 1].endswith(":") or (i + lw < n and nn[i + lw] == ":")):
            # T3: 'Inside <subj>: <title>' heading framing
            rep = True
        elif CLOSERS.match(" ".join(words[i + lw:i + lw + 8])):
            rep = True
        elif p1 == "building" and nx == "work":
            rep = True
        elif p1 in PY_PREV and nx in PY_NEXT and len(sjw) >= 2:
            rep = True
        (replaced if rep else keep).append(i)
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
    for nt in (blob.get("notes") or []):
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
        except Exception as e:
            print(f"   donor load fail {fn}: {e}", flush=True)
            continue
        subj = d.get("subject") or subjects.get(unit_course(d["uid"]))
        if subj:
            out.append({"subject": subj, "blob": d["blob"]})
    return out

def fnv1a32(s):
    h = 0x811C9DC5
    for b in s.encode():
        h ^= b
        h = (h * 0x01000193) & 0xFFFFFFFF
    return h

def now_iso():
    return datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")

def validate(blob, uid):
    errs = []
    if len(blob.get("notes") or []) != 10:
        errs.append("notes!=10")
    for nt in blob["notes"]:
        if wc(nt.get("body")) > 300:
            errs.append("note>300")
            break
    if len(blob.get("quiz") or []) != 20:
        errs.append("quiz!=20")
    for q in blob["quiz"]:
        if q["type"] == "mcq" and len(q.get("options") or {}) != 4:
            errs.append("mcqopts")
            break
    texts = [blob["summary"], blob["title"]]
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
    for t in texts:
        if "--" in t:
            errs.append("dashdash")
            break
    if not (blob["summary"].endswith(TAIL) and blob["summary"].startswith(blob["title"] + " in ")):
        errs.append("summary")
    for i, q in enumerate(blob["quiz"]):
        if q["id"] != f"{uid}-q{i+1:02d}":
            errs.append("qid")
            break
    return errs

stats = collections.Counter()
t0 = time.time()
built = 0
for kk, key in enumerate(keys[k0:k1]):
    lst = missing_by_key[key]
    todo = [(u, c, t) for (u, c, t) in lst if u not in done_units]
    if not todo:
        continue
    donors = donor_load(key)
    if not donors:
        for u, c, t in todo:
            failures.append({"uid": u, "why": "no donors"})
        stats["no_donor"] += len(todo)
        continue
    for i, (uid, cid, title) in enumerate(todo):
        donor = donors[i % len(donors)]
        sd, st = donor["subject"], subjects[cid]
        blob = json.loads(json.dumps(donor["blob"]))
        inj = replace_all(blob, sd, st)
        blob["topic_id"] = uid
        blob["title"] = title
        blob["summary"] = f"{title} in {st}{TAIL}"
        for qi, q in enumerate(blob["quiz"]):
            q["id"] = f"{uid}-q{qi+1:02d}"
        blob["generated_at"] = now_iso()
        errs = validate(blob, uid)
        if inj < 1:
            errs.append("inject0")
        if errs:
            failures.append({"uid": uid, "why": ",".join(errs), "sd": sd, "st": st})
            stats["bad"] += 1
            continue
        stage_write(fnv1a32(uid) % 60000, uid, blob)
        ledger.write(f"{uid}\tok\n")
        built += 1
        stats["inj"] += inj
        if built % 20000 == 0:
            print(f"  {built} built | {(time.time()-t0)/60:.1f} min | bad {stats['bad']}", flush=True)

for fh in open_handles.values():
    fh.close()
ledger.close()
json.dump(failures, open(f"{R}/assemble_failures.json", "w"))
print(f"\nCHUNK DONE: built={built} bad={stats['bad']} no_donor={stats['no_donor']} "
      f"avg_inj={stats['inj']/max(1,built):.1f} in {(time.time()-t0)/60:.1f} min", flush=True)
print("failures:", len(failures))
for f in failures[:25]:
    print("  ", f)
