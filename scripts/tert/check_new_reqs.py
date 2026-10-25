#!/usr/bin/env python3
"""Scan built ladder lessons against the founder's new requirements:
1. exactly 10 notes per lesson
2. every note body <= 300 words
3. zero '--' sequences in any note body, heading, quiz stem, options,
   answer, explanation, key_points, summary
Streams all 8 ladder files, prints per-file stats + global worst offenders.
"""
import json, glob, re

files = sorted(glob.glob('/home/z/my-project/content/tertiary/build/ladder_*.jsonl'))
dash2 = re.compile(r'--')
word_re = re.compile(r"[A-Za-z0-9']+")

st = {
    'units': 0, 'notes': 0, 'quiz': 0,
    'max_words': 0, 'max_unit': None, 'max_sample': None,
    'bad_counts': 0, 'over300': 0,
    'dash_hits': [], 'hist': {},
}

def scan_blob(uid, blob):
    st['units'] += 1
    notes = blob.get('notes') or []
    if len(notes) != 10:
        st['bad_counts'] += 1
        if len(st['dash_hits']) < 40:
            st['dash_hits'].append((uid, 'NOTE_COUNT', str(len(notes))))
    for n in notes:
        st['notes'] += 1
        for txt in (n.get('heading', ''), n.get('body', '')):
            if txt and dash2.search(txt):
                st['dash_hits'].append((uid, 'DASH2-N', txt[:80]))
        wc = len(word_re.findall(n.get('body', '')))
        b = wc // 25
        st['hist'][b] = st['hist'].get(b, 0) + 1
        if wc > 300:
            st['over300'] += 1
        if wc > st['max_words']:
            st['max_words'] = wc
            st['max_unit'] = uid
            st['max_sample'] = n.get('body', '')[:150]
    for q in (blob.get('quiz') or []):
        st['quiz'] += 1
        opts = q.get('options') or {}
        texts = [q.get('stem', ''), q.get('answer', ''), q.get('explanation', '')]
        texts += [v for v in opts.values() if isinstance(v, str)]
        for t in texts:
            if t and dash2.search(t):
                st['dash_hits'].append((uid, 'DASH2-Q', t[:80]))
    for kp in (blob.get('key_points') or []):
        if kp and dash2.search(kp):
            st['dash_hits'].append((uid, 'DASH2-KP', kp[:80]))
    s = blob.get('summary', '')
    if s and dash2.search(s):
        st['dash_hits'].append((uid, 'DASH2-SUM', s[:80]))

for fp in files:
    f_max = 0
    f_units = 0
    u0 = st['units']
    with open(fp, 'r', encoding='utf-8') as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            try:
                rec = json.loads(line)
            except Exception:
                continue
            if isinstance(rec, list):
                for r in rec:
                    blob = r.get('blob', r) if isinstance(r, dict) else {}
                    uid = (r.get('unit_id') if isinstance(r, dict) else None) or blob.get('topic_id', '?')
                    scan_blob(uid, blob)
                    f_units += 1
                    if st['units'] % 100000 == 0:
                        print(f"  progress {st['units']} units...", flush=True)
            elif isinstance(rec, dict):
                blob = rec.get('blob', rec)
                uid = rec.get('unit_id') or blob.get('topic_id', '?')
                scan_blob(uid, blob)
                f_units += 1
                if st['units'] % 100000 == 0:
                    print(f"  progress {st['units']} units...", flush=True)
    print(f"{fp.split('/')[-1]}: units={st['units']-u0} (running max note words={f_max or st['max_words']})", flush=True)

print("\n=== GLOBALS ===")
print(f"units={st['units']} notes={st['notes']} quiz={st['quiz']}")
print(f"max note body words: {st['max_words']} (unit {st['max_unit']})")
print("sample:", st['max_sample'])
print(f"notes over 300 words: {st['over300']}")
print(f"lessons with note count != 10: {st['bad_counts']}")
print(f"'--' hits: {len(st['dash_hits'])}")
for h in st['dash_hits'][:25]:
    print("  ", h)
print("note word-count histogram (25-word buckets):")
for b in sorted(st['hist']):
    print(f"  {b*25}-{b*25+24}: {st['hist'][b]}")
