#!/usr/bin/env python3
"""push_ladder.py — update the Supabase ladder for the rebuilt tertiary catalog.

1. UPDATE learn.units (title, category) for all tertiary unit rows (ids unchanged)
2. UPDATE learn.course_sections titles for sections 2-15
3. INSERT the missing section-1 rows (3,908)
All batches transactional per chunk; idempotent (safe to re-run).
"""
import glob
import json
import sys
import time

import psycopg2
from psycopg2.extras import execute_values

DSN = "postgresql://postgres.zfxrmcwdnmmxjawmsiyp:Stephen2474life%23@aws-1-eu-west-3.pooler.supabase.com:5432/postgres?sslmode=require"
BUILD = "/home/z/my-project/content/tertiary/build"


def subject_phrase_of(title, dept_name=""):
    # local import mirror of tert.spec.subject_phrase (cheap enough)
    sys.path.insert(0, "/home/z/my-project/scripts")
    from tert.spec import subject_phrase
    return subject_phrase(title, dept_name)


def main():
    sections_only = "--sections-only" in sys.argv
    rows = []
    for f in sorted(glob.glob(BUILD + "/ladder_*.jsonl")):
        with open(f) as fh:
            for line in fh:
                rows.append(json.loads(line))
    print("ladder rows:", len(rows))

    # section titles: read the section titles per course from the pack registry
    sys.path.insert(0, "/home/z/my-project/scripts")
    from tert.router import route
    from tert.build_all import load_pack
    corpus = {c["id"]: c for c in json.load(open("/home/z/my-project/content/tertiary/corpus.json"))}

    sec_rows = []      # (course_id, section, title) for sections 2..15 UPDATE + 1 INSERT
    unit_rows = []     # (title, category, uid)
    sec1_cache = {}
    sec_seen = set()
    for cid, uid, seq, sec, title, cat in rows:
        unit_rows.append((title, cat, uid))
        if sec == 1:
            continue
        if cid not in sec1_cache:
            pack = load_pack(route(corpus[cid]))
            titles = {k + 2: s["title"] for k, s in enumerate(pack["sections"])}
            titles[1] = "Foundations of " + subject_phrase_of(corpus[cid]["title"], corpus[cid]["dept_name"])
            sec1_cache[cid] = titles
        key = (cid, sec)
        if key not in sec_seen:
            sec_seen.add(key)
            sec_rows.append((cid, sec, sec1_cache[cid][sec]))

    if sections_only:
        unit_rows = []
    # add the missing section-1 rows (one INSERT per tertiary course)
    have_s1 = {(cid, sec) for cid, sec, _ in sec_rows}
    for cid in sec1_cache:
        if (cid, 1) not in have_s1:
            sec_rows.append((cid, 1, sec1_cache[cid][1]))
    print("unit updates:", len(unit_rows), "| section rows:", len(sec_rows),
          "| sec1_cache:", len(sec1_cache), "(incl. section-1 inserts)")
    q = psycopg2.connect(DSN)
    cur = q.cursor()
    t0 = time.time()

    # 1. units
    B = 4000
    for i in range(0, len(unit_rows), B):
        chunk = unit_rows[i:i + B]
        execute_values(cur, """
            UPDATE learn.units u SET title = v.title, category = v.category
            FROM (VALUES %s) AS v(title, category, uid)
            WHERE u.unit_id = v.uid
        """, chunk, page_size=B)
        q.commit()
        if (i // B) % 20 == 0:
            print("  units %d/%d (%.1f min)" % (i + len(chunk), len(unit_rows), (time.time() - t0) / 60))

    # 2. course_sections upsert (covers UPDATE 2..15 and INSERT section 1)
    for i in range(0, len(sec_rows), B):
        chunk = sec_rows[i:i + B]
        execute_values(cur, """
            INSERT INTO learn.course_sections (course_id, section, title, generated_at)
            VALUES %s
            ON CONFLICT (course_id, section) DO UPDATE SET title = EXCLUDED.title
        """, [(cid, sec, title, time.strftime("%Y-%m-%d %H:%M:%S+00")) for cid, sec, title in chunk], page_size=B)
        q.commit()
        print("  sections %d/%d" % (i + len(chunk), len(sec_rows)))

    # verify
    cur.execute("""SELECT COUNT(*) FROM learn.units u JOIN learn.courses c USING (course_id)
                   WHERE c.body='tertiary' AND u.title ILIKE '%meaning, scope%'""")
    print("remaining poison titles:", cur.fetchone()[0])
    cur.execute("""SELECT COUNT(*) FROM learn.course_sections WHERE course_id LIKE 'CRS-%' OR course_id LIKE 'GST%'""")
    print("tertiary course_sections rows now:", cur.fetchone()[0])
    q.close()
    print("done in %.1f min" % ((time.time() - t0) / 60))


if __name__ == "__main__":
    main()
