#!/usr/bin/env python3
"""Scan remaining R2 shard .gz files (lesson packs) for the founder's reqs:
- exactly 10 notes per lesson, every note body <= 300 words
- zero '--' (and zero unicode em/en dash) anywhere in lesson text
Reports totals + worst offenders + prints one full sample lesson.
"""
import gzip, glob, json, re, sys, random

shards = sorted(glob.glob('/home/z/my-project/content/tertiary/build/shards/*.gz'))
print(f"shard files on disk: {len(shards)}", flush=True)
dash2 = re.compile(r'--')
dashuni = re.compile(r'[\u2013\u2014]')
word_re = re.compile(r"[A-Za-z0-9']+")

st = {'lessons': 0, 'notes': 0, 'quiz': 0, 'max_words': 0, 'max_unit': None,
      'max_sample': None, 'bad_counts': 0, 'over300': 0, 'dash2': 0, 'dashuni': 0,
      'hist': {}, 'hits': []}

def scan_blob(uid, blob):
    st['lessons'] += 1
    notes = blob.get('notes') or []
    if len(notes) != 10:
        st['bad_counts'] += 1
        if len(st['hits']) < 30:
            st['hits'].append((uid, 'NOTE_COUNT', str(len(notes))))
    for n in notes:
        st['notes'] += 1
        for txt in (n.get('heading', ''), n.get('body', '')):
            if txt:
                if dash2.search(txt):
                    st['dash2'] += 1
                    if len(st['hits']) < 30:
                        st['hits'].append((uid, 'DASH2-N', txt[:90]))
                if dashuni.search(txt):
                    st['dashuni'] += 1
        wc = len(word_re.findall(n.get('body', '')))
        b = wc // 25
        st['hist'][b] = st['hist'].get(b, 0) + 1
        if wc > 300:
            st['over300'] += 1
        if wc > st['max_words']:
            st['max_words'] = wc
            st['max_unit'] = uid
            st['max_sample'] = (n.get('heading', ''), n.get('body', '')[:200])
    for q in (blob.get('quiz') or []):
        st['quiz'] += 1
        opts = q.get('options') or {}
        texts = [q.get('stem', ''), q.get('answer', ''), q.get('explanation', '')]
        texts += [v for v in opts.values() if isinstance(v, str)]
        for t in texts:
            if t and dash2.search(t):
                st['dash2'] += 1
                if len(st['hits']) < 30:
                    st['hits'].append((uid, 'DASH2-Q', t[:90]))
            if t and dashuni.search(t):
                st['dashuni'] += 1
    for kp in (blob.get('key_points') or []):
        if kp and dash2.search(kp):
            st['dash2'] += 1
    s = blob.get('summary', '')
    if s and dash2.search(s):
        st['dash2'] += 1

sample_blob = None
sample_uid = None
skipped = 0
for i, fp in enumerate(shards):
    try:
        with gzip.open(fp, 'rt', encoding='utf-8') as fh:
            for line in fh:
                line = line.rstrip('\n')
                if not line:
                    continue
                tab = line.find('\t')
                if tab < 0:
                    continue
                uid = line[:tab]
                try:
                    blob = json.loads(line[tab + 1:])
                except Exception:
                    continue
                scan_blob(uid, blob)
                if sample_blob is None and blob.get('notes'):
                    sample_blob = blob
                    sample_uid = uid
    except Exception:
        # shard already consumed (deleted) by the running push, or mid-delete;
        # treat as skipped, sample is still uniform
        skipped += 1
        continue
    if (i + 1) % 4000 == 0:
        print(f"  {i+1}/{len(shards)} shards, {st['lessons']} lessons...", flush=True)

print("\n=== GLOBALS (unpushed-disk sample) ===")
print(f"(shards skipped due to push race: {skipped})")
print(f"lessons={st['lessons']} notes={st['notes']} quiz={st['quiz']}")
print(f"max note body words: {st['max_words']} (unit {st['max_unit']})")
print("max sample:", st['max_sample'])
print(f"notes over 300 words: {st['over300']}")
print(f"lessons with note count != 10: {st['bad_counts']}")
print(f"'--' hits: {st['dash2']} | unicode dash hits: {st['dashuni']}")
for h in st['hits'][:25]:
    print("  ", h)
print("note word-count histogram (25-word buckets):")
for b in sorted(st['hist']):
    print(f"  {b*25}-{b*25+24}: {st['hist'][b]}")

if sample_blob:
    print("\n=== SAMPLE LESSON ===")
    print("unit:", sample_uid, "| title:", sample_blob.get('title'))
    print("summary:", (sample_blob.get('summary') or '')[:200])
    for j, n in enumerate(sample_blob['notes'][:3], 1):
        print(f"\nNOTE {j}: {n.get('heading')}")
        print(n.get('body', '')[:400], "...")
    print(f"\n(quiz count: {len(sample_blob.get('quiz') or [])})")
    q0 = (sample_blob.get('quiz') or [None])[0]
    if q0:
        print("quiz[0]:", json.dumps(q0, ensure_ascii=False)[:400])
